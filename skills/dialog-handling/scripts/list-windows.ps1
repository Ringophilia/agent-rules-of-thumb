<#
.SYNOPSIS
  Enumerate top-level windows (including hidden / covered ones) or the child
  controls of one window. Read-only: it never changes any window.

.EXAMPLE
  # All visible top-level windows
  powershell -NoProfile -ExecutionPolicy Bypass -File list-windows.ps1

  # Include invisible windows, only standard dialogs
  powershell -NoProfile -ExecutionPolicy Bypass -File list-windows.ps1 -All -Class '#32770'

  # Only windows of one process
  powershell -NoProfile -ExecutionPolicy Bypass -File list-windows.ps1 -ProcessId 1234

  # Read every control (text, buttons, control IDs) inside a dialog
  powershell -NoProfile -ExecutionPolicy Bypass -File list-windows.ps1 -Children 0x000A12F4

  # Machine-readable output
  powershell -NoProfile -ExecutionPolicy Bypass -File list-windows.ps1 -All -Json

.NOTES
  Columns:
    Enabled=False on a main window usually means a modal dialog owns it.
    Owner   = hwnd of the owner window; a dialog whose Owner is your target
              window is the one blocking it (more reliable than rect overlap).
  Children of WPF / Qt / Electron / custom-drawn UIs are often not real
  windows, so -Children may return nothing; use UI Automation or a screenshot.
  Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less UTF-8
  scripts with the ANSI code page and would corrupt non-ASCII literals.
#>
param(
    [switch]$All,
    [string]$Class,
    [int]$ProcessId,
    [string]$Children,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

if (-not ('RingoWin.Native' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
namespace RingoWin {
public static class Native {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, StringBuilder l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsHungAppWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();

    public static List<IntPtr> TopLevel() {
        var list = new List<IntPtr>();
        EnumWindows(delegate (IntPtr h, IntPtr l) { list.Add(h); return true; }, IntPtr.Zero);
        return list;
    }
    public static List<IntPtr> ChildrenOf(IntPtr parent) {
        var list = new List<IntPtr>();
        EnumChildWindows(parent, delegate (IntPtr h, IntPtr l) { list.Add(h); return true; }, IntPtr.Zero);
        return list;
    }
    public static string ClassOf(IntPtr h) {
        var sb = new StringBuilder(256);
        GetClassName(h, sb, sb.Capacity);
        return sb.ToString();
    }
    // WM_GETTEXT via SendMessageTimeout: works across processes and does not
    // hang if the target window is not responding.
    public static string TextOf(IntPtr h) {
        IntPtr len;
        if (SendMessageTimeout(h, 0x000E, IntPtr.Zero, IntPtr.Zero, 0x0002, 500, out len) == IntPtr.Zero) return null;
        int n = (int)len;
        if (n <= 0) return "";
        if (n > 32768) n = 32768;
        var sb = new StringBuilder(n + 1);
        IntPtr got;
        if (SendMessageTimeout(h, 0x000D, (IntPtr)(n + 1), sb, 0x0002, 500, out got) == IntPtr.Zero) return null;
        return sb.ToString();
    }
}
}
'@
}

[void][RingoWin.Native]::SetProcessDPIAware()

function ConvertTo-Hwnd([string]$s) {
    if ($s -match '^0x') { return [IntPtr][Convert]::ToInt64($s.Substring(2), 16) }
    return [IntPtr][Int64]$s
}
function Format-Hwnd([IntPtr]$h) { '0x{0:X8}' -f $h.ToInt64() }

$procNames = @{}
function Get-ProcName([uint32]$procId) {
    if (-not $procNames.ContainsKey($procId)) {
        $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
        $procNames[$procId] = if ($p) { $p.ProcessName } else { '?' }
    }
    $procNames[$procId]
}

function Get-Info([IntPtr]$h, [switch]$AsChild) {
    $r = New-Object RingoWin.Native+RECT
    [void][RingoWin.Native]::GetWindowRect($h, [ref]$r)
    [uint32]$procId = 0
    [void][RingoWin.Native]::GetWindowThreadProcessId($h, [ref]$procId)
    $text = [RingoWin.Native]::TextOf($h)
    $o = [ordered]@{
        Hwnd    = Format-Hwnd $h
        Class   = [RingoWin.Native]::ClassOf($h)
        Text    = if ($null -eq $text) { '<no response>' } else { $text -replace "`r?`n", ' / ' }
        Visible = [RingoWin.Native]::IsWindowVisible($h)
        Enabled = [RingoWin.Native]::IsWindowEnabled($h)
        X = $r.L; Y = $r.T; W = $r.R - $r.L; H = $r.B - $r.T
    }
    if ($AsChild) {
        $o.CtrlId = [RingoWin.Native]::GetDlgCtrlID($h)
    } else {
        $owner = [RingoWin.Native]::GetWindow($h, 4)   # GW_OWNER
        $o.Owner   = if ($owner -eq [IntPtr]::Zero) { '' } else { Format-Hwnd $owner }
        $o.Hung    = [RingoWin.Native]::IsHungAppWindow($h)
        $o.Pid     = $procId
        $o.Process = Get-ProcName $procId
    }
    [pscustomobject]$o
}

if ($Children) {
    $parent = ConvertTo-Hwnd $Children
    $rows = [RingoWin.Native]::ChildrenOf($parent) | ForEach-Object { Get-Info $_ -AsChild }
    if (-not $rows) { Write-Warning "No child windows. The UI may be custom-drawn (WPF/Qt/Electron/DirectUI); try UI Automation or a screenshot." }
} else {
    $rows = [RingoWin.Native]::TopLevel() | ForEach-Object {
        if (-not $All -and -not [RingoWin.Native]::IsWindowVisible($_)) { return }
        $info = Get-Info $_
        if ($Class -and $info.Class -ne $Class) { return }
        if ($ProcessId -and $info.Pid -ne $ProcessId) { return }
        if (-not $All -and $info.W -le 0 -and $info.H -le 0) { return }
        $info
    }
}

if (-not $rows) {
    if ($Json) { '[]' } else { '(no windows matched)' }
} elseif ($Json) {
    ConvertTo-Json -InputObject @($rows) -Depth 3
} else {
    # Format-Table shows at most 10 auto-picked columns; name them explicitly.
    $cols = if ($Children) { 'Hwnd', 'CtrlId', 'Class', 'Text', 'Visible', 'Enabled', 'X', 'Y', 'W', 'H' }
            else { 'Hwnd', 'Pid', 'Process', 'Class', 'Text', 'Visible', 'Enabled', 'Hung', 'Owner', 'X', 'Y', 'W', 'H' }
    @($rows) | Format-Table -Property $cols -AutoSize | Out-String -Width 400
}
