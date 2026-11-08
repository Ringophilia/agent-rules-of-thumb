<#
.SYNOPSIS
  Collect error evidence that never reaches your program's own log: dialogs
  shown by ANY process (crash reporters, loader errors, runtimes, helpers,
  antivirus, UAC), new processes, Windows event log errors, crash dumps and
  WER reports. Read-only: it never changes, activates or closes anything.

.EXAMPLE
  # Note the time, reproduce the failure, then collect everything since then
  $t = Get-Date
  # ... run / reproduce ...
  powershell -NoProfile -ExecutionPolicy Bypass -File collect-errors.ps1 -Since $t

  # Same, and mark which findings belong to your program's process tree
  powershell -NoProfile -ExecutionPolicy Bypass -File collect-errors.ps1 -Since $t -ProcessId 1234

  # Last 15 minutes, include hidden windows, machine-readable
  powershell -NoProfile -ExecutionPolicy Bypass -File collect-errors.ps1 -Minutes 15 -IncludeHidden -Json

.NOTES
  Windows have no creation time, so the Dialogs section lists every visible
  dialog-like window on the desktop (standard dialogs, owned popups, windows
  of error-reporter processes, windows of processes started since -Since),
  whatever process owns it. Related=True marks your -ProcessId tree.
  Text is read from child controls first, then UI Automation (TaskDialog,
  WPF, Qt, Electron dialogs have no Win32 child text).
  Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less UTF-8
  scripts with the ANSI code page and would corrupt non-ASCII literals.
#>
param(
    [datetime]$Since,
    [int]$Minutes = 10,
    [int]$ProcessId,
    [switch]$IncludeHidden,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
if (-not $Since) { $Since = (Get-Date).AddMinutes(-$Minutes) }

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class CeWin {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsHungAppWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, StringBuilder l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);

    public static List<IntPtr> TopLevel() {
        var r = new List<IntPtr>();
        EnumWindows((h, l) => { r.Add(h); return true; }, IntPtr.Zero);
        return r;
    }
    public static List<IntPtr> Children(IntPtr p) {
        var r = new List<IntPtr>();
        EnumChildWindows(p, (h, l) => { r.Add(h); return true; }, IntPtr.Zero);
        return r;
    }
    public static string Cls(IntPtr h) {
        var sb = new StringBuilder(256); GetClassName(h, sb, 256); return sb.ToString();
    }
    // WM_GETTEXT with a timeout so a hung target cannot hang us; works cross-process for edit controls too
    public static string Text(IntPtr h) {
        IntPtr res, len;
        if (SendMessageTimeout(h, 0x000E, IntPtr.Zero, IntPtr.Zero, 0x0002, 500, out len) == IntPtr.Zero) return "";
        int n = (int)len; if (n <= 0) return ""; if (n > 8192) n = 8192;
        var sb = new StringBuilder(n + 1);
        if (SendMessageTimeout(h, 0x000D, (IntPtr)(n + 1), sb, 0x0002, 500, out res) == IntPtr.Zero) return "";
        return sb.ToString();
    }
    public static uint Pid(IntPtr h) { uint p; GetWindowThreadProcessId(h, out p); return p; }
    public static IntPtr Owner(IntPtr h) { return GetWindow(h, 4); }
}
'@

# processes whose windows are error / block / consent popups on behalf of OTHER programs
$reporters = @('WerFault','WerFaultSecure','dwwin','DW20','consent','smartscreen','vsjitdebugger',
               'csrss','MpCmdRun','CrashReporter','BugSplat','BsSndRpt')

# ---------- processes ----------
$procs = @{}
foreach ($p in Get-CimInstance Win32_Process) {
    $procs[[int]$p.ProcessId] = [pscustomobject]@{
        Pid = [int]$p.ProcessId; ParentPid = [int]$p.ParentProcessId
        Name = [IO.Path]::GetFileNameWithoutExtension($p.Name); Started = $p.CreationDate
    }
}
$related = @{}
if ($ProcessId) {
    $related[$ProcessId] = $true
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($p in $procs.Values) {
            if ($related.ContainsKey($p.ParentPid) -and -not $related.ContainsKey($p.Pid)) { $related[$p.Pid] = $true; $changed = $true }
        }
    }
}
function Get-ProcName([int]$id) { if ($procs.ContainsKey($id)) { $procs[$id].Name } else { '?' } }
function Test-Related([int]$id) { return $related.ContainsKey($id) }

