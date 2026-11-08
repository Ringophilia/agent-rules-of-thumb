---
name: background-friendly
description: "Work without disturbing a user who is using the same Windows PC: capture only the target window (never the full screen), even when covered or minimized, launch GUIs minimized and unfocused, drive them through UI Automation, CDP, logs or tests, and ask before taking over the user's screen, mouse or keyboard. Use before any screenshot, GUI launch or debugging, UI interaction, or computer-use action. Ships zero-dependency PowerShell scripts."
compatibility: 原则通用；scripts/ 需要 Windows + PowerShell 5.1 或更高版本（uia.ps1 首次运行时用 Windows 自带的 .NET Framework csc 编译 uia.cs）
---

# 不打扰用户的后台工作

用户在你工作时**还在正常用这台电脑**。你的工作不能：抢焦点、把窗口弹到前台、动鼠标、往用户正在打字的地方发按键、截下用户的整个屏幕（可能有隐私内容）、留下一堆没关的窗口和进程。

一句话：**能在后台做的，一律在后台做；只看目标窗口，不看整个屏幕；必须动用户的电脑时，先问。**

脚本都在本 skill 目录的 `scripts/` 下（安装到 Claude Code 用户级时是 `~/.claude/skills/background-friendly/scripts/`），只用 Windows 自带的 PowerShell 5.1 和 .NET Framework，无需安装任何东西。脚本保持纯 ASCII，避免 PowerShell 5.1 按 ANSI 码页读取无 BOM 的 UTF-8 而导致乱码。调用方式：

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<scripts>\<脚本>.ps1" ...
```

| 脚本 | 作用 | 打扰用户？ |
|---|---|---|
| `capture-window.ps1` | 截单个窗口（被遮挡/最小化也行）；`-Burst` 按固定间隔连拍多帧 | 否 |
| `start-quiet.ps1` | 最小化+不激活地启动程序，输出写日志 | 否 |
| `uia.ps1` | UI Automation：读控件树、点按钮、填文本、勾选、选择、读文字 | 否 |
| `desktop-input.ps1` | 真实鼠标键盘输入（点击/拖动/滚轮/打字/快捷键），完成后还原 | **是，需先批准** |

---

## 1. 截图：只截目标窗口，不截全屏

**不要**默认用 `mcp__computer-use__screenshot`（或任何截整个桌面的工具）来"看看程序现在什么样"。它截的是用户的整个屏幕，目标窗口还必须在最前面。

按下面顺序选，越靠前越好：

| 目标 | 用什么 |
|---|---|
| 只想知道界面上有什么文字/控件 | 不截图：`uia.ps1 -Tree`、日志、浏览器面板的 `read_page`/`get_page_text` |
| 网页 / 本地 dev server | 内置浏览器面板 `mcp__Claude_Browser__*`；或 Playwright/Puppeteer **headless** 截图 |
| Electron / WebView2 / CEF | 带 `--remote-debugging-port` 启动，CDP `Page.captureScreenshot`；或 `webContents.capturePage()` |
| 自己能改代码的程序/游戏 | 程序内置截图：Unity `ScreenCapture.CaptureScreenshot`/RenderTexture，Godot `get_viewport().get_texture().get_image().save_png()`，Qt `widget.grab()`，WPF `RenderTargetBitmap`，加个调试命令或热键触发 |
| 任意桌面窗口（被遮挡、在后面、最小化） | `capture-window.ps1` |
| Android 设备/模拟器 | `adb exec-out screencap -p > shot.png` |
| Blender | Blender MCP 的 `look` |
| 任务本身就是看用户的桌面 | 全屏截图 —— 走第 4 节的批准流程 |

### capture-window.ps1

```powershell
capture-window.ps1 -List                                   # hwnd、pid、进程名、状态、标题
capture-window.ps1 -ProcessName MyGame -Out "<scratchpad>\shot.png"
capture-window.ps1 -Title "设置" -Out "<scratchpad>\shot.png"
capture-window.ps1 -ProcessId 1234 -Out "<scratchpad>\shot.png"
capture-window.ps1 -Hwnd 0x30C9E -Out "<scratchpad>\shot.png"
```

截完用 Read 工具打开 PNG。

- 被遮挡的窗口直接截，不动它（`PrintWindow` + `PW_RENDERFULLCONTENT`）。
- 最小化的窗口会先设成完全透明、关掉动画，再不激活地还原，截完重新最小化，样式和前台窗口都恢复原样。用户看不到，焦点也不变。不想还原就加 `-NoRestoreMinimized`；重绘慢的窗口加 `-SettleMs 1000`。
- `status` 的取值有 `ok`、`restored-invisibly`、`legacy-printwindow`、`black`。`black` 说明 DirectX/OpenGL/Vulkan 游戏或独占全屏的画面拿不到，这时改用程序内置截图，或改成窗口化模式再试，**不要**退回全屏截图。
- `cloaked` 表示窗口在别的虚拟桌面上或者是隐藏的 UWP 框架，可能截不到。
- 截图放 scratchpad，不要放进用户的项目目录。

### 1.1 连拍：观察一段过程

加载进度、动画、闪烁、一闪而过的弹窗，单张截图抓不住，用 `-Burst` 按固定间隔连拍：

```powershell
# 帧存在 <Out 去掉扩展名>.frames\frame_NN.png；JSON 里有每帧路径和 "t+毫秒" 标签
capture-window.ps1 -ProcessName MyApp -Burst 6 -IntervalMs 300 -Out "<s>\burst.png"
```

- 要对比这些帧，**拼成一张带标签的网格再看**，不要一张张打开（见 compare-in-one-image；JSON 里的 `labels` 可以直接当每格的标签）。
- 连拍是为了**观察过程**，不是为了等待完成。等某件事完成，用条件判断（见 no-blind-wait），完成后再截一张。
- 要给 `desktop-input.ps1` **量坐标**，在单张原图上量。

---

## 2. 调试和运行：尽量在后台

### 2.1 先想想能不能完全不要窗口
- 优先用测试、CLI、脚本验证逻辑，看输出和日志，不要开 GUI 去点。
- 能用 headless 模式就用：
  - 浏览器：`--headless=new`（Playwright/Puppeteer 默认就是 headless）
  - Unity：`-batchmode -nographics -logFile <path>`
  - Godot：`--headless`
  - Blender：`blender -b file.blend -P script.py`
  - Electron：`show: false` 加 CDP
  - Qt：`QT_QPA_PLATFORM=offscreen`
  - 控制台程序：直接跑，输出重定向到日志
- 耗时长的任务用 `run_in_background`，跑完会通知你，不要轮询。

### 2.2 必须开 GUI 时：最小化且不激活地启动
不要用 `Start-Process app.exe`、`start xxx`、`explorer xxx`、`Invoke-Item` 启动程序，它们会把窗口抢到前台。用：

```powershell
start-quiet.ps1 -FilePath "C:\path\app.exe" -Arguments "--debug" -WorkingDirectory "C:\path" `
                -StdOut "<scratchpad>\app.out.log" -StdErr "<scratchpad>\app.err.log"
# 纯控制台/不需要界面：加 -Hidden
```

