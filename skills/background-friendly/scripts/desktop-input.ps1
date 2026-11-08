<#
.SYNOPSIS
  FOREGROUND fallback: real mouse/keyboard input into one window, for when background
  methods (uia.ps1, CDP, app debug hooks) cannot do the job AND computer-use is not
  available. This DOES take over the user's mouse/keyboard for a moment, so ONLY run it
  after the user approved it in chat.

  It brings the target window to the front, runs the steps, then (by default) puts the
  user's previous foreground window, the window's previous minimized state and the mouse
  cursor back where they were.

.STEPS  (executed in order, one string each)
  click:X,Y        left click at X,Y relative to the window CLIENT area (physical pixels,
                   same pixel grid as a capture-window.ps1 screenshot minus the title bar
                   when -ScreenCoords is not used; see -WindowCoords)
  dclick:X,Y       double click         rclick:X,Y   right click
  move:X,Y         move the cursor only
  drag:X1,Y1,X2,Y2 left-button drag
  scroll:N         mouse wheel N notches (positive = up), at the current cursor position
  type:TEXT        type Unicode text (works for Chinese etc.; "\n" -> Enter)
  key:COMBO        e.g. enter, esc, tab, ctrl+s, ctrl+shift+t, alt+f4, f5, win+d, up, pagedown
  wait:MS          sleep

.EXAMPLES
  # With "powershell -File" pass all steps in ONE string separated by "||"
  desktop-input.ps1 -Title "My App" -Steps "click:120,80||type:hello world||key:ctrl+s"
  desktop-input.ps1 -ProcessName game -WindowCoords -Steps "click:400,300||wait:500||key:esc"

.PARAMETERS
  -WindowCoords  X,Y are relative to the window's visible frame (top-left of a
                 capture-window.ps1 screenshot) instead of the client area.
  -ScreenCoords  X,Y are absolute screen coordinates.
  -NoRestore     leave the target window in front.
  -StepDelayMs   pause between steps (default 80).
