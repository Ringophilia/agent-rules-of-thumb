---
name: dialog-handling
description: 处理阻塞式交互：Windows 对话框、网页模态框、浏览器原生 alert/confirm、终端 y/n 或密码提示、分页器、安装向导、二次验证。当点击"没反应"、程序看似卡死、命令长时间无输出但进程还活着、弹窗关不掉、或需要靠弹窗内容判断当前状态时使用。这类阻塞物常被遮挡而截图看不到、没有标准控件 ID、不响应常规关闭消息，有时它本身就是解决问题的入口。给出预防 → 发现 → 读取 → 判定 → 处理 → 循环的完整流程，附可直接运行的 Windows 窗口枚举与按钮点击脚本。Use when a click does nothing, an app looks frozen, a CLI hangs waiting for input, or a modal/dialog blocks automation.
compatibility: 原则通用；scripts/ 需要 Windows + PowerShell 5.1 或更高版本
---

# 阻塞式交互的处理

不只是 Windows 对话框：网页模态框、浏览器原生弹窗、终端提示、安装向导、CI 确认门、二次验证都是一类东西。**它在等人回答，回答之前整个流程停住。**

## 0. 能预防就别处理

不弹出来的弹窗最省事。运行命令之前，先想想它会不会停下来问你：

| 场景 | 预防方式 |
| --- | --- |
| apt / yum / choco / winget | `-y`、`DEBIAN_FRONTEND=noninteractive`、`--accept-package-agreements` |
| git | `GIT_TERMINAL_PROMPT=0`、`--no-edit`、`-m "..."`、`git --no-pager` |
| npm / npx | `npx --yes`、`npm init -y` |
| ssh / scp | `-o BatchMode=yes`（宁可立刻失败，也不要挂着等密码） |
| 分页器 | `PAGER=cat`、`--no-pager`、`| cat` |
| PowerShell | `powershell -NonInteractive`；`-Confirm:$false` 只用在确实要执行的操作上 |
| 安装包 | `/S`、`/quiet`、`/silent`、`msiexec /qn` |
| 浏览器自动化 | 先注册 dialog 处理器，再触发可能弹窗的动作 |

**命令长时间没有输出、进程却还在**：先怀疑它在等输入（`Password:`、`[y/N]`、`--More--`），别急着怀疑它算得慢。

## 1. 它可能完全不可见

截图只能拍到最上层。一个 `Visible=True` 的对话框完全可能压在别的窗口下面，截图里一条边都看不到，却在阻塞主窗口的消息循环。

典型症状：点击没反应、界面不刷新、程序"卡住"。**这时必须做结构枚举，不能只靠截图。**

**Windows**：用自带脚本（只读，不改动任何窗口）：

```powershell
# 所有顶层窗口，含隐藏的；只看标准对话框类
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/list-windows.ps1 -All -Class '#32770'
# 只看某个进程的窗口
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/list-windows.ps1 -All -ProcessId 1234
```

判断"是不是它挡着"，可靠程度从高到低：
1. 对话框的 `Owner` 正好是目标窗口 → 就是它
2. 目标窗口 `Enabled=False` → 几乎可以确定有模态框挡着，去找属于同一进程的对话框
3. 两者矩形重叠 → 只能作为参考

`Hung=True` 说明程序本身已经无响应，这和"被弹窗挡住"是两回事，不要混淆。

**Web**：
- DOM 里的模态框：`[role=dialog]`、`[aria-modal=true]`、`<dialog open>`、铺满视口且 z-index 很高的固定定位遮罩。iframe 和 shadow DOM 里面也要查。
- 浏览器**原生** `alert / confirm / prompt / beforeunload`：不在 DOM 里，页面 JS 会被整个冻结。只能用自动化工具的 dialog API 来处理。
- 自动化工具报 "element click intercepted"、"another element would receive the click"：说明有遮罩挡着，报错里通常会给出遮罩元素。

**终端**：看最后一行输出，看进程是否还活着、是否在读 stdin。

## 2. 先读，再处理

阻塞物上的文字往往是**唯一**的状态信息。处理之前先把它读下来：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/list-windows.ps1 -Children 0x00FD0EA6
# 输出每个子控件的 Text / Class / CtrlId / 坐标：正文、各按钮文字和 ID 一目了然
```

实测中读到过的内容：

- 「应用程序已经运行！」→ 单实例冲突，不是崩溃
- 「您可能在压缩包内运行」→ 路径检测误判
- 「请在 42 分钟后再换机使用」→ 授权绑定限制，不是密码错
- 「解绑成功，本月还可免费解绑 9 次」→ 操作已经成功，不需要重试

**不读内容就点掉，等于扔掉唯一的诊断线索。** 读到的内容要写进你的工作记录或汇报里。

## 3. 判定：障碍，还是入口

反面教训：一个反复弹出的「您确认要解绑吗？」被当成噪声，一次次关掉。实际上它就是出路：账号绑在旧机器上导致登录失败，点「确定」解绑之后才能继续。

| 弹窗内容和当前目标的关系 | 处理 |
| --- | --- |
| 无关（公告、广告、更新提示） | 关掉；有"不再提示"就勾上 |
| 报告了一个状态（错误、成功、限制） | 记下来，用它修正对现状的判断，再关掉 |
| 要你做的决定**正是**解决当前失败所需要的 | 入口，见下面的安全规则 |
| 要你做的决定和目标无关（比如"确认删除？"） | 取消 |
| 看不懂，或者不确定 | 先别动，把原文报告给用户 |

**入口经常是不可逆操作**（解绑、删除、覆盖、提交、付款、授权）。点「确定」之前：
- 用户的请求里已经明确包含这个动作 → 执行，并在汇报里写明
- 没有包含 → 把弹窗原文和你的判断告诉用户，等确认

"为了让流程继续下去"不能成为替用户做不可逆决定的理由。

## 4. 处理的可靠顺序

### Windows

自绘控件、老式 Win32 框架、受保护的程序不一定有标准的 IDOK(1) / IDCANCEL(2)，`WM_CLOSE` 也可能不起作用。按下面的顺序试，**每一步之后都重新枚举，确认它真的消失了**：

```
1. WM_COMMAND 发给按钮的父窗口（默认方法，等价于一次真实点击，不要求窗口处于激活状态）
     scripts/press-button.ps1 -Button <按钮hwnd>
