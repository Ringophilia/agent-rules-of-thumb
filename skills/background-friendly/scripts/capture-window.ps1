<#
.SYNOPSIS
  Capture a single window to PNG WITHOUT bringing it to the front, without moving
  the user's mouse, and (by default) without a visible flash - even when the window
  is covered by other windows or minimized.

.EXAMPLES
  # List capturable top-level windows (hwnd, pid, process, state, title)
  powershell -NoProfile -ExecutionPolicy Bypass -File capture-window.ps1 -List

  # Capture by process name / title substring / pid / hwnd
  ... -File capture-window.ps1 -ProcessName notepad -Out C:\tmp\shot.png
  ... -File capture-window.ps1 -Title "My Game" -Out C:\tmp\shot.png
  ... -File capture-window.ps1 -ProcessId 1234 -Out C:\tmp\shot.png
  ... -File capture-window.ps1 -Hwnd 0x1A2B3C -Out C:\tmp\shot.png

  # Minimized window: by default it is restored invisibly (alpha 0, no activation),
  # captured, then minimized again. Pass -NoRestoreMinimized to refuse instead.

  # Burst: N frames every -IntervalMs, saved to <Out>.frames\frame_NN.png and stitched
  # into ONE labelled contact sheet at -Out (via compose-shots.ps1). Good for loading
  # progress, animations, flicker, or a dialog that flashes by - one image, one look.
  ... -File capture-window.ps1 -Title "My App" -Burst 6 -IntervalMs 300 -Out C:\tmp\sheet.png

.NOTES
  Uses PrintWindow(PW_RENDERFULLCONTENT). Works for occluded windows and most
  Win32 / WPF / WinForms / Qt / Electron / browser windows. Some DirectX/OpenGL/
  Vulkan games or exclusive-fullscreen apps return a black image -> the script
  reports "black" and you should use the app's own screenshot API instead.
  Prints one JSON line describing the result.