#>
[CmdletBinding()]
param(
  [string]$Hwnd, [int]$ProcessId, [string]$ProcessName, [string]$Title,
  [Parameter(Mandatory)][string[]]$Steps,
  [switch]$WindowCoords, [switch]$ScreenCoords, [switch]$NoRestore,
  [int]$StepDelayMs = 80
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$src = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class DIn {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }
  [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr extra; }
  [StructLayout(LayoutKind.Explicit)] struct UNION { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
  [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public UNION u; }

  [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint n, INPUT[] inputs, int size);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);

  public static void InitDpi() {
    try { if (SetProcessDpiAwarenessContext(new IntPtr(-4))) return; } catch {}
    try { SetProcessDPIAware(); } catch {}
  }

  static void Send(params INPUT[] ins) { SendInput((uint)ins.Length, ins, Marshal.SizeOf(typeof(INPUT))); }
  static INPUT Key(ushort vk, ushort scan, uint flags) {
    var i = new INPUT(); i.type = 1; i.u.ki.wVk = vk; i.u.ki.wScan = scan; i.u.ki.dwFlags = flags; return i;
  }
  static INPUT Mouse(uint flags, uint data) {
    var i = new INPUT(); i.type = 0; i.u.mi.dwFlags = flags; i.u.mi.mouseData = data; return i;
  }

  public static bool Activate(IntPtr h) {
    if (IsIconic(h)) ShowWindow(h, 9); // SW_RESTORE
    if (GetForegroundWindow() == h) return true;
    uint me = GetCurrentThreadId();
    uint fgT = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
    uint tgT = GetWindowThreadProcessId(h, IntPtr.Zero);
    // An ALT tap lifts the foreground lock for this process.
    Send(Key(0x12, 0, 0), Key(0x12, 0, 2));
    AttachThreadInput(me, fgT, true); AttachThreadInput(me, tgT, true);
    BringWindowToTop(h); SetForegroundWindow(h);
    AttachThreadInput(me, fgT, false); AttachThreadInput(me, tgT, false);
    for (int i = 0; i < 20 && GetForegroundWindow() != h; i++) Thread.Sleep(25);
    return GetForegroundWindow() == h;
  }

  public static POINT ToScreen(IntPtr h, int x, int y, int mode) {
    var p = new POINT(); p.X = x; p.Y = y;
    if (mode == 0) { ClientToScreen(h, ref p); return p; }
    if (mode == 1) {
      RECT r;
      if (DwmGetWindowAttribute(h, 9, out r, Marshal.SizeOf(typeof(RECT))) != 0) GetWindowRect(h, out r);
      p.X += r.L; p.Y += r.T; return p;
    }
    return p;
  }

  public static void Click(int sx, int sy, string kind) {
    SetCursorPos(sx, sy); Thread.Sleep(30);
    uint down = 0x2, up = 0x4;
    if (kind == "r") { down = 0x8; up = 0x10; }
    Send(Mouse(down, 0), Mouse(up, 0));
    if (kind == "d") { Thread.Sleep(60); Send(Mouse(down, 0), Mouse(up, 0)); }
  }
  public static void Drag(int x1, int y1, int x2, int y2) {
    SetCursorPos(x1, y1); Thread.Sleep(40); Send(Mouse(0x2, 0));
    for (int i = 1; i <= 15; i++) { SetCursorPos(x1 + (x2 - x1) * i / 15, y1 + (y2 - y1) * i / 15); Thread.Sleep(15); }
    Send(Mouse(0x4, 0));
  }
  public static void Scroll(int notches) { Send(Mouse(0x800, (uint)(notches * 120))); }

  public static void TypeText(string s) {
    foreach (char ch in s) {
      if (ch == '\n') { Send(Key(0x0D, 0, 0), Key(0x0D, 0, 2)); continue; }
      if (ch == '\r') continue;
      Send(Key(0, ch, 4), Key(0, ch, 4 | 2)); // KEYEVENTF_UNICODE
      Thread.Sleep(5);
    }
  }

  static readonly Dictionary<string, ushort> Named = new Dictionary<string, ushort> {
    {"ctrl",0x11},{"control",0x11},{"shift",0x10},{"alt",0x12},{"win",0x5B},
    {"enter",0x0D},{"return",0x0D},{"tab",0x09},{"esc",0x1B},{"escape",0x1B},{"space",0x20},
    {"backspace",0x08},{"delete",0x2E},{"del",0x2E},{"insert",0x2D},{"home",0x24},{"end",0x23},
    {"pageup",0x21},{"pagedown",0x22},{"up",0x26},{"down",0x28},{"left",0x25},{"right",0x27},
    {"capslock",0x14},{"printscreen",0x2C},{"apps",0x5D},{"menu",0x5D}
  };
  static readonly HashSet<ushort> Extended = new HashSet<ushort> { 0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x2D,0x2E,0x5B,0x5D };

  static ushort Vk(string k) {
    k = k.Trim().ToLowerInvariant();
    ushort v;
    if (Named.TryGetValue(k, out v)) return v;
    if (k.Length >= 2 && k[0] == 'f') { int n; if (int.TryParse(k.Substring(1), out n) && n >= 1 && n <= 24) return (ushort)(0x6F + n); }
    if (k.Length == 1) {
      char c = char.ToUpperInvariant(k[0]);
      if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) return (ushort)c;
    }
    throw new ArgumentException("unknown key: " + k);
  }
  public static void Combo(string combo) {
    var parts = combo.Split('+'); var vks = new List<ushort>();
    foreach (var p in parts) vks.Add(Vk(p));
    foreach (var v in vks) Send(Key(v, 0, Extended.Contains(v) ? 1u : 0u));
    Thread.Sleep(20);
    for (int i = vks.Count - 1; i >= 0; i--) Send(Key(vks[i], 0, (Extended.Contains(vks[i]) ? 1u : 0u) | 2));
  }
}
"@
if (-not ('DIn' -as [type])) { Add-Type -TypeDefinition $src }
[DIn]::InitDpi()

