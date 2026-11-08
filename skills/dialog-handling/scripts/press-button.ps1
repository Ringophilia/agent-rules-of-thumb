<#
.SYNOPSIS
  Press a button inside a Win32 dialog without moving the mouse, then verify
  whether the dialog actually went away.

.DESCRIPTION
  Get the button hwnd first with:  list-windows.ps1 -Children <dialogHwnd>
  Methods, in the order you should try them:
    Command  (default) PostMessage(parent, WM_COMMAND, MAKEWPARAM(id, BN_CLICKED), btn)
             Same path a real click takes; works when the dialog is not active
             and never blocks on a hung window.
    BmClick  Bring dialog to foreground, then PostMessage(btn, BM_CLICK).
             BM_CLICK can fail silently when the dialog is not the active window.
    Close    PostMessage(dialog, WM_CLOSE). Usually equals Cancel / the X button;
             some programs treat it as "No".
  Use -Dialog with -Method Close. For Command/BmClick, -Dialog is optional and
  only used for the verification step (defaults to the button's parent).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File press-button.ps1 -Button 0x000B0312
  powershell -NoProfile -ExecutionPolicy Bypass -File press-button.ps1 -Button 0x000B0312 -Method BmClick
  powershell -NoProfile -ExecutionPolicy Bypass -File press-button.ps1 -Dialog 0x000A12F4 -Method Close

.NOTES
  Exit code 0 = dialog gone, 1 = dialog still there, 2 = bad arguments.
  Read the dialog text BEFORE pressing anything (list-windows.ps1 -Children).
#>
param(
    [string]$Button,
    [string]$Dialog,
    [ValidateSet('Command', 'BmClick', 'Close')][string]$Method = 'Command',
    [int]$WaitMs = 1500
)

$ErrorActionPreference = 'Stop'

if (-not ('RingoWin.Press' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace RingoWin {
public static class Press {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
}
'@
}

function ConvertTo-Hwnd([string]$s) {
    if (-not $s) { return [IntPtr]::Zero }
    if ($s -match '^0x') { return [IntPtr][Convert]::ToInt64($s.Substring(2), 16) }
    return [IntPtr][Int64]$s
}

$btn = ConvertTo-Hwnd $Button
$dlg = ConvertTo-Hwnd $Dialog

if ($Method -eq 'Close') {
    if ($dlg -eq [IntPtr]::Zero) { Write-Error '-Method Close needs -Dialog'; exit 2 }
} else {
    if ($btn -eq [IntPtr]::Zero -or -not [RingoWin.Press]::IsWindow($btn)) { Write-Error "Button $Button is not a valid window"; exit 2 }
    if ($dlg -eq [IntPtr]::Zero) { $dlg = [RingoWin.Press]::GetParent($btn) }
}

switch ($Method) {
    'Command' {
        $id = [RingoWin.Press]::GetDlgCtrlID($btn)
        $parent = [RingoWin.Press]::GetParent($btn)
        # MAKEWPARAM(id, BN_CLICKED=0) == id
        [void][RingoWin.Press]::PostMessage($parent, 0x0111, [IntPtr]$id, $btn)
    }
    'BmClick' {
        [void][RingoWin.Press]::SetForegroundWindow($dlg)
        Start-Sleep -Milliseconds 100
        [void][RingoWin.Press]::PostMessage($btn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)
    }
    'Close' {
        [void][RingoWin.Press]::PostMessage($dlg, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    }
}

# Verify by condition, not by a fixed sleep.
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.ElapsedMilliseconds -lt $WaitMs) {
    if (-not [RingoWin.Press]::IsWindow($dlg) -or -not [RingoWin.Press]::IsWindowVisible($dlg)) {
        "OK: dialog {0} gone after {1} ms (method={2})" -f ('0x{0:X8}' -f $dlg.ToInt64()), $sw.ElapsedMilliseconds, $Method
        exit 0
    }
    Start-Sleep -Milliseconds 100
}
"STILL OPEN: dialog {0} after {1} ms (method={2}). Re-enumerate; try the next method." -f ('0x{0:X8}' -f $dlg.ToInt64()), $WaitMs, $Method
exit 1