#>
[CmdletBinding()]
param(
  [switch]$List,
  [string]$Hwnd,
  [int]$ProcessId,
  [string]$ProcessName,
  [string]$Title,
  [string]$Out,
  [switch]$NoRestoreMinimized,
  [int]$SettleMs = 400,
  [switch]$IncludeShadow,
  [int]$Burst = 1,
  [int]$IntervalMs = 500,
  [int]$Columns = 0
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$src = @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class BgCap {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct WINDOWPLACEMENT {
    public int length, flags, showCmd; public POINT ptMin, ptMax; public RECT rcNormal; }

  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern int GetWindowTextLengthW(IntPtr h);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] static extern bool GetWindowPlacement(IntPtr h, ref WINDOWPLACEMENT p);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")] static extern IntPtr GetWindowLongPtr(IntPtr h, int i);
  [DllImport("user32.dll", EntryPoint="SetWindowLongPtrW")] static extern IntPtr SetWindowLongPtr(IntPtr h, int i, IntPtr v);
  [DllImport("user32.dll")] static extern bool SetLayeredWindowAttributes(IntPtr h, uint key, byte alpha, uint flags);
  [DllImport("user32.dll")] static extern bool GetLayeredWindowAttributes(IntPtr h, out uint key, out byte alpha, out uint flags);
  [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int v, int size);
  [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int v, int size);

  const int GWL_EXSTYLE = -20;
  const long WS_EX_LAYERED = 0x80000, WS_EX_TOOLWINDOW = 0x80;
  const int DWMWA_EXTENDED_FRAME_BOUNDS = 9, DWMWA_CLOAKED = 14, DWMWA_TRANSITIONS_FORCEDISABLED = 3;
  const int SW_SHOWNOACTIVATE = 4, SW_SHOWMINNOACTIVE = 7;

  public static void InitDpi() {
    try { if (SetProcessDpiAwarenessContext(new IntPtr(-4))) return; } catch {}
    try { SetProcessDPIAware(); } catch {}
  }

  public static string Title(IntPtr h) {
    int n = GetWindowTextLengthW(h); var sb = new StringBuilder(n + 1);
    GetWindowTextW(h, sb, sb.Capacity); return sb.ToString();
  }
  public static int Pid(IntPtr h) { uint p; GetWindowThreadProcessId(h, out p); return (int)p; }
  public static bool Cloaked(IntPtr h) { int v = 0; DwmGetWindowAttribute(h, DWMWA_CLOAKED, out v, 4); return v != 0; }

  // Top-level, visible, titled, non-tool, unowned windows (what a user thinks of as "windows").
  public static List<IntPtr> Windows() {
    var list = new List<IntPtr>();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      if (!IsWindowVisible(h)) return true;
      if (GetWindowTextLengthW(h) == 0) return true;
      if (GetWindow(h, 4) != IntPtr.Zero) return true; // GW_OWNER
      long ex = GetWindowLongPtr(h, GWL_EXSTYLE).ToInt64();
      if ((ex & WS_EX_TOOLWINDOW) != 0) return true;
      list.Add(h); return true;
    }, IntPtr.Zero);
    return list;
  }

  static Bitmap Grab(IntPtr h, uint flags, bool shadow, out bool black) {
    RECT wr; GetWindowRect(h, out wr);
    int w = wr.R - wr.L, ht = wr.B - wr.T;
    if (w <= 0 || ht <= 0) throw new Exception("window has zero size");
    var full = new Bitmap(w, ht, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(full)) {
      IntPtr dc = g.GetHdc();
      try { PrintWindow(h, dc, flags); } finally { g.ReleaseHdc(dc); }
    }
    Bitmap result = full;
    if (!shadow) {
      RECT fr;
      if (DwmGetWindowAttribute(h, DWMWA_EXTENDED_FRAME_BOUNDS, out fr, Marshal.SizeOf(typeof(RECT))) == 0) {
        var crop = Rectangle.Intersect(new Rectangle(fr.L - wr.L, fr.T - wr.T, fr.R - fr.L, fr.B - fr.T),
                                       new Rectangle(0, 0, w, ht));
        if (crop.Width > 0 && crop.Height > 0 && (crop.Width != w || crop.Height != ht)) {
          result = full.Clone(crop, PixelFormat.Format32bppArgb); full.Dispose();
        }
      }
    }
    black = IsBlack(result);
    return result;
  }

  static bool IsBlack(Bitmap b) {
    int stepX = Math.Max(1, b.Width / 40), stepY = Math.Max(1, b.Height / 40);
    for (int y = 0; y < b.Height; y += stepY)
      for (int x = 0; x < b.Width; x += stepX) {
        Color c = b.GetPixel(x, y);
        if (c.R > 8 || c.G > 8 || c.B > 8) return false;
      }
    return true;
  }

  // Returns a status string; writes PNG to outPath.
  public static string Capture(IntPtr h, string outPath, bool restoreMin, int settleMs, bool shadow) {
    return Capture(h, new string[] { outPath }, 0, restoreMin, settleMs, shadow, new long[1]);
  }

  // Burst: one frame per outPaths entry, every intervalMs (scheduled from the first frame).
  // A minimized window is restored invisibly ONCE for the whole burst.
  // elapsed[i] receives the capture time of frame i in ms since the first frame.
  public static string Capture(IntPtr h, string[] outPaths, int intervalMs, bool restoreMin, int settleMs, bool shadow, long[] elapsed) {
    if (!IsWindow(h)) throw new Exception("not a window");
    bool wasMin = IsIconic(h);
    IntPtr fg = GetForegroundWindow();
    IntPtr oldEx = GetWindowLongPtr(h, GWL_EXSTYLE);
    bool hadLayered = (oldEx.ToInt64() & WS_EX_LAYERED) != 0;
    uint oKey = 0, oFlags = 0; byte oAlpha = 255; bool hadAttrs = false;
    int one = 1, zero = 0;
    string note = "";

    if (wasMin) {
      if (!restoreMin) throw new Exception("window is minimized (run without -NoRestoreMinimized to restore it invisibly)");
      if (hadLayered) hadAttrs = GetLayeredWindowAttributes(h, out oKey, out oAlpha, out oFlags);
      // Make it fully transparent first, kill the restore animation, then show without activating.
      SetWindowLongPtr(h, GWL_EXSTYLE, new IntPtr(oldEx.ToInt64() | WS_EX_LAYERED));
      SetLayeredWindowAttributes(h, 0, 0, 2 /*LWA_ALPHA*/);
      DwmSetWindowAttribute(h, DWMWA_TRANSITIONS_FORCEDISABLED, ref one, 4);
      ShowWindow(h, SW_SHOWNOACTIVATE);
      Thread.Sleep(settleMs);
      note = "restored-invisibly";
    }

    Bitmap bmp = null; bool black, anyBlack = false, legacy = false;
    var sw = Stopwatch.StartNew();
    try {
      for (int i = 0; i < outPaths.Length; i++) {
        if (i > 0 && intervalMs > 0) {
          long wait = (long)i * intervalMs - sw.ElapsedMilliseconds;
          if (wait > 0) Thread.Sleep((int)wait);
        }
        elapsed[i] = sw.ElapsedMilliseconds;
        bmp = Grab(h, legacy ? 0u : 2u /*PW_RENDERFULLCONTENT*/, shadow, out black);
        if (black && !legacy) {
          bmp.Dispose();
          bmp = Grab(h, 0, shadow, out black);
          if (!black) legacy = true;
        }
        bmp.Save(outPaths[i], ImageFormat.Png);
        bmp.Dispose(); bmp = null;
        if (black) anyBlack = true;
      }
      if (legacy) note = (note + " legacy-printwindow").Trim();
      if (anyBlack) note = (note + " black").Trim();
      return note == "" ? "ok" : note;
    } finally {
      if (bmp != null) bmp.Dispose();
      if (wasMin) {
        ShowWindow(h, SW_SHOWMINNOACTIVE);
        Thread.Sleep(50);
        if (hadLayered && hadAttrs) SetLayeredWindowAttributes(h, oKey, oAlpha, oFlags);
        SetWindowLongPtr(h, GWL_EXSTYLE, oldEx);
        DwmSetWindowAttribute(h, DWMWA_TRANSITIONS_FORCEDISABLED, ref zero, 4);
        if (fg != IntPtr.Zero && GetForegroundWindow() != fg) SetForegroundWindow(fg);
      }
    }
  }
}
"@

