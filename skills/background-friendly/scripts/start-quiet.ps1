<#
.SYNOPSIS
  Start a program WITHOUT stealing focus from the user: its first window is shown
  minimized-and-not-activated (SW_SHOWMINNOACTIVE), or hidden with -Hidden.
  stdout/stderr can be redirected to log files. Prints one JSON line with the PID.

.EXAMPLES
  powershell -NoProfile -ExecutionPolicy Bypass -File start-quiet.ps1 -FilePath C:\app\game.exe -Arguments "--debug" -WorkingDirectory C:\app
  ... -File start-quiet.ps1 -FilePath python -Arguments "app.py" -StdOut C:\tmp\out.log -StdErr C:\tmp\err.log
  ... -File start-quiet.ps1 -FilePath C:\tool\cli.exe -Hidden

.NOTES
  Most Win32/WinForms/WPF/Qt apps honour the STARTUPINFO show command for their first
  window. Apps that force their own window state (e.g. call SetForegroundWindow, or
  restore a saved maximized state) may still pop up - prefer the app's headless /
  background flag when one exists. A minimized window can still be captured with
  capture-window.ps1 (it is restored invisibly for the shot).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$FilePath,
  [string]$Arguments = '',
  [string]$WorkingDirectory = (Get-Location).Path,
  [switch]$Hidden,
  [string]$StdOut,
  [string]$StdErr
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$src = @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class QuietStart {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  struct STARTUPINFO {
    public int cb; public string lpReserved, lpDesktop, lpTitle;
    public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
    public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
  }
  [StructLayout(LayoutKind.Sequential)]
  struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
  [StructLayout(LayoutKind.Sequential)]
  struct SECURITY_ATTRIBUTES { public int nLength; public IntPtr lpSecurityDescriptor; public bool bInheritHandle; }

  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern bool CreateProcessW(string app, System.Text.StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit,
    uint flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  static extern IntPtr CreateFileW(string name, uint access, uint share, ref SECURITY_ATTRIBUTES sa, uint disp, uint flags, IntPtr tmpl);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);

  static IntPtr OpenLog(string path) {
    if (String.IsNullOrEmpty(path)) return IntPtr.Zero;
    var sa = new SECURITY_ATTRIBUTES(); sa.nLength = Marshal.SizeOf(sa); sa.bInheritHandle = true;
    // GENERIC_WRITE, FILE_SHARE_READ|WRITE, CREATE_ALWAYS
    IntPtr h = CreateFileW(path, 0x40000000, 3, ref sa, 2, 0x80, IntPtr.Zero);
    if (h == new IntPtr(-1)) throw new System.ComponentModel.Win32Exception();
    return h;
  }

  public static int Start(string cmdLine, string cwd, bool hidden, string outPath, string errPath) {
    var si = new STARTUPINFO(); si.cb = Marshal.SizeOf(si);
    si.dwFlags = 0x1; // STARTF_USESHOWWINDOW
    si.wShowWindow = (short)(hidden ? 0 : 7); // SW_HIDE : SW_SHOWMINNOACTIVE
    IntPtr o = OpenLog(outPath), e = OpenLog(errPath);
    bool inherit = false;
    if (o != IntPtr.Zero || e != IntPtr.Zero) {
      si.dwFlags |= 0x100; // STARTF_USESTDHANDLES
      si.hStdOutput = o; si.hStdError = e != IntPtr.Zero ? e : o; inherit = true;
    }
    // CREATE_NO_WINDOW for console programs so no console window pops up
    uint flags = 0x08000000;
    PROCESS_INFORMATION pi;
    try {
      if (!CreateProcessW(null, new System.Text.StringBuilder(cmdLine), IntPtr.Zero, IntPtr.Zero, inherit, flags, IntPtr.Zero, cwd, ref si, out pi))
        throw new System.ComponentModel.Win32Exception();
    } finally {
      if (o != IntPtr.Zero) CloseHandle(o);
      if (e != IntPtr.Zero) CloseHandle(e);
    }
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
    return pi.dwProcessId;
  }
}
"@
if (-not ('QuietStart' -as [type])) { Add-Type -TypeDefinition $src }

# Resolve bare command names (python, node, ...) via PATH
$exe = $FilePath
if (-not (Test-Path $exe)) {
  $cmd = Get-Command $FilePath -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd) { $exe = $cmd.Source }
}
$exe = [IO.Path]::GetFullPath($exe)
$cmdLine = '"' + $exe + '"' + $(if ($Arguments) { ' ' + $Arguments } else { '' })
$cwd = [IO.Path]::GetFullPath($WorkingDirectory)
foreach ($p in @($StdOut, $StdErr)) {
  if ($p) { $d = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($p)); if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force $d | Out-Null } }
}
$outFull = if ($StdOut) { [IO.Path]::GetFullPath($StdOut) } else { $null }
$errFull = if ($StdErr) { [IO.Path]::GetFullPath($StdErr) } else { $null }

$procId = [QuietStart]::Start($cmdLine, $cwd, [bool]$Hidden, $outFull, $errFull)
[pscustomobject]@{ pid = $procId; exe = $exe; mode = $(if ($Hidden) { 'hidden' } else { 'minimized-noactivate' }); stdout = $outFull; stderr = $errFull } | ConvertTo-Json -Compress