# ---- pick window (same selectors as capture-window.ps1) ----
Add-Type -AssemblyName UIAutomationClient
$target = [IntPtr]::Zero
if ($Hwnd) {
  $v = if ($Hwnd -match '^0x') { [Convert]::ToInt64($Hwnd.Substring(2), 16) } else { [int64]$Hwnd }
  $target = [IntPtr]$v
} elseif (-not $ScreenCoords -or $ProcessId -or $ProcessName -or $Title) {
  if (-not $ProcessId -and -not $ProcessName -and -not $Title) { throw 'Specify -Hwnd, -ProcessId, -ProcessName or -Title (or -ScreenCoords with no window).' }
  $tops = [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
  foreach ($w in $tops) {
    $c = $w.Current
    if ($ProcessId -and $c.ProcessId -ne $ProcessId) { continue }
    if ($ProcessName) { $pn = try { (Get-Process -Id $c.ProcessId).ProcessName } catch { '' }; if ($pn -notlike ($ProcessName -replace '\.exe$','')) { continue } }
    if ($Title -and $c.Name -notlike "*$Title*") { continue }
    $target = [IntPtr]$c.NativeWindowHandle; break
  }
  if ($target -eq [IntPtr]::Zero) { throw 'No matching window (use capture-window.ps1 -List).' }
}

$prevFg = [DIn]::GetForegroundWindow()
$wasMin = ($target -ne [IntPtr]::Zero) -and [DIn]::IsIconic($target)
$prevCursor = New-Object DIn+POINT
[void][DIn]::GetCursorPos([ref]$prevCursor)
$mode = if ($ScreenCoords) { 2 } elseif ($WindowCoords) { 1 } else { 0 }
$log = @()

try {
  if ($target -ne [IntPtr]::Zero) {
    if (-not [DIn]::Activate($target)) { $log += 'warn: could not bring window to front' }
    Start-Sleep -Milliseconds 150
  }
  # "powershell -File" collapses arrays into one comma-joined string, so also accept
  # "||" as a separator and split before every "<op>:" that follows a comma.
  $stepList = foreach ($chunk in $Steps) {
    foreach ($part in ($chunk -split '\s*\|\|\s*')) {
      $part -split ',(?=(?:click|dclick|rclick|move|drag|scroll|type|key|wait):)' | Where-Object { $_ -ne '' }
    }
  }
  foreach ($s in $stepList) {
    $i = $s.IndexOf(':'); if ($i -lt 0) { throw "bad step '$s'" }
    $op = $s.Substring(0, $i).ToLower(); $arg = $s.Substring($i + 1)
    switch ($op) {
      { $_ -in 'click','dclick','rclick','move' } {
        $xy = $arg.Split(','); $p = [DIn]::ToScreen($target, [int]$xy[0], [int]$xy[1], $mode)
        if ($op -eq 'move') { [void][DIn]::SetCursorPos($p.X, $p.Y) }
        else { [DIn]::Click($p.X, $p.Y, @{click='l';dclick='d';rclick='r'}[$op]) }
      }
      'drag' {
        $n = $arg.Split(',') | ForEach-Object { [int]$_ }
        $a = [DIn]::ToScreen($target, $n[0], $n[1], $mode); $b = [DIn]::ToScreen($target, $n[2], $n[3], $mode)
        [DIn]::Drag($a.X, $a.Y, $b.X, $b.Y)
      }
      'scroll' { [DIn]::Scroll([int]$arg) }
      'type'   { [DIn]::TypeText(($arg -replace '\\n', "`n")) }
      'key'    { [DIn]::Combo($arg) }
      'wait'   { Start-Sleep -Milliseconds ([int]$arg) }
      default  { throw "unknown step '$op'" }
    }
    $log += $s
    Start-Sleep -Milliseconds $StepDelayMs
  }
} finally {
  if (-not $NoRestore) {
    [void][DIn]::SetCursorPos($prevCursor.X, $prevCursor.Y)
    if ($wasMin) { [void][DIn]::ShowWindow($target, 7) } # SW_SHOWMINNOACTIVE
    if ($prevFg -ne [IntPtr]::Zero -and $prevFg -ne $target) { [void][DIn]::Activate($prevFg) }
  }
}
[pscustomobject]@{ hwnd = ('0x{0:X}' -f $target.ToInt64()); steps = $log; restored = (-not $NoRestore) } | ConvertTo-Json -Compress
