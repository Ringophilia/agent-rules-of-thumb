<div align="center">

[English](README.md) | [简体中文](README.zh-CN.md) | **繁體中文** | [日本語](README.ja.md)

# Agent Rules of Thumb

**讓 AI 代理少走冤枉路的經驗法則**

一組從真實翻車現場整理出來的 [Agent Skills](https://agentskills.io)，<br>
修正 AI 代理在自動化、除錯、維運中最常見、也最浪費時間的壞習慣。

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/format-Agent%20Skills-8A2BE2.svg)](https://agentskills.io)
[![Skills](https://img.shields.io/badge/skills-6-blue.svg)](#-skills-一覽)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-ready-D97757.svg)](#-安裝)
[![PowerShell 5.1+](https://img.shields.io/badge/scripts-PowerShell%205.1%2B-5391FE.svg)](#-零依賴腳本工具箱)

[Skills 一覽](#-skills-一覽) · [真實案例](#-它們從哪來) · [安裝](#-安裝) · [腳本工具箱](#-零依賴腳本工具箱) · [貢獻](#-貢獻)

</div>

---

## 💡 為什麼需要這些

AI 代理很少因為「不會」而失敗，更多是因為**習慣**：

- 順手用最熟悉的工具，而不是最合適的
- 隨手 `sleep 30`，等一個其實早就結束的任務
- 用程序名稱查不到，就宣布「程式已結束」，視窗明明還在螢幕上
- 試了三次失敗，就告訴使用者「技術上不可行」
- 截一張全螢幕、把視窗切到最前面，打斷正在用電腦的使用者

這些習慣不會讓任務立刻失敗，只會讓它**慢十倍、結論出錯，或者把使用者晾在一邊**。本儲存庫的每條 skill 都對應一次真實發生過的事故：先寫清楚錯在哪，再給出可執行的流程和檢查清單。

## 📚 Skills 一覽

| Skill | 修正的壞習慣 | 什麼時候觸發 |
| --- | --- | --- |
| 🫥 [**background-friendly**](skills/background-friendly/SKILL.md) | 截全螢幕、搶焦點、動使用者的滑鼠鍵盤；不問就佔用使用者的桌面 | 截圖、啟動或除錯 GUI 程式、操作程式介面、使用 computer-use 之前 |
| 🪟 [**dialog-handling**](skills/dialog-handling/SKILL.md) | 看不見對話框就當它不存在；沒讀內容就關掉；按程序名稱亂殺 | 點擊沒反應、程式看似當掉、指令卡住等輸入 |
| 🔍 [**never-give-up-early**](skills/never-give-up-early/SKILL.md) | 自己試了幾次失敗，就宣布「不可行」 | 準備說「行不通 / 不值得做」之前 |
| ⏱️ [**no-blind-wait**](skills/no-blind-wait/SKILL.md) | 用固定時長的 sleep 等結果 | 準備寫 sleep 等某件事完成時 |
| 📸 [**screenshot-first**](skills/screenshot-first/SKILL.md) | 根據程序名稱、結束代碼等間接指標斷言狀態 | 準備說「已啟動 / 已結束 / 已修好」之前 |
| 🚀 [**think-about-faster-path**](skills/think-about-faster-path/SKILL.md) | 習慣性地用最熟悉、而不是最合適的工具 | 慢操作、批次操作、跨機器操作之前 |

各條 skill 的**原則是通用的**；範例偏 Windows / PowerShell，因為它們來自 Windows 桌面與虛擬機自動化的實際經歷。

> [!NOTE]
> skill 檔案目前以簡體中文撰寫。現代 LLM 代理不論你用什麼語言對話，都能正常照著執行。歡迎協助翻譯，見[貢獻](#-貢獻)。

### 速查：代理正準備……

| 正準備…… | 先讀 |
| --- | --- |
| 截圖、開 GUI、點介面 | 🫥 background-friendly |
| 說「已完成 / 已結束 / 已修好」 | 📸 screenshot-first |
| 寫 `sleep` 等結果 | ⏱️ no-blind-wait |
| 說「做不到 / 不值得」 | 🔍 never-give-up-early |
| 跑一個慢的、批次的、跨機器的操作 | 🚀 think-about-faster-path |
| 面對「點了沒反應 / 卡住了」 | 🪟 dialog-handling |

## 🔥 它們從哪來

每條 skill 都源自一次具體的事故。點開看看當時發生了什麼：

<details>
<summary><b>🚀 think-about-faster-path</b>：同一個檔案，換個指令快了 20 倍</summary>

<br>

要在兩台機器之間傳一個 44.4 MB 的檔案，順手用了 Windows PowerShell 5.1 的 `Invoke-WebRequest`，結果要幾十秒，有時直接逾時。換成 `curl.exe` 之後只要 **1.9 秒**。

根本原因是 5.1 的進度列繪製會把下載拖慢幾十倍。而且在 PowerShell 5.1 裡，`curl` 其實是 `Invoke-WebRequest` 的別名。

**教訓**：更好的工具一直都知道，只是動手前沒有做比較。

</details>

<details>
<summary><b>⏱️ no-blind-wait</b>：10 秒的工作，等了 100 多秒</summary>

<br>

任務腳本裡 `Start-Sleep 50`，排程端又 `Start-Sleep 54`。可是那個遠端呼叫本身就是同步的：回傳時任務早就做完了。時間全浪費了，出錯時也只看到一個「逾時」，不知道卡在哪一步。

**教訓**：先看呼叫是不是同步的；需要輪詢時，「條件 + 間隔 + 總逾時 + 逾時後做什麼」缺一不可；長流程要打階段標記。

</details>

<details>
<summary><b>📸 screenshot-first</b>：程序「不存在」，視窗卻在螢幕正中央</summary>

<br>

用名稱查程序回傳空值，`MainWindowTitle` 也是空的，於是判斷程式「已結束」。截圖一看，視窗就在螢幕正中央等人去點。原來執行階段把映像名稱改成了一串數字。

**教訓**：程序名稱、結束代碼、狀態欄位都是間接指標。和第一手證據衝突時，相信第一手證據，並追查間接指標為什麼說錯了。

</details>

<details>
<summary><b>🪟 dialog-handling</b>：被反覆關掉的對話框，正是出路</summary>

<br>

一個反覆出現的「您確定要解除綁定嗎？」被當成雜訊，關了一次又一次。實際上帳號綁在舊機器上，正是它導致登入失敗；按下「確定」解除綁定之後，流程立刻就通了。

**教訓**：先讀對話框內容，再判斷它是障礙還是入口；如果入口是不可逆操作，先問使用者。

</details>

<details>
<summary><b>🔍 never-give-up-early</b>：被判「死刑」的問題，30 分鐘就解決了</summary>

<br>

為了讓一個商用軟體在虛擬機裡啟動，自己改了十幾項設定，全部失敗，於是得出結論：「偵測層次太深，不值得繼續。」使用者反問：只憑一篇轉載文章和一輪嘗試就下結論，調查太少了。隨後開了 4 路獨立調查，其中一路找到了現成的開源驅動程式，**前後 30 分鐘**解決。

**教訓**：你試過的只是所有方案裡很小的一塊。說「不行」之前，要拿出具體的排除證據和查過的來源。

</details>

<details>
<summary><b>🫥 background-friendly</b>：AI 在除錯，使用者卻沒辦法用電腦</summary>

<br>

為了「看一眼程式現在長什麼樣」，代理把視窗切到最前面截全螢幕、移動滑鼠去點按鈕，使用者手上的工作一次次被打斷，截圖裡還帶到使用者螢幕上的其他內容。

**改進後**：只截目標視窗，被遮住甚至最小化的視窗也能截，而且不搶焦點；程式以最小化、不啟用的方式啟動；用 UI Automation 在背景點按鈕、填文字。確實必須佔用桌面時，**先請求同意，沒同意就暫停**。

</details>

## 📦 安裝

### Claude Code

```bash
git clone https://github.com/Ringophilia/agent-rules-of-thumb.git
cd agent-rules-of-thumb

# 對所有專案生效
mkdir -p ~/.claude/skills && cp -r skills/* ~/.claude/skills/
# 或者只對目前專案生效（在你的專案根目錄執行）
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

可以只挑需要的 skill 複製。裝好後開一個新工作階段即可生效。

> [!TIP]
> skill 是否被載入，取決於代理自己判斷 `description` 和目前任務是否相符。如果希望某條規則**一律生效**，可以在全域 `~/.claude/CLAUDE.md` 裡加一行，例如：
>
> ```markdown
> - 截圖、啟動或除錯 GUI 程式、使用 computer-use 之前，先讀 background-friendly skill 並照做。
> ```

### 其他支援 Agent Skills 標準的代理

把 skill 目錄放到對應工具的 skills 目錄，具體位置見該工具的文件。

### 不支援 skills 的工具

把 `SKILL.md` 的正文（去掉開頭兩個 `---` 之間的部分）貼進系統提示詞或規則檔即可。這些原則本身不依賴任何特定平台。

## 🧰 零依賴腳本工具箱

兩條 skill 附帶可直接執行的 Windows 腳本，**只依賴系統內建的 PowerShell 5.1 和 .NET Framework**，不需要安裝任何東西。

| 需求 | 腳本 | 打擾使用者？ |
| --- | --- | :---: |
| 找被遮住或隱藏的 Win32 對話框，讀出子控制項的文字和 ID | [`dialog-handling/scripts/list-windows.ps1`](skills/dialog-handling/scripts/list-windows.ps1) | 否 |
| 點擊 Win32 對話框按鈕（WM_COMMAND，不需要啟用視窗） | [`dialog-handling/scripts/press-button.ps1`](skills/dialog-handling/scripts/press-button.ps1) | 否 |
| 截單一視窗（被遮住或最小化都行，不搶焦點） | [`background-friendly/scripts/capture-window.ps1`](skills/background-friendly/scripts/capture-window.ps1) | 否 |
| 把多張截圖拼成一張帶標籤的網格，一眼比對；`-Diff` 用紅框標出變化。`capture-window.ps1 -Burst` 連拍並拼成一張 | [`background-friendly/scripts/compose-shots.ps1`](skills/background-friendly/scripts/compose-shots.ps1) | 否 |
| 以最小化、不啟用的方式啟動程式，輸出寫到日誌 | [`background-friendly/scripts/start-quiet.ps1`](skills/background-friendly/scripts/start-quiet.ps1) | 否 |
| 用 UI Automation 在背景讀控制項樹、點按鈕、填文字、勾選 | [`background-friendly/scripts/uia.ps1`](skills/background-friendly/scripts/uia.ps1) | 否 |
| 真實滑鼠鍵盤輸入，結束後還原前景視窗和滑鼠位置 | [`background-friendly/scripts/desktop-input.ps1`](skills/background-friendly/scripts/desktop-input.ps1) | ⚠️ 需使用者同意 |

```powershell
# 例：在背景截一個最小化的視窗，然後填它的文字方塊、點按鈕，全程不搶焦點
.\capture-window.ps1 -Title "My App" -Out shot.png
.\uia.ps1 -Title "My App" -ControlType Edit -SetValue "hello"
.\uia.ps1 -Title "My App" -Name "OK" -Invoke
# 前後比對拼成一張、變化處畫紅框；連拍 6 幀拼成一張時間序列
.\compose-shots.ps1 -Inputs "before.png||after.png" -Diff -Out diff.png
.\capture-window.ps1 -Title "My App" -Burst 6 -IntervalMs 300 -Out sheet.png
```

> [!NOTE]
> `uia.ps1` 第一次執行時會用 Windows 內建的 `csc.exe` 把 `uia.cs` 編譯成 `uia.exe`。原因是在 Windows PowerShell 裡，受控 UIA 用戶端載入不了 Win32 控制項的代理，所有控制項都只會顯示成沒有 Pattern 的 `Pane`。所有腳本都維持純 ASCII，以避開 PowerShell 5.1 用 ANSI 字碼頁讀取無 BOM UTF-8 腳本時出現的亂碼問題。

## 🧱 Skill 的結構

遵循 [Agent Skills](https://agentskills.io) 開放標準：每個 skill 是一個目錄，入口是 `SKILL.md`。

```
skills/
  <skill-name>/
    SKILL.md        # YAML frontmatter（name + description）+ Markdown 正文
    scripts/        # 選用：skill 裡引用的可執行腳本
```

`description` 是代理決定「要不要載入這個 skill」的唯一依據，所以裡面同時寫了**做什麼**和**什麼時候用**。

每條 skill 的正文大致按同一個結構組織：

1. **反面案例**：真實發生的事故，錯在哪
2. **觸發訊號**：發現自己正要做什麼、說什麼時，就該停下來
3. **正確做法**：可執行的步驟、指令、程式碼
4. **邊界**：什麼時候規則不適用，什麼時候該停下來問使用者
5. **檢查清單**：動手前或宣布完成前逐項過一遍

## 🤝 貢獻

歡迎提 Issue 和 PR，尤其歡迎這幾類：

- **新的翻車案例**：你的代理反覆犯的某個錯，附上當時的現場（指令、輸出、截圖）
- **其他平台的範例**：macOS / Linux 下的等價做法和腳本
- **反例**：某條規則在你的情境裡給出了錯誤的指引
- **翻譯**：skill 本身或本 README 的其他語言版本

新增 skill 時請維持這幾個慣例：從真實案例出發；`description` 寫清「做什麼 + 什麼時候用」；正文給出可執行的步驟而不是口號；腳本零依賴、純 ASCII。

## 📄 授權

[MIT](LICENSE) © 2026 Ringophilia