$newProcs = @($procs.Values | Where-Object { $_.Started -and $_.Started -ge $Since } | Sort-Object Started | ForEach-Object {
    [pscustomobject]@{
        Started = $_.Started.ToString('HH:mm:ss'); Pid = $_.Pid; Name = $_.Name
        ParentPid = $_.ParentPid; Parent = (Get-ProcName $_.ParentPid)
        Reporter = ($reporters -contains $_.Name); Related = (Test-Related $_.Pid)
    }
})
$newPidSet = @{}; foreach ($p in $newProcs) { $newPidSet[$p.Pid] = $true }

# ---------- dialogs ----------
$uiaLoaded = $false
function Get-UiaText([IntPtr]$h) {
    if (-not $script:uiaLoaded) {
        Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
        $script:uiaLoaded = $true
    }
    try {
        $el = [System.Windows.Automation.AutomationElement]::FromHandle($h)
        $all = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $names = New-Object System.Collections.Generic.List[string]
        $i = 0
        foreach ($e in $all) {
            if (++$i -gt 300) { break }
            $n = $e.Current.Name
            if ($n -and -not $names.Contains($n)) { $names.Add($n) }
        }
        return ($names -join ' | ')
    } catch { return '' }
}

$dialogs = @()
foreach ($h in [CeWin]::TopLevel()) {
    $visible = [CeWin]::IsWindowVisible($h)
    if (-not $visible -and -not $IncludeHidden) { continue }
    $cls = [CeWin]::Cls($h)
    if ($cls -in @('Progman','WorkerW','Shell_TrayWnd','Shell_SecondaryTrayWnd','IME','MSCTFIME UI','tooltips_class32')) { continue }
    $wpid = [int][CeWin]::Pid($h)
    $pname = Get-ProcName $wpid
    $owner = [CeWin]::Owner($h)
    $isDialog = ($cls -eq '#32770') -or ($owner -ne [IntPtr]::Zero)
    $isReporter = $reporters -contains $pname
    $isNew = $newPidSet.ContainsKey($wpid)
    $isRel = Test-Related $wpid
    # hidden windows only matter if they are dialogs, reporters or ours; a new
    # process's hidden helper windows (GDI+, broadcast, GL dummies) are noise
    if ($visible) { if (-not ($isDialog -or $isReporter -or $isNew -or $isRel)) { continue } }
    else          { if (-not ($cls -eq '#32770' -or $isRel)) { continue } }

    $title = [CeWin]::Text($h)
    if ($title -eq $cls -or $cls -match '^(GDI\+ Hook|\.NET-Broadcast|NVOpenGLPbuffer|CicMarshalWnd|OleMainThread)') { continue }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($c in [CeWin]::Children($h)) {
        $t = [CeWin]::Text($c)
        if ($t -and -not $parts.Contains($t)) { $parts.Add($t) }
    }
    $body = ($parts -join ' | ')
    if (-not $body) { $body = Get-UiaText $h }
    if (-not $title -and -not $body -and -not $isReporter) { continue }   # empty helper windows

    $rank = 0
    if ($isRel) { $rank += 8 }; if ($isReporter) { $rank += 4 }; if ($cls -eq '#32770') { $rank += 2 }; if ($visible) { $rank += 1 }
    $dialogs += [pscustomobject]@{
        Rank = $rank
        Hwnd = ('0x{0:X8}' -f $h.ToInt64()); Pid = $wpid; Process = $pname; Class = $cls
        Visible = $visible; Hung = [CeWin]::IsHungAppWindow($h)
        Owner = $(if ($owner -ne [IntPtr]::Zero) { '0x{0:X8}' -f $owner.ToInt64() } else { '' })
        Reporter = $isReporter; NewProcess = $isNew; Related = $isRel
        Title = $title; Text = $body
    }
}

# most likely culprits first: ours, crash reporters, standard dialogs, visible
$dialogs = @($dialogs | Sort-Object Rank -Descending | Select-Object * -ExcludeProperty Rank)

