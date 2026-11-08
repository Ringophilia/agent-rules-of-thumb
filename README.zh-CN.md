<div align="center">

[English](README.md) | **简体中文** | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md)

# Agent Rules of Thumb

**让 AI 智能体少走弯路的经验法则**

一组从真实翻车现场总结出来的 [Agent Skills](https://agentskills.io)，<br>
纠正 AI 智能体在自动化、排障、运维中最常见、也最费时间的坏习惯。

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/format-Agent%20Skills-8A2BE2.svg)](https://agentskills.io)
[![Skills](https://img.shields.io/badge/skills-14-blue.svg)](#-skills-一览)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-ready-D97757.svg)](#-安装)
[![PowerShell 5.1+](https://img.shields.io/badge/scripts-PowerShell%205.1%2B-5391FE.svg)](#-零依赖脚本工具箱)

[Skills 一览](#-skills-一览) · [真实案例](#-它们从哪来) · [安装](#-安装) · [脚本工具箱](#-零依赖脚本工具箱) · [贡献](#-贡献)

</div>

---

## 💡 为什么需要这些

AI 智能体很少因为"不会"而失败，更多是因为**习惯**：

- 顺手用最熟悉的工具，而不是最合适的
- 随手 `sleep 30`，等一个其实早就结束的任务
- 进程名查不到就宣布"程序已退出"，可窗口明明还在屏幕上
- 试了三次失败，就告诉用户"技术上不可行"
- 截一张全屏、把窗口切到前台，打断正在用电脑的用户

这些习惯不会让任务立刻失败，只会让它**慢十倍、结论出错、或者把用户晾在一边**。本仓库里的每条 skill 都对应一次真实发生过的事故：先写清楚错在哪，再给出可执行的流程和检查清单。

## 📚 Skills 一览

| Skill | 纠正的坏习惯 | 什么时候触发 |
| --- | --- | --- |
| 🫥 [**background-friendly**](skills/background-friendly/SKILL.md) | 截全屏、抢焦点、动用户的鼠标键盘；不问就占用用户的桌面 | 截图、启动或调试 GUI 程序、操作程序界面、使用 computer-use 之前 |
| 🧩 [**compare-in-one-image**](skills/compare-in-one-image/SKILL.md) | 一张张打开截图、靠记忆对照：慢、看不出细微差别、token 花 N 倍 | 准备看两张以上的截图、渲染图或视频帧来找差异之前 |
| 🪟 [**dialog-handling**](skills/dialog-handling/SKILL.md) | 看不见弹窗就当它不存在；没读内容就点掉；按进程名乱杀 | 点击没反应、程序看似卡死、命令挂住等输入 |
| 📋 [**look-beyond-the-log**](skills/look-beyond-the-log/SKILL.md) | 一遍遍读自己的日志，真正的报错却在别的进程的弹窗（崩溃报告、缺 DLL 的系统提示、运行库断言、子进程或安装器、杀软）、事件日志或崩溃转储里 | 程序报错、崩溃、提前退出或卡住，而日志是空的、断在半截，或者看不出问题 |
| 🔍 [**never-give-up-early**](skills/never-give-up-early/SKILL.md) | 自己试了几次失败，就宣布"不可行"；主方案出现一次过渡性的异常，就退到兜底方案（软件渲染、兼容模式、降级实现） | 准备说"走不通 / 不值得做"、或改用兜底和降级方案之前 |
| ⏱️ [**no-blind-wait**](skills/no-blind-wait/SKILL.md) | 用固定时长的 sleep 等结果 | 准备写 sleep 等某件事完成时 |
| 📸 [**screenshot-first**](skills/screenshot-first/SKILL.md) | 根据进程名、退出码等间接指标断言状态 | 准备说"已启动 / 已退出 / 已修好"之前 |
| 🚀 [**think-about-faster-path**](skills/think-about-faster-path/SKILL.md) | 习惯性地用最熟悉、而不是最合适的工具 | 慢操作、批量操作、跨机操作之前 |
| 🙋 [**maybe-it-was-the-user**](skills/maybe-it-was-the-user/SKILL.md) | 用户关掉了窗口、改了文件，却被当成程序出错，开始排错或反复重启 | 程序、窗口、文件意外变化，准备排错之前 |
| 🎨 [**style-fits-the-job**](skills/style-fits-the-job/SKILL.md) | 不分场景套用"AI 风"：商务工具满是毛玻璃、紫蓝渐变、霓虹；娱乐应用却做得死板。和一律鼓励"大胆"的设计 skill 不同，这里先看用途再定风格 | 设计或编写任何 UI 样式之前 |
| 🧭 [**think-like-the-user**](skills/think-like-the-user/SKILL.md) | 按钮放错地方、入口藏得深、多余的确认和步骤；加用户没要的功能、菜单和入口；界面上露出技术栈、hook 次数、ID、堆栈等开发者信息 | 设计或修改交互、流程、表单、弹窗时；宣布 UI 完成之前 |
| 🛠️ [**just-do-it-yourself**](skills/just-do-it-yourself/SKILL.md) | 自己能跑的命令、能读的文件、能查的报错，却停下来让用户去做 | 准备让用户运行、检查、复制、确认任何东西之前 |
| 📜 [**no-blind-script**](skills/no-blind-script/SKILL.md) | 有变数的流程也用一个固定脚本跑到底，默认每一步都按预期发生 | 准备写脚本对会变化的系统执行一长串操作之前；一次性脚本失败两次以上时 |
| 🔤 [**encoding-first**](skills/encoding-first/SKILL.md) | 含中文的文件随工具默认编码保存，乱码或报错后才改，下次再犯 | 写任何含中文或其他非 ASCII 字符的文件之前；一看到乱码时 |

各条 skill 的**原则是通用的**；示例偏 Windows / PowerShell，因为它们来自 Windows 桌面与虚拟机自动化的实际经历。

### 速查：智能体正准备……

| 正准备…… | 先读 |
| --- | --- |
| 截图、开 GUI、点界面 | 🫥 background-friendly |
| 对比几张截图、渲染图或视频帧 | 🧩 compare-in-one-image |
| 说"已完成 / 已退出 / 已修好" | 📸 screenshot-first |
| 写 `sleep` 等结果 | ⏱️ no-blind-wait |
| 说"做不到 / 不值得"，或改用兜底方案 | 🔍 never-give-up-early |
| 跑一个慢的、批量的、跨机的操作 | 🚀 think-about-faster-path |
| 面对"点了没反应 / 卡住了" | 🪟 dialog-handling |
| 为了找程序失败的原因，又要去读一遍日志 | 📋 look-beyond-the-log |
| 排查"突然"关闭或变化的东西 | 🙋 maybe-it-was-the-user |
| 给 UI 选配色、字体、效果 | 🎨 style-fits-the-job |
| 摆按钮、设计流程、宣布界面做完了 | 🧭 think-like-the-user |
| 让用户去运行命令或检查什么 | 🛠️ just-do-it-yourself |
| 写脚本从头到尾执行一长串操作 | 📜 no-blind-script |
| 写含中文等非 ASCII 字符的脚本或文件 | 🔤 encoding-first |

## 🔥 它们从哪来

每条 skill 都源自一次具体的事故。点开看看当时发生了什么：

<details>
<summary><b>🚀 think-about-faster-path</b>：同一个文件，换个命令快了 20 倍</summary>

<br>

要在两台机器之间传一个 44.4 MB 的文件，顺手用了 Windows PowerShell 5.1 的 `Invoke-WebRequest`，结果要几十秒，有时直接超时。换成 `curl.exe` 之后只用了 **1.9 秒**。

根因是 5.1 的进度条渲染会把下载拖慢几十倍。而且在 PowerShell 5.1 里，`curl` 其实是 `Invoke-WebRequest` 的别名。

**教训**：更好的工具一直都知道，只是动手前没做比较。

</details>

<details>
<summary><b>⏱️ no-blind-wait</b>：10 秒的活，等了 100 多秒</summary>

<br>

任务脚本里 `Start-Sleep 50`，调度端又 `Start-Sleep 54`。可那个远程调用本身就是同步的：返回时任务早就做完了。时间全浪费了，出错时也只看到一个"超时"，不知道卡在哪一步。

**教训**：先看调用是不是同步的；需要轮询时，"条件 + 间隔 + 总超时 + 超时后做什么"缺一不可；长流程要打阶段标记。

</details>

<details>
<summary><b>📸 screenshot-first</b>：进程"不存在"，窗口却在屏幕中央</summary>

<br>

按名字查进程返回空，`MainWindowTitle` 也是空的，于是判断程序"已退出"。截图一看，窗口就在屏幕中央等人去点。原来运行时把映像名改成了一串数字。

**教训**：进程名、退出码、状态字段都是间接指标。和一手证据冲突时，信一手证据，并追查间接指标为什么说错了。

</details>

<details>
<summary><b>🪟 dialog-handling</b>：被反复关掉的弹窗，正是出路</summary>

<br>

一个反复出现的「您确认要解绑吗？」被当成噪声，关了一次又一次。实际上账号绑在旧机器上，正是它导致登录失败；点「确定」解绑之后，流程立刻就通了。

**教训**：先读弹窗内容，再判断它是障碍还是入口；如果入口是不可逆操作，先问用户。

</details>

<details>
<summary><b>📋 look-beyond-the-log</b>：报错在另一个程序的弹窗里</summary>

<br>

智能体做的程序一启动就报错。它一遍遍读程序的日志、加日志、再读，始终找不到原因。答案一直摆在屏幕上：另一个进程弹出了报错窗口（系统加载器提示缺 DLL）。程序在写第一行日志之前就死了，日志里不可能有。

**教训**：日志只记录程序来得及写下的东西。记下时间点、复现，然后把所有进程的弹窗、事件日志、崩溃转储和 stderr 扫一遍，再回头读日志。

</details>

<details>
<summary><b>🔍 never-give-up-early</b>：判了"死刑"的问题，30 分钟就解决了</summary>

<br>

为了让一个商用软件在虚拟机里启动，自己改了十几项配置，全部失败，于是得出结论："检测层次太深，不值得继续。"用户反问：只凭一篇转载帖和一轮尝试就下结论，调研太少了。随后开了 4 路独立调研，其中一路找到了现成的开源驱动，**前后 30 分钟**解决。

**教训**：你试过的只是全部方案里很小的一块。说"不行"之前，要拿出具体的排除证据和查过的来源。

</details>

<details>
<summary><b>🫥 background-friendly</b>：AI 在调试，用户却没法用电脑</summary>

<br>

为了"看一眼程序现在什么样"，智能体把窗口切到前台截全屏、移动鼠标去点按钮，用户手上的工作一次次被打断，截图里还带上了用户屏幕上的其他内容。

**改进后**：只截目标窗口，被遮挡甚至最小化的窗口也能截，而且不抢焦点；程序以最小化、不激活的方式启动；用 UI Automation 在后台点按钮、填文本。确实必须占用桌面时，**先请求批准，没批准就暂停**。

</details>

<details>
<summary><b>🔍 never-give-up-early</b>：把更新时的重启当成"3D 加速不可行"的证据</summary>

<br>

给虚拟机调大显存、走 3D 加速。重启时 Windows 正好在装更新，中途关机了好几次，这是更新的正常流程。AI 把其中一次关机当成了重启结束，没有确认虚拟机的实际状态，就断定改显存的方法不可行。用户说了"现在正在更新"，它仍然自行退到软件渲染，放弃了本来没有问题的 3D 路线。

**教训**：先判断现象是终态还是过渡状态，用一手证据确认；用户告诉你的状态优先采信；降级会降低目标，必须先征得用户同意。

</details>

<details>
<summary><b>📜 no-blind-script</b>：角色死了，脚本还在打怪</summary>

<br>

为了测试游戏，AI 写了一个自动打怪脚本：移动、攻击、等待、捡东西、去下一处，一个固定的动作序列。中途角色被怪打死，脚本完全不知道，继续对着死亡画面发送移动和攻击指令，之后的所有"测试结果"都没有意义。

**教训**：确定的批量操作用一个脚本跑完；有变数的流程要在关键动作前检查前置条件，遇到意外状态就停下报告，或者改成分步执行。一次性脚本失败两次以上（尤其每次失败的地方不同），就别再修修补补，先加检查点。

</details>

## 📊 实测效果

用 DeepSeek Harness 的无界面模式，同一个任务在装 skill 和不装 skill 的情况下各跑 3 次（有一个场景各跑 6 次），每个场景都埋了一个容易踩的坑：

| 场景 | 装 skill | 不装 skill |
| --- | :---: | :---: |
| 从虚拟机拷 400 MB 文件，自带的拷贝命令只有 ~2 MB/s（think-about-faster-path） | 3/3 | 0/3 |
| 财务内部用的报销审批列表页（style-fits-the-job） | 3/3 | 0/3 |
| README 说 10 秒启动完成，实际要 15~23 秒（no-blind-wait） | 6/6 | 5/6 |
| 8 帧里找出有问题的帧（compare-in-one-image） | 3/3，看 1~3 张图 | 3/3，看 8~11 张图 |

另外 7 个 skill 的场景两组都及格：这个模型本来就会主动反编译、读日志、检查产物。只测了一个模型，样本也小，完整数据、方法和局限见 [evals/results.md](evals/results.md)。

## 📦 安装

### Claude Code

```bash
git clone https://github.com/Ringophilia/agent-rules-of-thumb.git
cd agent-rules-of-thumb

# 对所有项目生效
mkdir -p ~/.claude/skills && cp -r skills/* ~/.claude/skills/
# 或者只对当前项目生效（在你的项目根目录执行）
mkdir -p .claude/skills && cp -r /path/to/agent-rules-of-thumb/skills/* .claude/skills/
```

<details>
<summary>Windows PowerShell</summary>

```powershell
git clone https://github.com/Ringophilia/agent-rules-of-thumb.git
New-Item -ItemType Directory -Force "$HOME\.claude\skills" | Out-Null
Copy-Item -Recurse -Force agent-rules-of-thumb\skills\* "$HOME\.claude\skills\"
```

</details>

可以只挑需要的 skill 复制。装好后开一个新会话即可生效。

### 常驻规则（推荐）

Skill 是否被加载，取决于智能体自己判断 `description` 和当前任务是否匹配。"准备说做不到之前"这类习惯型规则，触发的时机智能体自己很难察觉，所以最可靠的用法是：**skill 放细节，再把每条规则的一句话常驻在上下文里**。

[`rules/core-rules.zh-CN.md`](rules/core-rules.zh-CN.md) 就是这些句子（英文版：[`rules/core-rules.md`](rules/core-rules.md)），整段粘贴进 `~/.claude/CLAUDE.md`、`AGENTS.md` 或智能体的系统提示词即可。

### 其他支持 Agent Skills 标准的智能体

把 skill 目录放到对应工具的 skills 目录，具体位置见该工具的文档。

### 不支持 skills 的工具

把 `SKILL.md` 的正文（去掉开头两个 `---` 之间的部分）粘贴进系统提示词或规则文件即可。这些原则本身不依赖任何特定平台。

## 🧰 零依赖脚本工具箱

四条 skill 附带可直接运行的 Windows 脚本，**只依赖系统自带的 PowerShell 5.1 和 .NET Framework**，不需要安装任何东西。

| 需求 | 脚本 | 打扰用户？ |
| --- | --- | :---: |
| 找被遮挡或隐藏的 Win32 对话框，读出子控件的文字和 ID | [`dialog-handling/scripts/list-windows.ps1`](skills/dialog-handling/scripts/list-windows.ps1) | 否 |
| 点击 Win32 对话框按钮（WM_COMMAND，不需要激活窗口） | [`dialog-handling/scripts/press-button.ps1`](skills/dialog-handling/scripts/press-button.ps1) | 否 |
| 按时间点扫出日志之外的报错：所有进程的弹窗、新进程、事件日志错误、崩溃转储 | [`look-beyond-the-log/scripts/collect-errors.ps1`](skills/look-beyond-the-log/scripts/collect-errors.ps1) | 否 |
| 截单个窗口（被遮挡或最小化都行，不抢焦点）；`-Burst` 按固定间隔连拍多帧 | [`background-friendly/scripts/capture-window.ps1`](skills/background-friendly/scripts/capture-window.ps1) | 否 |
| 把多张截图拼成一张带标签的网格，一眼对比；`-Diff` 用红框标出变化 | [`compare-in-one-image/scripts/compose-shots.ps1`](skills/compare-in-one-image/scripts/compose-shots.ps1) | 否 |
| 以最小化、不激活的方式启动程序，输出写到日志 | [`background-friendly/scripts/start-quiet.ps1`](skills/background-friendly/scripts/start-quiet.ps1) | 否 |
| 用 UI Automation 在后台读控件树、点按钮、填文本、勾选 | [`background-friendly/scripts/uia.ps1`](skills/background-friendly/scripts/uia.ps1) | 否 |
| 真实鼠标键盘输入，结束后还原前台窗口和鼠标位置 | [`background-friendly/scripts/desktop-input.ps1`](skills/background-friendly/scripts/desktop-input.ps1) | ⚠️ 需用户批准 |

```powershell
# 例：在后台截一个最小化的窗口，然后给它的文本框填值、点按钮，全程不抢焦点
.\capture-window.ps1 -Title "My App" -Out shot.png
.\uia.ps1 -Title "My App" -ControlType Edit -SetValue "hello"
.\uia.ps1 -Title "My App" -Name "OK" -Invoke
# 前后对比拼成一张、变化处画红框；给窗口连拍 6 帧
.\compose-shots.ps1 -Inputs "before.png||after.png" -Diff -Out diff.png
.\capture-window.ps1 -Title "My App" -Burst 6 -IntervalMs 300 -Out burst.png
```

> [!NOTE]
> `uia.ps1` 首次运行时会用 Windows 自带的 `csc.exe` 把 `uia.cs` 编译成 `uia.exe`。原因是在 Windows PowerShell 里，托管 UIA 客户端加载不了 Win32 控件的代理，所有控件都只显示成没有 Pattern 的 `Pane`。所有脚本都保持纯 ASCII，以避开 PowerShell 5.1 按 ANSI 码页读取无 BOM UTF-8 脚本时出现的乱码问题。

## 🧱 Skill 的结构

遵循 [Agent Skills](https://agentskills.io) 开放标准：每个 skill 是一个目录，入口是 `SKILL.md`。

```
skills/
  <skill-name>/
    SKILL.md        # YAML frontmatter（name + description）+ Markdown 正文
    scripts/        # 可选：skill 里引用的可执行脚本
rules/
  core-rules.md     # 每条 skill 一句话，放进 CLAUDE.md / AGENTS.md 常驻
evals/
  scenarios.md      # 每条 skill 的可复现测试场景
  results.md        # 装与不装 skill 的实测对比
  harness/          # 场景生成器和评分脚本
```

`description` 是智能体决定"要不要加载这个 skill"的唯一依据，而且所有已安装 skill 的 description 会一直占着上下文，所以统一用几句英文写成：**核心规则 + 什么时候用**。正文用中文。

每条 skill 的正文大致按同一个结构组织：

1. **反面案例**：真实发生的事故，错在哪
2. **触发信号**：发现自己正要做什么、说什么时，就该停下来
3. **正确做法**：可执行的步骤、命令、代码
4. **边界**：什么时候规则不适用，什么时候该停下来问用户
5. **检查清单**：动手前或宣布完成前逐项过一遍

## 🤝 贡献

欢迎提 Issue 和 PR，尤其欢迎这几类：

- **新的翻车案例**：你的智能体反复犯的某个错，附上当时的现场（命令、输出、截图）
- **其他平台的示例**：macOS / Linux 下的等价做法和脚本
- **反例**：某条规则在你的场景里给出了错误的指导
- **测试结果**：用[测试场景](evals/scenarios.md)对比装与不装 skill 的表现（注明智能体和模型版本）
- **翻译**：skill 本身或本 README 的其他语言版本

新增 skill 时请保持这几个约定：从真实案例出发；`description` 用几句英文写清"核心规则 + 什么时候用"；正文给出可执行的步骤而不是口号；脚本零依赖、纯 ASCII；同时在 `rules/core-rules*.md` 里加一句常驻规则，在 `evals/scenarios.md` 里加一个测试场景。

## 📄 许可

[MIT](LICENSE) © 2026 Ringophilia
