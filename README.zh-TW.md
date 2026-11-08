<div align="center">

[English](README.md) | [简体中文](README.zh-CN.md) | **繁體中文** | [日本語](README.ja.md)

# Agent Rules of Thumb

**讓 AI 代理少走冤枉路的經驗法則**

一組從真實翻車現場整理出來的 [Agent Skills](https://agentskills.io)，<br>
修正 AI 代理在自動化、除錯、維運中最常見、也最浪費時間的壞習慣。

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/format-Agent%20Skills-8A2BE2.svg)](https://agentskills.io)
[![Skills](https://img.shields.io/badge/skills-13-blue.svg)](#-skills-一覽)
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
| 🧩 [**compare-in-one-image**](skills/compare-in-one-image/SKILL.md) | 一張張打開截圖、靠記憶比對：慢、看不出細微差別、token 花 N 倍 | 準備看兩張以上的截圖、算繪圖或影片影格來找差異之前 |
| 🪟 [**dialog-handling**](skills/dialog-handling/SKILL.md) | 看不見對話框就當它不存在；沒讀內容就關掉；按程序名稱亂殺 | 點擊沒反應、程式看似當掉、指令卡住等輸入 |
| 🔍 [**never-give-up-early**](skills/never-give-up-early/SKILL.md) | 自己試了幾次失敗，就宣布「不可行」；主方案出現一次過渡性的異常，就退到備援方案（軟體算繪、相容模式、降級實作） | 準備說「行不通 / 不值得做」、或改用備援和降級方案之前 |
| ⏱️ [**no-blind-wait**](skills/no-blind-wait/SKILL.md) | 用固定時長的 sleep 等結果 | 準備寫 sleep 等某件事完成時 |
| 📸 [**screenshot-first**](skills/screenshot-first/SKILL.md) | 根據程序名稱、結束代碼等間接指標斷言狀態 | 準備說「已啟動 / 已結束 / 已修好」之前 |
| 🚀 [**think-about-faster-path**](skills/think-about-faster-path/SKILL.md) | 習慣性地用最熟悉、而不是最合適的工具 | 慢操作、批次操作、跨機器操作之前 |
| 🙋 [**maybe-it-was-the-user**](skills/maybe-it-was-the-user/SKILL.md) | 使用者關掉了視窗、改了檔案，卻被當成程式出錯，開始除錯或反覆重啟 | 程式、視窗、檔案意外變化，準備除錯之前 |
| 🎨 [**style-fits-the-job**](skills/style-fits-the-job/SKILL.md) | 不分場景套用「AI 風」：商務工具滿是毛玻璃、紫藍漸層、霓虹；娛樂應用卻做得死板。和一律鼓勵「大膽」的設計 skill 不同，這裡先看用途再定風格 | 設計或撰寫任何 UI 樣式之前 |
| 🧭 [**think-like-the-user**](skills/think-like-the-user/SKILL.md) | 按鈕放錯地方、入口藏得深、多餘的確認和步驟；加使用者沒要的功能、選單和入口；介面上露出技術棧、hook 次數、ID、堆疊等開發者資訊 | 設計或修改互動、流程、表單、對話框時；宣布 UI 完成之前 |
| 🛠️ [**just-do-it-yourself**](skills/just-do-it-yourself/SKILL.md) | 自己能跑的指令、能讀的檔案、能查的錯誤，卻停下來讓使用者去做 | 準備讓使用者執行、檢查、複製、確認任何東西之前 |
| 📜 [**no-blind-script**](skills/no-blind-script/SKILL.md) | 有變數的流程也用一個固定腳本跑到底，預設每一步都照預期發生 | 準備寫腳本對會變化的系統執行一長串操作之前；一次性腳本失敗兩次以上時 |
| 🔤 [**encoding-first**](skills/encoding-first/SKILL.md) | 含中文的檔案隨工具預設編碼儲存，亂碼或報錯後才改，下次再犯 | 寫任何含中文或其他非 ASCII 字元的檔案之前；一看到亂碼時 |

各條 skill 的**原則是通用的**；範例偏 Windows / PowerShell，因為它們來自 Windows 桌面與虛擬機自動化的實際經歷。

> [!NOTE]
> skill 正文目前以簡體中文撰寫，`description`（代理用來判斷何時載入 skill 的部分）則是英文。現代 LLM 代理不論你用什麼語言對話，都能正常照著執行。歡迎協助翻譯，見[貢獻](#-貢獻)。

### 速查：代理正準備……

| 正準備…… | 先讀 |
| --- | --- |
| 截圖、開 GUI、點介面 | 🫥 background-friendly |
| 比對幾張截圖、算繪圖或影片影格 | 🧩 compare-in-one-image |
| 說「已完成 / 已結束 / 已修好」 | 📸 screenshot-first |
| 寫 `sleep` 等結果 | ⏱️ no-blind-wait |
| 說「做不到 / 不值得」，或改用備援方案 | 🔍 never-give-up-early |
| 跑一個慢的、批次的、跨機器的操作 | 🚀 think-about-faster-path |
| 面對「點了沒反應 / 卡住了」 | 🪟 dialog-handling |
| 排查「突然」關閉或變化的東西 | 🙋 maybe-it-was-the-user |
| 為 UI 選配色、字型、效果 | 🎨 style-fits-the-job |
| 擺按鈕、設計流程、宣布介面做完了 | 🧭 think-like-the-user |
| 讓使用者去執行指令或檢查什麼 | 🛠️ just-do-it-yourself |
| 寫腳本從頭到尾執行一長串操作 | 📜 no-blind-script |
| 寫含中文等非 ASCII 字元的腳本或檔案 | 🔤 encoding-first |

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

<details>
<summary><b>🔍 never-give-up-early</b>：把更新時的重新開機當成「3D 加速不可行」的證據</summary>

<br>

為虛擬機調大顯示記憶體、走 3D 加速。重新開機時 Windows 正好在安裝更新，中途關機了好幾次，這是更新的正常流程。AI 把其中一次關機當成了重新開機結束，沒有確認虛擬機的實際狀態，就斷定調整顯示記憶體的方法不可行。使用者說了「現在正在更新」，它仍然自行退到軟體算繪，放棄了本來沒有問題的 3D 路線。

**教訓**：先判斷現象是終態還是過渡狀態，用第一手證據確認；使用者告訴你的狀態優先採信；降級會降低目標，必須先徵得使用者同意。

</details>

<details>
<summary><b>📜 no-blind-script</b>：角色死了，腳本還在打怪</summary>

<br>

為了測試遊戲，AI 寫了一個自動打怪腳本：移動、攻擊、等待、撿東西、去下一處，一個固定的動作序列。中途角色被怪打死，腳本完全不知道，繼續對著死亡畫面送出移動和攻擊指令，之後的所有「測試結果」都沒有意義。

**教訓**：確定的批次操作用一個腳本跑完；有變數的流程要在關鍵動作前檢查前置條件，遇到意外狀態就停下回報，或者改成分步執行。一次性腳本失敗兩次以上（尤其每次失敗的地方不同），就別再修修補補，先加檢查點。

</details>

## 📊 實測效果

用 DeepSeek Harness 的無介面模式，同一個任務在裝 skill 和不裝 skill 的情況下各跑 3 次（有一個情境各跑 6 次），每個情境都埋了一個容易踩的坑：

| 情境 | 裝 skill | 不裝 skill |
| --- | :---: | :---: |
| 從虛擬機複製 400 MB 檔案，內建的複製指令只有 ~2 MB/s（think-about-faster-path） | 3/3 | 0/3 |
| 財務內部用的報銷審批列表頁（style-fits-the-job） | 3/3 | 0/3 |
| README 說 10 秒啟動完成，實際要 15~23 秒（no-blind-wait） | 6/6 | 5/6 |
| 8 幀裡找出有問題的幀（compare-in-one-image） | 3/3，看 1~3 張圖 | 3/3，看 8~11 張圖 |

另外 7 個 skill 的情境兩組都及格：這個模型本來就會主動反編譯、讀日誌、檢查產物。只測了一個模型，樣本也小，完整資料、方法和局限見 [evals/results.md](evals/results.md)（簡體中文）。

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

### 常駐規則（推薦）

skill 是否被載入，取決於代理自己判斷 `description` 和目前任務是否相符。「準備說做不到之前」這類習慣型規則，觸發的時機代理自己很難察覺，所以最可靠的用法是：**skill 放細節，再把每條規則的一句話常駐在上下文裡**。

[`rules/core-rules.zh-CN.md`](rules/core-rules.zh-CN.md)（簡體中文）和 [`rules/core-rules.md`](rules/core-rules.md)（英文）就是這些句子，整段貼進 `~/.claude/CLAUDE.md`、`AGENTS.md` 或代理的系統提示詞即可。

### 其他支援 Agent Skills 標準的代理

把 skill 目錄放到對應工具的 skills 目錄，具體位置見該工具的文件。

### 不支援 skills 的工具

把 `SKILL.md` 的正文（去掉開頭兩個 `---` 之間的部分）貼進系統提示詞或規則檔即可。這些原則本身不依賴任何特定平台。

## 🧰 零依賴腳本工具箱

三條 skill 附帶可直接執行的 Windows 腳本，**只依賴系統內建的 PowerShell 5.1 和 .NET Framework**，不需要安裝任何東西。

| 需求 | 腳本 | 打擾使用者？ |
| --- | --- | :---: |
| 找被遮住或隱藏的 Win32 對話框，讀出子控制項的文字和 ID | [`dialog-handling/scripts/list-windows.ps1`](skills/dialog-handling/scripts/list-windows.ps1) | 否 |
| 點擊 Win32 對話框按鈕（WM_COMMAND，不需要啟用視窗） | [`dialog-handling/scripts/press-button.ps1`](skills/dialog-handling/scripts/press-button.ps1) | 否 |
| 截單一視窗（被遮住或最小化都行，不搶焦點）；`-Burst` 按固定間隔連拍多幀 | [`background-friendly/scripts/capture-window.ps1`](skills/background-friendly/scripts/capture-window.ps1) | 否 |
| 把多張截圖拼成一張帶標籤的網格，一眼比對；`-Diff` 用紅框標出變化 | [`compare-in-one-image/scripts/compose-shots.ps1`](skills/compare-in-one-image/scripts/compose-shots.ps1) | 否 |
| 以最小化、不啟用的方式啟動程式，輸出寫到日誌 | [`background-friendly/scripts/start-quiet.ps1`](skills/background-friendly/scripts/start-quiet.ps1) | 否 |
| 用 UI Automation 在背景讀控制項樹、點按鈕、填文字、勾選 | [`background-friendly/scripts/uia.ps1`](skills/background-friendly/scripts/uia.ps1) | 否 |
| 真實滑鼠鍵盤輸入，結束後還原前景視窗和滑鼠位置 | [`background-friendly/scripts/desktop-input.ps1`](skills/background-friendly/scripts/desktop-input.ps1) | ⚠️ 需使用者同意 |

```powershell
# 例：在背景截一個最小化的視窗，然後填它的文字方塊、點按鈕，全程不搶焦點
.\capture-window.ps1 -Title "My App" -Out shot.png
.\uia.ps1 -Title "My App" -ControlType Edit -SetValue "hello"
.\uia.ps1 -Title "My App" -Name "OK" -Invoke
# 前後比對拼成一張、變化處畫紅框；給視窗連拍 6 幀
.\compose-shots.ps1 -Inputs "before.png||after.png" -Diff -Out diff.png
.\capture-window.ps1 -Title "My App" -Burst 6 -IntervalMs 300 -Out burst.png
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
rules/
  core-rules.md     # 每條 skill 一句話，放進 CLAUDE.md / AGENTS.md 常駐
evals/
  scenarios.md      # 每條 skill 的可重現測試情境
  results.md        # 裝與不裝 skill 的實測對比
  harness/          # 情境產生器和評分腳本
```

`description` 是代理決定「要不要載入這個 skill」的唯一依據，而且所有已安裝 skill 的 description 會一直佔著上下文，所以統一用幾句英文寫成：**核心規則 + 什麼時候用**。

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
- **測試結果**：用[測試情境](evals/scenarios.md)比較裝與不裝 skill 的表現（註明代理和模型版本）
- **翻譯**：skill 本身或本 README 的其他語言版本

新增 skill 時請維持這幾個慣例：從真實案例出發；`description` 用幾句英文寫清「核心規則 + 什麼時候用」；正文給出可執行的步驟而不是口號；腳本零依賴、純 ASCII；同時在 `rules/core-rules*.md` 裡加一句常駐規則，在 `evals/scenarios.md` 裡加一個測試情境。

## 📄 授權

[MIT](LICENSE) © 2026 Ringophilia