# ---------- event log ----------
$events = @()
$queries = @(
    @{ LogName = 'Application'; Level = 1, 2; StartTime = $Since },
    @{ LogName = 'Application'; ProviderName = 'Windows Error Reporting'; StartTime = $Since },
    @{ LogName = 'System'; ProviderName = 'Application Popup'; StartTime = $Since },
    @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Resource-Exhaustion-Detector'; StartTime = $Since }
)
foreach ($q in $queries) {
    try {
        $events += Get-WinEvent -FilterHashtable $q -MaxEvents 50 -ErrorAction Stop
    } catch { }   # "no events found" is an exception here
}
$events = @($events | Sort-Object RecordId, LogName -Unique | Sort-Object TimeCreated | ForEach-Object {
    $msg = ''
    try { $msg = $_.Message } catch { }
    if (-not $msg) { $msg = ($_.Properties | ForEach-Object { $_.Value }) -join ' | ' }
    $msg = ($msg -replace '\s+', ' ').Trim()
    if ($msg.Length -gt 600) { $msg = $msg.Substring(0, 600) + '...' }
    [pscustomobject]@{
        Time = $_.TimeCreated.ToString('HH:mm:ss'); Log = $_.LogName; Source = $_.ProviderName
        Id = $_.Id; Level = $_.LevelDisplayName; Message = $msg
    }
})

# ---------- crash dumps / WER reports ----------
$dirs = @(
    (Join-Path $env:LOCALAPPDATA 'CrashDumps'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\WER\ReportArchive'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\WER\ReportQueue'),
    (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive'),
    (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue')
)
$files = @()
foreach ($d in $dirs) {
    if (-not (Test-Path -LiteralPath $d)) { continue }
    try {
        $files += Get-ChildItem -LiteralPath $d -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $Since } |
            ForEach-Object { [pscustomobject]@{ Time = $_.LastWriteTime.ToString('HH:mm:ss'); Path = $_.FullName } }
    } catch { }
}

# ---------- output ----------
$result = [pscustomobject]@{
    Since = $Since.ToString('yyyy-MM-dd HH:mm:ss'); ProcessId = $ProcessId
    Dialogs = $dialogs; NewProcesses = $newProcs; Events = $events; CrashFiles = $files
}
if ($Json) { $result | ConvertTo-Json -Depth 4; return }

"Since $($result.Since)$(if ($ProcessId) { "   (Related = process tree of pid $ProcessId)" })"
""
"== Dialogs / popups from ANY process ($($dialogs.Count)) =="
if ($dialogs.Count) {
    foreach ($d in $dialogs) {
        $flags = @()
        if ($d.Related) { $flags += 'RELATED' }; if ($d.Reporter) { $flags += 'REPORTER' }
        if ($d.NewProcess) { $flags += 'NEW-PROCESS' }; if (-not $d.Visible) { $flags += 'hidden' }
        if ($d.Hung) { $flags += 'HUNG' }
        "[$($d.Hwnd)] $($d.Process) pid=$($d.Pid) class=$($d.Class) owner=$($d.Owner) $($flags -join ' ')"
        "    Title: $($d.Title)"
        "    Text : $($d.Text)"
    }
} else { "    (none)" }
""
"== Processes started since then ($($newProcs.Count)) =="
if ($newProcs.Count) {
    # reporters and our own tree first; the rest is context, capped
    $top = @($newProcs | Where-Object { $_.Reporter -or $_.Related }) + @($newProcs | Where-Object { -not ($_.Reporter -or $_.Related) } | Select-Object -Last 30)
    $top | Format-Table -AutoSize | Out-String -Width 220
    if ($newProcs.Count -gt $top.Count) { "    ... $($newProcs.Count - $top.Count) older unrelated processes omitted (use -Json for all)" ; "" }
} else { "    (none)" }
"== Event log: errors, WER, Application Popup ($($events.Count)) =="
if ($events.Count) { foreach ($e in $events) { "$($e.Time) [$($e.Log)/$($e.Source) $($e.Id) $($e.Level)] $($e.Message)" } } else { "    (none)" }
""
"== Crash dumps / WER reports ($($files.Count)) =="
if ($files.Count) { foreach ($f in $files) { "$($f.Time) $($f.Path)" } } else { "    (none)" }
