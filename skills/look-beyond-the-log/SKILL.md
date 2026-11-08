---
name: look-beyond-the-log
description: "When a program you built or run fails, the real error is often not in its log: a popup from ANOTHER process (crash reporter WerFault, the loader's 'xxx.dll was not found', a VC++ runtime/assert box, .NET/JIT debugger, Java/Electron/Python launcher, a helper/updater/installer, antivirus, SmartScreen, UAC), the event log, a crash dump, or stderr nobody captured. Sweep all of these for the time of the failure before rereading the log again. Use when a program errors, crashes, exits early, hangs, or its log is empty, stops mid-way or shows nothing wrong. Ships a read-only PowerShell sweep script."
compatibility: 原则通用；scripts/ 需要 Windows + PowerShell 5.1 或更高版本
---

# 日志之外的报错

真实事故：智能体做的程序启动报错，它一遍遍读程序自己的日志、加日志、再读，始终找不到原因。答案一直摆在屏幕上：**另一个进程**弹了一个报错窗口（系统加载器提示缺 DLL / 运行库）。它没去看，因为它只盯着自己程序的日志。

**日志只记录程序"自己来得及、也想到要写下"的东西。** 很多失败恰好发生在程序写不了日志的地方。

## 0. 什么时候该怀疑"错误不在日志里"

出现任意一条，就停止反复读日志，做第 2 节的全面排查：

- 日志是空的，或者停在一行看起来正常的地方，后面再也没有增长
- 日志里没有错误，但程序明明失败了 / 退出了 / 没反应
- 日志的修改时间早于这次失败（读的是上一次运行的日志，或者写到别处去了）
- 退出码非 0 但日志里没有对应的错误；或者退出码是下面这些"死在日志之前"的值
- 程序"卡住"、窗口不出来、命令一直不返回
- 读了两遍日志、加过一轮日志，还是定位不到

| 退出码 | 十进制 | 含义 | 错误通常出现在 |
| --- | --- | --- | --- |
| `0xC0000135` | -1073741515 | 找不到 DLL | 系统弹窗「由于找不到 xxx.dll，无法继续执行代码」 |
| `0xC000007B` | -1073741701 | 32/64 位 DLL 混用 | 系统弹窗「应用程序无法正常启动(0xc000007b)」 |
| `0xC0000139` | -1073741511 | DLL 里找不到入口点 | 系统弹窗「无法定位程序输入点」 |
| `0xC0000005` | -1073741819 | 访问违规（崩溃） | WerFault 弹窗、事件日志 1000、`CrashDumps` |
| `0xC0000409` | -1073740791 | 栈溢出检测 / fast fail | 同上 |
| `0xC00000FD` | -1073741571 | 栈溢出 | 同上 |
| `0xE0434352` | -532462766 | 未处理的 .NET 异常 | 事件日志 `.NET Runtime` 1026、JIT 调试器弹窗 |
| `3` | 3 | C 运行库 `abort()` / 断言失败 | VC++ Runtime / Debug Assertion 弹窗、stderr |
| `0xC0000142` | -1073741502 | DLL 初始化失败 | 系统弹窗、事件日志 |
| `0xC0000022` | -1073741790 | 拒绝访问 | 杀软 / SmartScreen / 权限弹窗 |

退出码看不懂时，`certutil -error <code>` 或搜一下十六进制值，比再读一遍日志快。

## 1. 错误可能在哪些地方

| 位置 | 典型内容 | 为什么日志里没有 |
| --- | --- | --- |
| **系统加载器弹窗** | 缺 DLL、缺 VC++ / .NET 运行库、入口点找不到、位数不对 | 进程还没执行到你的第一行代码就死了 |
| **崩溃报告进程**（`WerFault.exe`） | 「xxx 已停止工作」 | 崩溃那一刻程序已经失去控制 |
| **运行库自己的弹窗** | VC++ Debug Assertion、`abort()`、.NET 未处理异常 / JIT 调试器、Java「A Java Exception has occurred」、Electron「A JavaScript error occurred in the main process」、PyInstaller「Failed to execute script」 | 由运行库在你的日志框架之外直接弹出 |
| **你启动的其他程序** | 子进程、辅助进程、更新器、启动器、安装器、插件宿主、浏览器、模拟器、数据库自己报的错 | 它们有自己的窗口和日志，不写你的日志 |
| **系统拦截** | 杀软隔离 / 拦截通知、SmartScreen「已保护你的电脑」、UAC 提权框（在安全桌面上，截图拍不到）、防火墙询问 | 程序根本没被允许运行，或某个文件被删了 |
| **Windows 事件日志** | `Application Error` 1000、`.NET Runtime` 1026、`SideBySide` 33（清单 / 运行库版本错）、`Windows Error Reporting` 1001、System 日志 `Application Popup` 26（系统弹窗的文字副本） | 系统记录，不在程序目录 |
| **崩溃转储与 WER 报告** | `%LOCALAPPDATA%\CrashDumps\*.dmp`、`...\WER\ReportArchive` | 同上 |
| **没被捕获的 stderr** | 用 `Start-Process`、双击、GUI 子系统、服务方式启动时，stderr 直接丢了 | 程序把错误打到 stderr，而不是日志文件 |
| **别的日志** | 同一程序的另一个日志文件（按日期、按进程分）、`%TEMP%`、`%APPDATA%`、IDE 输出窗口、Web 浏览器控制台 vs 服务端日志 | 你读的不是正在写的那一份 |