脚本返回 PID。之后用 `capture-window.ps1 -ProcessId <pid>` 看画面，用 `uia.ps1 -ProcessId <pid>` 操作。少数程序会强行弹到前台，这种情况优先找它的 headless/后台参数。

### 2.3 和 GUI 交互：先用后台方式
按顺序选，前 4 种都不打扰用户：

1. 程序自带的调试接口：命令行参数、配置文件、调试控制台、IPC/HTTP 调试端点、测试框架（Playwright、Appium/WinAppDriver、Unity Test Framework 等）
2. Web/Electron：CDP / Playwright
3. 原生 Windows 程序：`uia.ps1`（UI Automation）。窗口最小化也能操作，脚本会临时把它不可见地还原，做完再最小化。
   ```powershell
   uia.ps1 -Title "My App" -Tree                              # 先看控件：类型、Name、AutomationId、支持的 Pattern
   uia.ps1 -Title "My App" -Name "确定" -Invoke                # 点按钮/菜单项
   uia.ps1 -Title "My App" -ControlType Edit -SetValue "hello" # 填文本框（-Index n 选第 n 个）
   uia.ps1 -Title "My App" -AutomationId chkFast -Toggle       # 勾选框
   uia.ps1 -Title "My App" -Name "Item 3" -Select              # 列表/Tab/单选
   uia.ps1 -Title "My App" -Name "文件" -Expand                 # 展开菜单/下拉框/树节点
   uia.ps1 -Title "My App" -Name "状态*" -GetText               # 读文字（Name 支持 * ? 通配）
   ```
   支持 Win32、WinForms、WPF、UWP、WinUI、Qt（开了无障碍）和部分 Chromium。游戏和自绘界面通常什么都读不到，这类程序只能用第 1 种方式或第 4 节的方式。
