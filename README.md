<div align="center">

**English** | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md)

# Agent Rules of Thumb

**Battle-tested rules of thumb that keep AI agents off the slow, wrong, and annoying path**

A set of [Agent Skills](https://agentskills.io), each one distilled from a real failure,<br>
that correct the most common and most expensive habits of AI agents doing automation, debugging, and ops work.

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/format-Agent%20Skills-8A2BE2.svg)](https://agentskills.io)
[![Skills](https://img.shields.io/badge/skills-11-blue.svg)](#-the-skills)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-ready-D97757.svg)](#-installation)
[![PowerShell 5.1+](https://img.shields.io/badge/scripts-PowerShell%205.1%2B-5391FE.svg)](#-zero-dependency-script-toolbox)

[The skills](#-the-skills) · [Where they come from](#-where-they-come-from) · [Installation](#-installation) · [Script toolbox](#-zero-dependency-script-toolbox) · [Contributing](#-contributing)

</div>

---

## 💡 Why

AI agents rarely fail because they *can't* do something. They fail because of **habits**:

- Reaching for the most familiar tool instead of the right one
- Writing `sleep 30` to wait for a task that finished long ago
- Declaring "the program exited" because a process lookup came back empty, while the window is sitting right there on screen
- Telling the user "this isn't technically possible" after three failed attempts
- Taking a full-screen screenshot or pulling a window to the front while the user is trying to work

None of these make a task fail outright. They make it **ten times slower, reach the wrong conclusion, or leave the user stranded**. Every skill here comes from an incident that actually happened: it spells out what went wrong, then gives a concrete procedure and a checklist.

## 📚 The skills

| Skill | The bad habit it fixes | When it kicks in |
| --- | --- | --- |
| 🫥 [**background-friendly**](skills/background-friendly/SKILL.md) | Full-screen screenshots, stealing focus, taking over the user's mouse and keyboard without asking | Before screenshots, launching or debugging GUI apps, driving an app's UI, or using computer-use |
| 🪟 [**dialog-handling**](skills/dialog-handling/SKILL.md) | Assuming an unseen dialog doesn't exist; dismissing it without reading it; killing processes by name | A click does nothing, an app looks frozen, a command hangs waiting for input |
| 🔍 [**never-give-up-early**](skills/never-give-up-early/SKILL.md) | Declaring something "impossible" after a few personal attempts | Before saying "this won't work" or "not worth it" |
| ⏱️ [**no-blind-wait**](skills/no-blind-wait/SKILL.md) | Waiting for results with fixed-length sleeps | When about to write a sleep to wait for something |
| 📸 [**screenshot-first**](skills/screenshot-first/SKILL.md) | Asserting state from indirect signals like process names and exit codes | Before saying "it started / it exited / it's fixed" |
| 🚀 [**think-about-faster-path**](skills/think-about-faster-path/SKILL.md) | Using the most familiar tool instead of the most suitable one | Before slow, bulk, repetitive, or cross-machine operations |
| 🙋 [**maybe-it-was-the-user**](skills/maybe-it-was-the-user/SKILL.md) | Treating a window the user closed, or a file the user edited, as a bug, then debugging it or restarting it over and over | A program, window, or file changes unexpectedly, before you start debugging it |
| 🎨 [**style-fits-the-job**](skills/style-fits-the-job/SKILL.md) | The same "AI look" everywhere: glassmorphism, purple gradients and neon on a business tool; a fun app made dull and grey | Before designing or styling any UI |
| 🧭 [**think-like-the-user**](skills/think-like-the-user/SKILL.md) | Buttons in odd places, buried entry points, needless confirmations and extra steps; features, menus, and entry points nobody asked for | Designing or changing interactions, flows, forms, and dialogs; before calling UI work done |
| 🛠️ [**just-do-it-yourself**](skills/just-do-it-yourself/SKILL.md) | Stopping to ask the user to run a command, open a file, or paste an error it could handle itself | Before asking the user to run, check, copy, or confirm anything |
| ↩️ [**dont-fall-back-too-soon**](skills/dont-fall-back-too-soon/SKILL.md) | Retreating to a fallback (software rendering, compatibility mode, a downgrade) after one odd symptom that was only a transitional state | Before abandoning the main approach for a fallback or downgrade |

The **principles are platform-agnostic**. The examples lean toward Windows / PowerShell because that's where the incidents happened: Windows desktop and virtual-machine automation.

> [!NOTE]
> The skill files are currently written in Chinese. Modern LLM agents follow them fine whatever language you talk to them in. Translations are welcome; see [Contributing](#-contributing).

### Quick reference: the agent is about to…

| About to… | Read first |
| --- | --- |
| Take a screenshot, open a GUI, click through an interface | 🫥 background-friendly |
| Say "done / it exited / it's fixed" | 📸 screenshot-first |
| Write a `sleep` to wait for a result | ⏱️ no-blind-wait |
| Say "can't be done / not worth it" | 🔍 never-give-up-early |
| Run something slow, bulk, or cross-machine | 🚀 think-about-faster-path |
| Face "the click did nothing / it's stuck" | 🪟 dialog-handling |
| Debug something that "suddenly" closed or changed | 🙋 maybe-it-was-the-user |
| Pick colours, fonts, and effects for a UI | 🎨 style-fits-the-job |
| Place buttons, design a flow, or say the UI is done | 🧭 think-like-the-user |
| Ask the user to run a command or check something | 🛠️ just-do-it-yourself |
| Switch to a fallback or downgraded approach | ↩️ dont-fall-back-too-soon |

## 🔥 Where they come from

Each skill traces back to one specific incident. Expand to see what happened:

<details>
<summary><b>🚀 think-about-faster-path</b>: same file, 20× faster with a different command</summary>

<br>

A 44.4 MB file needed to move between two machines. The agent reached for Windows PowerShell 5.1's `Invoke-WebRequest`: tens of seconds, sometimes a timeout. Switching to `curl.exe` took **1.9 seconds**.

The root cause: 5.1's progress-bar rendering slows downloads by an order of magnitude. And in PowerShell 5.1, `curl` is an alias for `Invoke-WebRequest`.

**Lesson**: the better tool was known all along. The comparison just never happened before acting.

</details>

<details>
<summary><b>⏱️ no-blind-wait</b>: a 10-second job that waited 100+ seconds</summary>

<br>

The task script ran `Start-Sleep 50`, then the orchestrator ran `Start-Sleep 54` on top. But the remote call was synchronous: by the time it returned, the job was already done. All that time was wasted, and when something did fail, all you got was "timeout", with no idea which step was stuck.

**Lesson**: check whether the call is synchronous first. When you must poll, you need all four: condition, interval, overall timeout, and what to do on timeout. Mark phases in long pipelines.

</details>

<details>
<summary><b>📸 screenshot-first</b>: the process "didn't exist", but the window was in the middle of the screen</summary>

<br>

A lookup by process name came back empty and `MainWindowTitle` was blank, so the program was declared "exited". A screenshot showed the window right in the middle of the screen, waiting for a click. The runtime had renamed its image to a string of digits.

**Lesson**: process names, exit codes, and status fields are indirect signals. When they disagree with first-hand evidence, trust the evidence, then find out why the indirect signal lied.

</details>

<details>
<summary><b>🪟 dialog-handling</b>: the dialog that kept getting closed was the way out</summary>

<br>

An "Are you sure you want to unbind?" dialog kept popping up and kept being dismissed as noise. In fact, the account being bound to an old machine was exactly why login failed. Clicking "OK" to unbind made the whole flow work.

**Lesson**: read the dialog before handling it, and decide whether it's an obstacle or the entrance. If the entrance is irreversible, ask the user first.

</details>

<details>
<summary><b>🔍 never-give-up-early</b>: a "dead end" solved in 30 minutes</summary>

<br>

Trying to get a commercial program to start inside a VM, the agent tweaked over a dozen settings, all failed, and it concluded: "the detection runs too deep; not worth continuing." The user pushed back: one reposted article and one round of attempts isn't research. Four independent research threads followed. One of them found an existing open-source driver, and the problem was solved **within 30 minutes**.

**Lesson**: what you've tried is a tiny slice of the solution space. Before saying "no", produce concrete evidence of what was ruled out and which sources were checked.

</details>

<details>
<summary><b>🫥 background-friendly</b>: the AI was debugging and the user couldn't use their computer</summary>

<br>

To "take a quick look at the app", the agent kept pulling windows to the front, taking full-screen screenshots, and moving the mouse to click buttons. The user's work was interrupted again and again, and the screenshots captured whatever else was on their screen.

**After**: capture only the target window, even a covered or minimized one, without stealing focus. Launch apps minimized and not activated. Click buttons and fill text boxes in the background through UI Automation. When the desktop truly has to be used, **ask for approval first, and pause if it isn't given**.

</details>

<details>
<summary><b>↩️ dont-fall-back-too-soon</b>: an update reboot taken as proof that 3D acceleration "doesn't work"</summary>

<br>

After raising a VM's video memory for 3D acceleration, the guest rebooted while Windows Update was installing, and powered off several times along the way, which is normal for updates. The agent took one of those shutdowns as the end of the reboot, never checked the VM's actual state, and decided the video-memory change didn't work. Even after the user said "it's updating right now", it switched to software rendering on its own, dropping the 3D path that was never broken.

**Lesson**: first decide whether a symptom is a final state or a transitional one, and confirm with first-hand evidence. When the user tells you the state, believe them. A fallback lowers the goal, so ask before taking it.

</details>

## 📦 Installation

### Claude Code

```bash
git clone https://github.com/Ringophilia/agent-rules-of-thumb.git
cd agent-rules-of-thumb

# Available in every project
mkdir -p ~/.claude/skills && cp -r skills/* ~/.claude/skills/
# Or only in one project (run from that project's root)
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

Feel free to copy only the skills you want. They take effect in the next new session.

> [!TIP]
> Whether a skill gets loaded depends on the agent matching its `description` to the task at hand. To make a rule **always on**, add a line to your global `~/.claude/CLAUDE.md`, for example:
>
> ```markdown
> - Before taking screenshots, launching or debugging GUI apps, or using computer-use, read the background-friendly skill and follow it.
> ```

### Other agents that support Agent Skills

Put the skill directories in that tool's skills directory; see its documentation for the location.

### Tools without skills support

Paste the body of `SKILL.md` (everything after the frontmatter between the two `---` lines) into the system prompt or rules file. The principles don't depend on any particular platform.

## 🧰 Zero-dependency script toolbox

Two of the skills ship ready-to-run Windows scripts that **only need the PowerShell 5.1 and .NET Framework that come with Windows**. Nothing to install.

| Need | Script | Disturbs the user? |
| --- | --- | :---: |
| Find covered or hidden Win32 dialogs; read their controls' text and IDs | [`dialog-handling/scripts/list-windows.ps1`](skills/dialog-handling/scripts/list-windows.ps1) | No |
| Press a Win32 dialog button (WM_COMMAND, no activation needed) | [`dialog-handling/scripts/press-button.ps1`](skills/dialog-handling/scripts/press-button.ps1) | No |
| Capture a single window, even covered or minimized, without stealing focus | [`background-friendly/scripts/capture-window.ps1`](skills/background-friendly/scripts/capture-window.ps1) | No |
| Stitch several shots into one labelled grid for a single-look comparison; `-Diff` boxes what changed. `capture-window.ps1 -Burst` takes a timed series into one sheet | [`background-friendly/scripts/compose-shots.ps1`](skills/background-friendly/scripts/compose-shots.ps1) | No |
| Launch a program minimized and not activated, logging its output | [`background-friendly/scripts/start-quiet.ps1`](skills/background-friendly/scripts/start-quiet.ps1) | No |
| Read the control tree, click buttons, set text, toggle checkboxes via UI Automation | [`background-friendly/scripts/uia.ps1`](skills/background-friendly/scripts/uia.ps1) | No |
| Real mouse/keyboard input, then restore the foreground window and cursor | [`background-friendly/scripts/desktop-input.ps1`](skills/background-friendly/scripts/desktop-input.ps1) | ⚠️ Needs approval |

```powershell
# Example: capture a minimized window, then fill its text box and press a button,
# all in the background, without stealing focus
.\capture-window.ps1 -Title "My App" -Out shot.png
.\uia.ps1 -Title "My App" -ControlType Edit -SetValue "hello"
.\uia.ps1 -Title "My App" -Name "OK" -Invoke
# Before/after in ONE image with changes boxed in red, and a 6-frame time series as one sheet
.\compose-shots.ps1 -Inputs "before.png||after.png" -Diff -Out diff.png
.\capture-window.ps1 -Title "My App" -Burst 6 -IntervalMs 300 -Out sheet.png
```

> [!NOTE]
> On first run, `uia.ps1` compiles `uia.cs` into `uia.exe` with the `csc.exe` that ships with Windows. Inside Windows PowerShell, the managed UIA client can't load the Win32 control proxies, so every control shows up as a bare `Pane` with no patterns. All scripts are pure ASCII to avoid PowerShell 5.1 misreading BOM-less UTF-8 scripts with the ANSI code page.

## 🧱 Skill anatomy

Follows the [Agent Skills](https://agentskills.io) open standard: each skill is a directory whose entry point is `SKILL.md`.

```
skills/
  <skill-name>/
    SKILL.md        # YAML frontmatter (name + description) + Markdown body
    scripts/        # optional: executable scripts referenced by the skill
```

The `description` is the only thing the agent sees when deciding whether to load a skill, so each one states both **what it does** and **when to use it**.

Each skill body follows roughly the same structure:

1. **The failure**: a real incident and what went wrong
2. **Trigger signals**: what you catch yourself about to do or say that should make you stop
3. **The right way**: concrete steps, commands, and code
4. **Boundaries**: when the rule doesn't apply, and when to stop and ask the user
5. **Checklist**: run through it before acting or before declaring done

## 🤝 Contributing

Issues and PRs are welcome, especially:

- **New failure cases**: a mistake your agent keeps making, with the evidence (commands, output, screenshots)
- **Other platforms**: macOS / Linux equivalents and scripts
- **Counterexamples**: a rule that gave the wrong guidance in your situation
- **Translations**: of the skills themselves or of this README

When adding a skill, please keep these conventions: start from a real incident; make the `description` say "what it does + when to use it"; give actionable steps, not slogans; keep scripts dependency-free and pure ASCII.

## 📄 License

[MIT](LICENSE) © 2026 Ringophilia