if (-not ('BgCap' -as [type])) {
  Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
}
[BgCap]::InitDpi()

function Get-ProcName([int]$procId) {
  try { (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { '?' }
}

$wins = [BgCap]::Windows()

if ($List) {
  foreach ($h in $wins) {
    $procId = [BgCap]::Pid($h)
    $state = if ([BgCap]::IsIconic($h)) { 'minimized' } elseif ([BgCap]::Cloaked($h)) { 'cloaked' } else { 'normal' }
    '{0,-12} {1,-7} {2,-22} {3,-10} {4}' -f ('0x{0:X}' -f $h.ToInt64()), $procId, (Get-ProcName $procId), $state, [BgCap]::Title($h)
  }
  return
}

if (-not $Out) { throw 'Specify -Out <path.png> (or -List).' }

$target = [IntPtr]::Zero
if ($Hwnd) {
  $v = if ($Hwnd -match '^0x') { [Convert]::ToInt64($Hwnd.Substring(2), 16) } else { [int64]$Hwnd }
  $target = [IntPtr]$v
} else {
  $cands = $wins | Where-Object {
    $procId = [BgCap]::Pid($_)
    (-not $ProcessId -or $procId -eq $ProcessId) -and
    (-not $ProcessName -or (Get-ProcName $procId) -like ($ProcessName -replace '\.exe$','')) -and
    (-not $Title -or [BgCap]::Title($_) -like "*$Title*")
  }
  if (-not $ProcessId -and -not $ProcessName -and -not $Title) { throw 'Specify -Hwnd, -ProcessId, -ProcessName or -Title.' }
  $cands = @($cands)
  if ($cands.Count -eq 0) { throw 'No matching window. Run with -List to see candidates.' }
  # Prefer non-cloaked windows (cloaked = on another virtual desktop / hidden UWP frame)
  $target = ($cands | Sort-Object { [BgCap]::Cloaked($_) } | Select-Object -First 1)
}

$outFull = [IO.Path]::GetFullPath($Out)
$dir = [IO.Path]::GetDirectoryName($outFull)
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }

if ($Burst -le 1) {
  $status = [BgCap]::Capture($target, $outFull, -not $NoRestoreMinimized, $SettleMs, [bool]$IncludeShadow)
  [pscustomobject]@{
    hwnd   = ('0x{0:X}' -f $target.ToInt64())
    pid    = [BgCap]::Pid($target)
    title  = [BgCap]::Title($target)
    status = $status
    path   = $outFull
  } | ConvertTo-Json -Compress
  return
}

# ---- burst: N frames -> <Out-without-ext>.frames\frame_NN.png + one labelled contact sheet at -Out ----
$framesDir = [IO.Path]::Combine($dir, [IO.Path]::GetFileNameWithoutExtension($outFull) + '.frames')
if (-not (Test-Path $framesDir)) { New-Item -ItemType Directory -Force $framesDir | Out-Null }
$frames = @(1..$Burst | ForEach-Object { [IO.Path]::Combine($framesDir, ('frame_{0:D2}.png' -f $_)) })
$elapsed = New-Object 'long[]' $Burst
$status = [BgCap]::Capture($target, [string[]]$frames, $IntervalMs, -not $NoRestoreMinimized, $SettleMs, [bool]$IncludeShadow, $elapsed)
$labels = @(0..($Burst - 1) | ForEach-Object { 't+{0} ms' -f $elapsed[$_] })
$winTitle = [BgCap]::Title($target)
$sheetArgs = @{
  Inputs = ($frames -join '||'); Labels = ($labels -join '||'); Out = $outFull
  Title = ('{0}  -  {1} frames, every {2} ms' -f $winTitle, $Burst, $IntervalMs)
}
if ($Columns -gt 0) { $sheetArgs.Columns = $Columns }
$sheet = & (Join-Path $PSScriptRoot 'compose-shots.ps1') @sheetArgs | ConvertFrom-Json
[pscustomobject]@{
  hwnd   = ('0x{0:X}' -f $target.ToInt64())
  pid    = [BgCap]::Pid($target)
  title  = $winTitle
  status = $status
  path   = $outFull
  layout = $sheet.layout
  approxTokens = $sheet.approxTokens
  frames = $frames
  elapsedMs = @($elapsed | ForEach-Object { [long]$_ })
} | ConvertTo-Json -Compress