4. Win32 消息：`PostMessage`/`SendMessage`（`WM_COMMAND`、`BM_CLICK`、`WM_SETTEXT`、`WM_KEYDOWN`）发给目标窗口句柄，不要用全局的 `SendInput`。
5. 以上都不行时，用真实鼠标键盘，**必须先走第 4 节的批准流程**。

### 2.4 收尾
- 记下自己启动的 PID，调试完关掉。只关自己启动的进程，**绝不**动用户自己开的。
- 临时文件、日志、截图都放 scratchpad。
- 长时间占满 CPU 的构建可以把优先级降到 `BelowNormal`。

---

## 3. 不要做的事
- 不要为了截图或操作方便就用 `SetForegroundWindow`、`ShowWindow(SW_RESTORE)`、`AppActivate` 把窗口切到前台。
- 不要用默认程序打开文件或 URL（`Start-Process report.html`、`start https://...`、`explorer .`）。
- 不要弹 `MessageBox`、`Read-Host`、`pause`、`msg`。
- 未经批准，不要发全局按键（`SendKeys`、`SendInput`、`keybd_event`），不要移动鼠标（`SetCursorPos`）。
- 不要改分辨率、主题、音量、电源计划等系统设置，不要播放声音。
- 不要先截全屏再裁剪。

---

## 4. 必须使用用户的屏幕、鼠标、键盘时：先请求批准

以下情况都算"使用用户电脑"：
- 全屏截图
- 把窗口切到前台
- 移动或点击真实鼠标、发送真实按键
- computer-use 的任何点击、输入、滚动、截图
- 运行 `desktop-input.ps1`

### 4.1 请求批准
动手前用 `AskUserQuestion` 问（没有这个工具就在聊天里问，然后结束这一轮等回复）。问题要单独能看懂，写清：
- 要操作哪个窗口或程序
- 具体做什么（例如"点击登录按钮、输入测试账号、按回车"）
- 大约占用多久（例如"约 5 秒，期间请别动鼠标键盘"）
- 为什么后台方式不行（一句话）

选项给"可以，现在做"和"先不要"。

### 4.2 未批准就暂停
- 用户拒绝、没回答、或答复不明确，都**不要执行**。
- 先做不需要占用电脑的部分（读代码、写代码、跑测试、后台截图）。剩下必须前台的部分告诉用户：已经暂停，等你方便时告诉我。
- 不要换一种同样打扰用户的方式绕过去，不要自己认定"应该可以"。
- 批准只对这一次说明过的操作有效。之后要做新的前台操作，要再问一次。只有用户明确说过类似"这个会话里随便用"时才例外。

