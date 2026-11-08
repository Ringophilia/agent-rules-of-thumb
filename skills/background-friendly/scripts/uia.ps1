<#
.SYNOPSIS
  Background control of native Windows apps through UI Automation: read the control
  tree, click buttons / menu items, set text, toggle checkboxes, select items, read text.
  Does NOT move the mouse, does NOT send global keystrokes, does NOT need the window to
  be in front. Covered windows work as-is; minimized windows are restored invisibly
  (transparent, not activated) for the call and minimized again afterwards.

.EXAMPLES
  # Dump the control tree (pick the window like capture-window.ps1)
  uia.ps1 -ProcessName notepad -Tree
  uia.ps1 -Title "My App" -Tree -Depth 6 -Max 400

  # Act on a control, found by -Name (wildcards ok) / -AutomationId / -ControlType / -ClassName
  uia.ps1 -Title "My App" -Name "OK" -Invoke
  uia.ps1 -Title "My App" -ControlType Edit -SetValue "hello"          # first Edit box
  uia.ps1 -Title "My App" -AutomationId "textBox1" -SetValue "hello"
  uia.ps1 -Title "My App" -Name "Fast mode" -Toggle
  uia.ps1 -Title "My App" -Name "Item 3" -Select
  uia.ps1 -Title "My App" -Name "status*" -GetText
  uia.ps1 -Title "My App" -Name "File" -Expand                         # menus, combos, tree nodes
  uia.ps1 -Title "My App" -Name "Save*" -ControlType MenuItem -Invoke -Index 1

.NOTES
  Works with Win32 / WinForms / WPF / UWP / WinUI / Qt (accessibility on) / partly Chromium.
  Games and custom-drawn UIs usually expose nothing -> use the app's own debug hooks.
  The C# helper (uia.cs) is compiled to uia.exe on first use with the csc.exe that ships with
  the .NET Framework 4.x in Windows. Prints JSON (actions) or an indented tree (-Tree).
#>
[CmdletBinding()]
param(
  [string]$Hwnd, [int]$ProcessId, [string]$ProcessName, [string]$Title,
  [switch]$Tree, [int]$Depth = 8, [int]$Max = 300,
  [string]$Name, [string]$AutomationId, [string]$ControlType, [string]$ClassName, [int]$Index = 0,
  [switch]$Invoke, [string]$SetValue, [switch]$Toggle, [switch]$Select,
  [switch]$Expand, [switch]$Collapse, [switch]$GetText, [switch]$NoRestoreMinimized
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$cs  = Join-Path $PSScriptRoot 'uia.cs'
$exe = Join-Path $PSScriptRoot 'uia.exe'
if (-not (Test-Path $exe) -or (Get-Item $cs).LastWriteTime -gt (Get-Item $exe).LastWriteTime) {
  $fw = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
  if (-not (Test-Path "$fw\csc.exe")) { $fw = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319' }
  $out = & "$fw\csc.exe" -nologo -optimize -out:"$exe" -r:"$fw\WPF\UIAutomationClient.dll" -r:"$fw\WPF\UIAutomationTypes.dll" "$cs" 2>&1
  if ($LASTEXITCODE -ne 0) { throw "compiling uia.cs failed:`n$out" }
}

$a = @()
if ($Hwnd)        { $a += '--hwnd', $Hwnd }
if ($ProcessId)   { $a += '--pid', $ProcessId }
if ($ProcessName) { $a += '--process', $ProcessName }
if ($Title)       { $a += '--title', $Title }
if ($Tree)        { $a += '--tree', '--depth', $Depth, '--max', $Max }
if ($Name)        { $a += '--name', $Name }
if ($AutomationId){ $a += '--id', $AutomationId }
if ($ControlType) { $a += '--type', $ControlType }
if ($ClassName)   { $a += '--class', $ClassName }
if ($Index)       { $a += '--index', $Index }
if ($Invoke)      { $a += '--invoke' }
if ($PSBoundParameters.ContainsKey('SetValue')) { $a += '--set-value', $SetValue }
if ($Toggle)      { $a += '--toggle' }
if ($Select)      { $a += '--select' }
if ($Expand)      { $a += '--expand' }
if ($Collapse)    { $a += '--collapse' }
if ($GetText)     { $a += '--get-text' }
if ($NoRestoreMinimized) { $a += '--no-restore-minimized' }

& $exe @a
exit $LASTEXITCODE