2. 激活对话框后发 BM_CLICK
     scripts/press-button.ps1 -Button <按钮hwnd> -Method BmClick
   （注意：对话框不是活动窗口时，BM_CLICK 可能静默失败）
3. 子控件枚举结果为空 → 说明是 WPF / Qt / Electron / 自绘界面，改用 UI Automation 的 InvokePattern
     background-friendly/scripts/uia.ps1 -Hwnd <对话框hwnd> -Tree   然后   -Name <按钮名> -Invoke
4. 激活后发键盘 Enter / Esc（Esc 通常等于取消）
5. 坐标点击按钮中心（需要窗口在最上层；注意 DPI 缩放，脚本输出的是物理像素）
6. WM_CLOSE：scripts/press-button.ps1 -Dialog <对话框hwnd> -Method Close
   （通常等于"取消"或右上角 X，有些程序会把它当成"否"）
```

第 1、3、6 步不需要激活窗口；第 2、4、5 步会把窗口切到前台、动用户的鼠标键盘。如果用户正在用这台电脑，执行这几步之前按 background-friendly 第 4 节先请求批准，没批准就暂停。

几个坑：
- 跨进程**不要用 `SendMessage`**。对方无响应时，你的脚本也会跟着卡死。用 `PostMessage`，或带超时的 `SendMessageTimeout`（两个脚本都是这样实现的）。
- "确定通常是第一个按钮"并不可靠，要按读出来的 `Text` 或 `CtrlId` 来选。

### Web / 终端

顺序是同一个思路：
- Web：语义定位（role=button 加按钮名、`[data-testid]`）→ 键盘 Enter / Esc → 最后才用坐标点击。原生弹窗只能走 dialog API。
- 终端：首选**杀掉进程，加上非交互参数重新跑**（回到第 0 节）；不行再往 stdin 写答案。

## 5. 多个阻塞物：循环，并且设上限

关掉一个后常常还有下一个（公告 → 公告 2 → 确认框 → 结果框）：

```
for 第 1..10 轮:
    重新枚举 → 没有阻塞物就退出
    读内容 → 记录
    判定（第 3 节）→ 处理（第 4 节）
    等待"它消失"这个条件成立（不要固定 sleep，见 no-blind-wait）
超过上限仍有阻塞物 → 停下来，报告每一轮读到的内容
```

**同一个弹窗关掉后又出现，说明它不是噪声。** 停止循环，回到第 3 节，重新判断它是不是入口。

## 6. 定位用结构特征，不用文本

按文字 `-match` 来找窗口，脚本换个环境就可能静默失效。常见根因：**Windows PowerShell 5.1 会按系统 ANSI 码页读取不带 BOM 的 UTF-8 脚本**，脚本里的中文字面量会变成乱码。

```powershell
# 不可靠
$dlg = $wins | Where-Object { $_.Text -match '公告' }

# 可靠：类名、尺寸、所属进程、控件 ID
$dlg = $wins | Where-Object { $_.Class -eq '#32770' -and $_.Pid -eq $target -and $_.W -gt 150 }
$btn = $kids | Where-Object { $_.Class -eq 'Button' -and $_.CtrlId -eq 1 }
```

确实需要匹配中文时：脚本保存为 **UTF-8 with BOM**，或者脚本只用 ASCII，再从外部文件或参数传入中文。

## 7. 清场：只清你自己制造的

你自己开出来的控制台、编辑器、报错窗口会挡住目标界面。清场时**只关你启动过的进程**，所以启动时就要记下 PID：

```powershell
$spawned = @()
$p = Start-Process notepad.exe -PassThru; $spawned += $p.Id
# ... 自动化操作 ...
$spawned | ForEach-Object { Stop-Process -Id $_ -ErrorAction SilentlyContinue }
```

**永远不要按进程名批量杀**（`powershell`、`conhost`、`chrome`、`explorer`……）。这会杀掉用户自己的终端和工作内容，还可能杀掉正在运行你的宿主进程。分不清是不是你启动的窗口，就把它最小化或移开，不要杀。

## 检查清单

- [ ] 能用非交互参数预防的，启动时就加上
- [ ] 截图看不出问题时，做一次全量结构枚举（含隐藏、被遮挡的窗口）
- [ ] 先读内容并记录，再决定怎么处理
- [ ] 判断它是障碍还是入口；入口如果不可逆，先问用户
- [ ] 按"WM_COMMAND → BM_CLICK → UIA → 键盘 → 坐标 → WM_CLOSE"的顺序处理，每步都验证
- [ ] 用循环处理，设上限；同一个弹窗反复出现时停下来重新判断
- [ ] 定位用结构特征，不用文本
- [ ] 只清理自己启动的进程