### 4.3 批准后：有 computer-use 就用 computer-use
1. 先确认 computer-use 是否可用：工具列表里有 `mcp__computer-use__*`；如果它只是 deferred 工具，用 `ToolSearch` 搜 `computer-use`（max_results 30）一次全部加载。如果有 `anthropic-skills:computer-use` skill，先读它。
2. 用 `request_access` 申请要操作的应用，`computer_batch` 把动作一次做完，不要来回切窗口。
3. 遵守 computer-use 的分级限制：浏览器只能看，终端/IDE 只能点。网页操作改用浏览器工具。
4. 做完把用户原来的窗口切回前台，告诉用户"好了，可以继续用了"。

### 4.4 没有 computer-use 时：用自带脚本或其他办法
**首选 `desktop-input.ps1`。**它会把目标窗口切到前台，按顺序执行步骤，结束后自动还原：用户原来的前台窗口、鼠标位置，以及目标窗口原本的最小化状态。

```powershell
# 用 powershell -File 调用时，所有步骤写在一个字符串里，用 "||" 分隔
desktop-input.ps1 -Title "My App" -Steps "click:120,80||key:ctrl+a||type:你好 hello||key:enter"
desktop-input.ps1 -ProcessName game -WindowCoords -Steps "click:400,300||wait:500||key:esc"
desktop-input.ps1 -Title "My App" -Steps "drag:10,10,200,200||scroll:-3||rclick:50,50"
```

- 支持的步骤：`click:X,Y` / `dclick:X,Y` / `rclick:X,Y` / `move:X,Y` / `drag:X1,Y1,X2,Y2` / `scroll:N`（正数向上）/ `type:文本`（Unicode，支持中文，`\n` 表示回车）/ `key:组合键`（如 `enter`、`esc`、`ctrl+s`、`alt+f4`、`f5`、`ctrl+shift+t`、`pagedown`）/ `wait:毫秒`
- 坐标默认相对窗口**客户区**，单位是物理像素。加 `-WindowCoords` 后，坐标相对 `capture-window.ps1` 截图的左上角，这样从截图上量坐标最方便。`-ScreenCoords` 用屏幕绝对坐标。
- 推荐流程：`capture-window.ps1` 截图 → 量坐标 → `desktop-input.ps1 -WindowCoords` 执行 → `capture-window.ps1` 再截一张确认结果。
- `-NoRestore` 会让窗口留在前台，一般不要用。

**其他办法**（用户电脑上已经装了才用；要安装新东西先问用户）：
- AutoHotkey v2：`ControlClick` / `ControlSend` / `ControlSetText` 可以对指定控件发消息，很多程序不需要前台
- Python + pywinauto：`backend="uia"` 下用 `.invoke()` / `.set_edit_text()` 是后台操作；`.click_input()` / `.type_keys()` 是前台操作
- Python + pyautogui：纯前台键鼠，等同于 `desktop-input.ps1`
- NirCmd：`nircmd win activate`、`sendkeypress` 等简单前台操作

用这些前台方式同样要先走 4.1 的批准流程，做完一样要还原前台窗口和鼠标位置。

---

## 相关 skill

- **screenshot-first**：决定"什么时候必须拿一手证据"，本 skill 决定"怎么拿才不打扰用户"。需要截图作为证据时，用 `capture-window.ps1` 只截目标窗口。
- **dialog-handling**：处理 Win32 对话框时，它的 `list-windows.ps1` 和 `press-button.ps1 -Method Command`（WM_COMMAND）都是后台方式，可以直接用。子控件枚举为空时（WPF/Qt/Electron），改用本 skill 的 `uia.ps1`。它列出的 BmClick、键盘 Enter/Esc、坐标点击这几步需要激活窗口，执行前要先走第 4 节的批准流程。
- **no-blind-wait**：等窗口重绘或程序启动时，按条件判断是否完成，不要固定 sleep。`-SettleMs` 只是截图前留给窗口重绘的时间。