其他平台同理：Linux 看 `journalctl`、`dmesg`（OOM killer、segfault）、core dump；macOS 看 `~/Library/Logs/DiagnosticReports`；容器看 `docker inspect` 的 `OOMKilled` / `ExitCode`；网页看浏览器控制台和网络面板；CI 看前置 job 和 runner 自己的日志。

## 2. 做法：按时间点全面取证

**1）复现之前记下时间点。** 之后所有证据都按"这个时间点之后"来筛，避免把旧的弹窗、旧的日志当成这次的结果。

**2）用能拿到 stderr 和退出码的方式启动。**

```powershell
$t = Get-Date
$p = Start-Process .\app.exe -PassThru -RedirectStandardError err.txt -RedirectStandardOutput out.txt -WindowStyle Minimized
$null = $p.Handle                         # 不先取一次 Handle，PS 5.1 里 ExitCode 会是空的
$p.WaitForExit(30000) | Out-Null          # 带超时，不要无限等
$p.HasExited; $p.ExitCode                 # 退出码对照第 0 节的表
```

**3）一次扫完所有位置**（本 skill 自带脚本，只读，不激活、不关闭任何窗口，不截图，不打扰用户）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/collect-errors.ps1 -Since $t -ProcessId $p.Id
# 加 -IncludeHidden 看隐藏窗口，加 -Json 给程序读
```

它输出四部分：

- **所有进程**的弹窗及其文字（不只是你的进程；`RELATED` 标出你的进程树，`REPORTER` 标出 WerFault / consent / smartscreen 这类替别人报错的进程）
- 这个时间点之后新启动的进程（有没有冒出 WerFault、更新器、另一个实例）
- 事件日志里的错误、WER 记录、`Application Popup`
- 新生成的崩溃转储和 WER 报告

**4）再回到日志**，这时你已经知道错误是什么，读日志是为了找它的上下文，而不是盲找。

没有脚本可用时（其他平台、受限环境），手动覆盖同样的几处：枚举顶层窗口（见 dialog-handling 的 `list-windows.ps1 -All`）、`Get-WinEvent -FilterHashtable @{LogName='Application';Level=1,2;StartTime=$t}`、`Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Application Popup';StartTime=$t}`、看 CrashDumps 目录。

## 3. 找到之后

- **先把弹窗原文抄下来，写进工作记录和给用户的汇报**，再处理。关掉之后这条线索就没了。怎么读、怎么安全地关，见 dialog-handling。
- 想看弹窗长什么样，只截那个窗口（background-friendly 的 `capture-window.ps1 -Hwnd`），不截全屏。
- 弹窗属于另一个进程时，搞清楚**那个进程是谁拉起的、为什么失败**：它可能是你的程序依赖的服务、子进程或安装器，修的应该是它，而不是你的主程序。
- 有崩溃转储就用它（WinDbg `!analyze -v`、Visual Studio 打开 .dmp），它比任何日志都准。
- 修完之后，用同样的方式再扫一遍，确认弹窗和事件日志里的错误**都不再出现**（screenshot-first：拿一手证据再说修好了）。

## 4. 常见误区

| 误区 | 实际 |
| --- | --- |
| "日志里没报错，所以不是程序的问题" | 程序可能根本没跑到写日志的地方 |
| "我只关心我自己的进程" | 报错的经常是别的进程：WerFault、加载器、杀软、子进程 |
| "截图里没有弹窗" | 弹窗可能被挡住、在另一个显示器、在安全桌面（UAC）、或者已经被谁关掉了；事件日志里的 `Application Popup` 会留下文字副本 |
| "再加点日志就能定位" | 死在加载阶段的程序，加多少日志都不会执行 |
| "弹窗挡路，先关掉再说" | 关掉之前不读，等于扔掉唯一的诊断信息 |
| "看到的这个弹窗就是这次的错误" | 可能是上次运行留下的；按时间点筛 |

## 检查清单

- [ ] 复现前记下时间点，用能拿到退出码和 stderr 的方式启动
- [ ] 退出码对照第 0 节，判断是不是"死在日志之前"
- [ ] 扫一遍：所有进程的弹窗、新进程、事件日志、崩溃转储、stderr
- [ ] 弹窗原文先记录、再汇报、再处理
- [ ] 弹窗属于别的进程时，追到那个进程为什么失败
- [ ] 确认读的日志就是这次运行正在写的那一份（看修改时间）
- [ ] 修好后再扫一遍，确认错误真的消失
