<div align="center">

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | **日本語**

# Agent Rules of Thumb

**AI エージェントに遠回りをさせないための経験則**

実際の失敗から一つずつまとめた [Agent Skills](https://agentskills.io) 集です。<br>
自動化・デバッグ・運用の場面で AI エージェントがやりがちな、最も時間を無駄にする癖を正します。

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/format-Agent%20Skills-8A2BE2.svg)](https://agentskills.io)
[![Skills](https://img.shields.io/badge/skills-10-blue.svg)](#-skills-一覧)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-ready-D97757.svg)](#-インストール)
[![PowerShell 5.1+](https://img.shields.io/badge/scripts-PowerShell%205.1%2B-5391FE.svg)](#-依存ゼロのスクリプト集)

[Skills 一覧](#-skills-一覧) · [それぞれの由来](#-それぞれの由来) · [インストール](#-インストール) · [スクリプト集](#-依存ゼロのスクリプト集) · [コントリビュート](#-コントリビュート)

</div>

---

## 💡 なぜ必要か

AI エージェントが失敗する理由は「できないから」より、むしろ**癖**であることがほとんどです。

- 最適なツールではなく、使い慣れたツールに手が伸びる
- とっくに終わっているタスクを `sleep 30` で待つ
- プロセス名で見つからないからと「プログラムは終了した」と判断する。ウィンドウは画面に出ているのに
- 3 回失敗しただけで「技術的に不可能です」とユーザーに伝える
- 全画面のスクリーンショットを撮ったり、ウィンドウを最前面に出したりして、PC を使っているユーザーの邪魔をする

どれもタスクを即座に失敗させるわけではありません。ただ、**10 倍遅くなる、結論を誤る、ユーザーを置き去りにする**のです。このリポジトリの各 skill は実際に起きた事故に対応していて、何が間違っていたかを明らかにしたうえで、実行可能な手順とチェックリストを示します。

## 📚 Skills 一覧

| Skill | 正す癖 | いつ発動するか |
| --- | --- | --- |
| 🫥 [**background-friendly**](skills/background-friendly/SKILL.md) | 全画面スクショ、フォーカスを奪う、許可なくユーザーのマウスとキーボードを使う | スクリーンショット、GUI アプリの起動・デバッグ、UI 操作、computer-use を使う前 |
| 🪟 [**dialog-handling**](skills/dialog-handling/SKILL.md) | 見えないダイアログは存在しないとみなす。内容を読まずに閉じる。プロセス名でまとめて kill する | クリックが効かない、アプリが固まったように見える、コマンドが入力待ちで止まった |
| 🔍 [**never-give-up-early**](skills/never-give-up-early/SKILL.md) | 自分で数回試して失敗しただけで「不可能」と宣言する | 「うまくいかない / やる価値がない」と言う前 |
| ⏱️ [**no-blind-wait**](skills/no-blind-wait/SKILL.md) | 固定時間の sleep で結果を待つ | 何かの完了を sleep で待とうとしたとき |
| 📸 [**screenshot-first**](skills/screenshot-first/SKILL.md) | プロセス名や終了コードなど間接的な指標で状態を断定する | 「起動した / 終了した / 直った」と言う前 |
| 🚀 [**think-about-faster-path**](skills/think-about-faster-path/SKILL.md) | 最適なツールではなく、使い慣れたツールを惰性で使う | 時間のかかる操作、一括処理、マシンをまたぐ操作の前 |
| 🙋 [**maybe-it-was-the-user**](skills/maybe-it-was-the-user/SKILL.md) | ユーザーが閉じたウィンドウや編集したファイルをバグとみなし、デバッグや再起動を繰り返す | プログラム・ウィンドウ・ファイルが予期せず変わり、デバッグを始める前 |
| 🎨 [**style-fits-the-job**](skills/style-fits-the-job/SKILL.md) | 場面を問わず「AI っぽい」見た目：業務ツールにすりガラス・紫青グラデーション・ネオン、娯楽アプリは逆に味気ない | UI のデザインやスタイリングを始める前 |
| 🧭 [**think-like-the-user**](skills/think-like-the-user/SKILL.md) | ボタンの配置が不自然、入口が深い、不要な確認や手順が多い、頼まれていない機能・メニュー・入口を足す | 操作・フロー・フォーム・ダイアログを設計・変更するとき、UI 完成と言う前 |
| 🛠️ [**just-do-it-yourself**](skills/just-do-it-yourself/SKILL.md) | 自分で実行できるコマンド、読めるファイル、調べられるエラーなのに、止まってユーザーにやらせる | ユーザーに実行・確認・コピー・承認を頼む前 |

各 skill の**原則はプラットフォームに依存しません**。例が Windows / PowerShell 寄りなのは、Windows デスクトップと仮想マシンの自動化で実際に起きた出来事が元になっているからです。

> [!NOTE]
> skill ファイル本体は現在中国語で書かれています。最近の LLM エージェントは、会話の言語にかかわらず問題なく従います。翻訳も歓迎します（[コントリビュート](#-コントリビュート)を参照）。

### 早見表：エージェントが今まさに……

| しようとしていること | 先に読む |
| --- | --- |
| スクショを撮る、GUI を開く、画面を操作する | 🫥 background-friendly |
| 「完了 / 終了した / 直った」と言う | 📸 screenshot-first |
| 結果待ちに `sleep` を書く | ⏱️ no-blind-wait |
| 「できない / やる価値がない」と言う | 🔍 never-give-up-early |
| 遅い・一括・マシンをまたぐ処理を走らせる | 🚀 think-about-faster-path |
| 「クリックが効かない / 固まった」に直面した | 🪟 dialog-handling |
| 「突然」閉じた・変わったものをデバッグする | 🙋 maybe-it-was-the-user |
| UI の配色・フォント・エフェクトを選ぶ | 🎨 style-fits-the-job |
| ボタンを配置する、フローを設計する、UI 完成と言う | 🧭 think-like-the-user |
| ユーザーにコマンド実行や確認を頼む | 🛠️ just-do-it-yourself |

## 🔥 それぞれの由来

どの skill も具体的な事故から生まれています。開いて、そのとき何が起きたかを見てみてください。

<details>
<summary><b>🚀 think-about-faster-path</b>：同じファイルが、コマンドを変えただけで 20 倍速く</summary>

<br>

44.4 MB のファイルを 2 台のマシン間で転送する際、何気なく Windows PowerShell 5.1 の `Invoke-WebRequest` を使ったところ、数十秒かかり、ときにはタイムアウトしました。`curl.exe` に替えると **1.9 秒**でした。

原因は、5.1 のプログレスバー描画がダウンロードを何十倍も遅くすることです。しかも PowerShell 5.1 では `curl` は `Invoke-WebRequest` のエイリアスです。

**教訓**：より良いツールはずっと知っていた。手を動かす前に比較しなかっただけ。

</details>

<details>
<summary><b>⏱️ no-blind-wait</b>：10 秒で終わる作業に 100 秒以上待った</summary>

<br>

タスクスクリプトの中で `Start-Sleep 50`、さらに呼び出し側でも `Start-Sleep 54`。しかしそのリモート呼び出しは同期的で、戻ってきた時点でタスクはとっくに終わっていました。時間はすべて無駄になり、失敗しても「タイムアウト」としか分からず、どのステップで止まったのか見えません。

**教訓**：まず呼び出しが同期かどうかを確認する。ポーリングが必要なら「条件 + 間隔 + 全体のタイムアウト + タイムアウト後の対応」はどれも欠かせない。長い処理にはフェーズの目印を残す。

</details>

<details>
<summary><b>📸 screenshot-first</b>：プロセスは「存在しない」のに、ウィンドウは画面の真ん中に</summary>

<br>

プロセス名で検索すると空、`MainWindowTitle` も空だったため、プログラムは「終了した」と判断しました。スクリーンショットを見ると、ウィンドウは画面の真ん中でクリックを待っていました。ランタイムがイメージ名を数字の羅列に書き換えていたのです。

**教訓**：プロセス名、終了コード、ステータス欄はどれも間接的な指標にすぎない。一次情報と食い違ったら一次情報を信じ、なぜ間接指標が間違ったのかを突き止める。

</details>

<details>
<summary><b>🪟 dialog-handling</b>：何度も閉じられたダイアログこそが出口だった</summary>

<br>

繰り返し出てくる「バインドを解除しますか？」をノイズとみなして何度も閉じていました。実はアカウントが古いマシンに紐づいていたことこそがログイン失敗の原因で、「OK」を押して解除した途端、すべてが進みました。

**教訓**：処理する前にダイアログの内容を読み、それが障害なのか入口なのかを判断する。入口が取り消せない操作なら、先にユーザーに確認する。

</details>

<details>
<summary><b>🔍 never-give-up-early</b>：「打つ手なし」とされた問題が 30 分で解決</summary>

<br>

ある商用ソフトを仮想マシン内で起動させようと、自力で十数項目の設定を変えたものの全滅し、「検出が深すぎる。続ける価値はない」と結論づけました。ユーザーからは「転載記事 1 本と 1 回の試行だけで結論を出すのは調査不足だ」と指摘されました。その後 4 本の独立した調査を並行して進めたところ、そのうち 1 本が既存のオープンソースドライバを見つけ、**30 分ほど**で解決しました。

**教訓**：自分が試したのは解の空間のごく一部にすぎない。「無理」と言う前に、何を除外したかの具体的な証拠と、調べた情報源を示す。

</details>

<details>
<summary><b>🫥 background-friendly</b>：AI がデバッグ中、ユーザーは PC を使えない</summary>

<br>

「アプリが今どうなっているかちょっと見る」ために、エージェントはウィンドウを最前面に出して全画面を撮り、マウスを動かしてボタンを押していました。ユーザーの作業は何度も中断され、スクリーンショットには画面上のほかの内容まで写り込んでいました。

**改善後**：対象のウィンドウだけを撮る。隠れていても最小化されていても撮れて、フォーカスも奪わない。アプリは最小化・非アクティブの状態で起動する。UI Automation でボタン操作やテキスト入力をバックグラウンドで行う。どうしてもデスクトップを使う必要があるときは、**先に許可を求め、許可がなければ一時停止する**。

</details>

## 📦 インストール

### Claude Code

```bash
git clone https://github.com/Ringophilia/agent-rules-of-thumb.git
cd agent-rules-of-thumb

# すべてのプロジェクトで有効にする
mkdir -p ~/.claude/skills && cp -r skills/* ~/.claude/skills/
# 特定のプロジェクトだけで有効にする（そのプロジェクトのルートで実行）
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

必要な skill だけをコピーしても構いません。次に新しいセッションを開いたときから有効になります。

> [!TIP]
> skill が読み込まれるかどうかは、エージェントが `description` と目の前のタスクが合うかを自分で判断して決まります。あるルールを**常に有効**にしたい場合は、グローバルの `~/.claude/CLAUDE.md` に 1 行加えてください。例：
>
> ```markdown
> - スクリーンショット、GUI アプリの起動・デバッグ、computer-use の前に、background-friendly skill を読んで従うこと。
> ```

### Agent Skills 標準に対応したその他のエージェント

各ツールの skills ディレクトリに skill のディレクトリを置いてください。場所は各ツールのドキュメントを参照してください。

### skills に対応していないツール

`SKILL.md` の本文（冒頭の 2 つの `---` で囲まれた部分を除いたもの）をシステムプロンプトやルールファイルに貼り付けてください。原則自体は特定のプラットフォームに依存しません。

## 🧰 依存ゼロのスクリプト集

2 つの skill には、そのまま実行できる Windows スクリプトが付属しています。**Windows に標準で入っている PowerShell 5.1 と .NET Framework だけ**で動き、追加のインストールは不要です。

| 用途 | スクリプト | ユーザーの邪魔をするか |
| --- | --- | :---: |
| 隠れている／非表示の Win32 ダイアログを探し、子コントロールのテキストと ID を読む | [`dialog-handling/scripts/list-windows.ps1`](skills/dialog-handling/scripts/list-windows.ps1) | しない |
| Win32 ダイアログのボタンを押す（WM_COMMAND、アクティブ化不要） | [`dialog-handling/scripts/press-button.ps1`](skills/dialog-handling/scripts/press-button.ps1) | しない |
| 単一ウィンドウを撮る（隠れていても最小化されていても可、フォーカスを奪わない） | [`background-friendly/scripts/capture-window.ps1`](skills/background-friendly/scripts/capture-window.ps1) | しない |
| 複数のスクショをラベル付きの 1 枚のグリッドにまとめ、一目で比較する。`-Diff` で変化箇所を赤枠表示。`capture-window.ps1 -Burst` は連写して 1 枚にまとめる | [`background-friendly/scripts/compose-shots.ps1`](skills/background-friendly/scripts/compose-shots.ps1) | しない |
| プログラムを最小化・非アクティブで起動し、出力をログに書く | [`background-friendly/scripts/start-quiet.ps1`](skills/background-friendly/scripts/start-quiet.ps1) | しない |
| UI Automation でコントロールツリーを読み、ボタンを押し、テキストを入力し、チェックを切り替える | [`background-friendly/scripts/uia.ps1`](skills/background-friendly/scripts/uia.ps1) | しない |
| 実際のマウス・キーボード入力。終了後に前面ウィンドウとカーソル位置を元に戻す | [`background-friendly/scripts/desktop-input.ps1`](skills/background-friendly/scripts/desktop-input.ps1) | ⚠️ 要許可 |

```powershell
# 例：最小化されたウィンドウを撮影し、テキストボックスに入力してボタンを押す。
# すべてバックグラウンドで、フォーカスは奪わない
.\capture-window.ps1 -Title "My App" -Out shot.png
.\uia.ps1 -Title "My App" -ControlType Edit -SetValue "hello"
.\uia.ps1 -Title "My App" -Name "OK" -Invoke
# 前後比較を 1 枚に（変化は赤枠）、6 フレームの連写を 1 枚の時系列に
.\compose-shots.ps1 -Inputs "before.png||after.png" -Diff -Out diff.png
.\capture-window.ps1 -Title "My App" -Burst 6 -IntervalMs 300 -Out sheet.png
```

> [!NOTE]
> `uia.ps1` は初回実行時に、Windows 付属の `csc.exe` で `uia.cs` を `uia.exe` にコンパイルします。Windows PowerShell の中ではマネージド UIA クライアントが Win32 コントロールのプロキシを読み込めず、すべてのコントロールがパターンを持たない `Pane` として見えてしまうためです。すべてのスクリプトは純粋な ASCII にしてあり、PowerShell 5.1 が BOM なし UTF-8 を ANSI コードページで読んで文字化けする問題を避けています。

## 🧱 Skill の構成

[Agent Skills](https://agentskills.io) オープン標準に従っています。各 skill は 1 つのディレクトリで、入口は `SKILL.md` です。

```
skills/
  <skill-name>/
    SKILL.md        # YAML frontmatter（name + description）+ Markdown 本文
    scripts/        # 任意：skill から参照される実行可能スクリプト
```

エージェントが skill を読み込むかどうかを判断する材料は `description` だけです。そのため、どの skill にも**何をするか**と**いつ使うか**の両方を書いています。

各 skill の本文はおおむね同じ構成です。

1. **失敗例**：実際に起きた事故と、何が間違っていたか
2. **発動のサイン**：自分が何をしよう・何を言おうとしていたら立ち止まるべきか
3. **正しいやり方**：実行可能な手順、コマンド、コード
4. **境界**：ルールが当てはまらない場合、ユーザーに確認すべき場合
5. **チェックリスト**：手を動かす前、完了を宣言する前に一つずつ確認する

## 🤝 コントリビュート

Issue と PR を歓迎します。特に次のようなものを歓迎します。

- **新しい失敗例**：あなたのエージェントが繰り返す失敗。当時の状況（コマンド、出力、スクリーンショット）を添えて
- **他プラットフォームの例**：macOS / Linux での同等の手順やスクリプト
- **反例**：あるルールがあなたの状況では誤った指針になった
- **翻訳**：skill 本体やこの README の各言語版

skill を追加するときは次の約束事を守ってください。実際の出来事から出発すること。`description` には「何をするか + いつ使うか」を書くこと。本文はスローガンではなく実行可能な手順にすること。スクリプトは依存ゼロ・純粋な ASCII にすること。

## 📄 ライセンス

[MIT](LICENSE) © 2026 Ringophilia
