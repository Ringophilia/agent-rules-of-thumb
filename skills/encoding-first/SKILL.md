---
name: encoding-first
description: 写入含中文或其他非 ASCII 字符的文件（脚本、配置、数据、源码）之前，先按"谁来读它"选对编码和 BOM，而不是先随手保存、出错了再改。Windows PowerShell 5.1 读无 BOM 的 .ps1 会按 ANSI 码页（如 GBK）解析而乱码报错；.bat/.cmd 遇到 BOM 第一行就坏；bash/sh 的 shebang、JSON、大多数 Unix 工具不能有 BOM；Excel 打开 CSV 要 BOM；Python 在中文 Windows 上 open() 默认按 GBK 读。在要写或改 .ps1 .bat .cmd .sh .py .json .csv .reg .cs 等文件且内容含非 ASCII 字符、用 PowerShell 的 Set-Content/Out-File/> 写文件、或看到乱码（锟斤拷、鍙傛暟、�、ï»¿）和"缺少终止符"、UnicodeDecodeError 'gbk'、"Unexpected token in JSON at position 0" 之类的错误时使用。写完用字节检查确认，项目已有约定就照着做，同类错误一次修完。Use before writing any file containing non-ASCII text, and at the first sign of mojibake or encoding errors.
---

# 先定编码，再写文件

## 问题

AI 写含中文的脚本，常见的流程是：

```
随手保存（编码随工具默认）→ 运行 → 乱码 / 语法错误 → 排查半天才想到是编码 → 改编码 → 下一个文件再犯一次
```

这类错误**完全可以在写之前避免**：每种文件由谁来读、它认什么编码，是确定的、可以查表的。它的报错却往往不像编码问题（"字符串缺少终止符"、"不是内部或外部命令"、"意外的标记"），所以每次都要浪费一轮排查。

## 写之前：先问"谁来读它"

编码是给**读取方**选的，不是给写入方。查下表：

| 文件 / 读取方 | 用什么 | 为什么 |
| --- | --- | --- |
| `.ps1`，要在 **Windows PowerShell 5.1** 里运行 | **纯 ASCII**（首选），或 **UTF-8 带 BOM** | 5.1 读无 BOM 文件时按系统 ANSI 码页（中文系统是 GBK/936），中文变乱码，引号被吞，报"字符串缺少终止符" |
| `.ps1`，只在 PowerShell 7+ 运行 | UTF-8（有无 BOM 都行） | 7+ 默认 UTF-8 |
| `.bat` / `.cmd` | **纯 ASCII**（首选），或系统 ANSI 码页；**不能有 BOM** | cmd 按控制台码页读；BOM 会粘在第一行前面，报 `'@echo' 不是内部或外部命令`（`@echo` 前面带着看不见的或乱码的字符） |
| `.sh`、带 shebang 的任何脚本 | UTF-8 **无 BOM**，LF 换行 | BOM 在 `#!` 前面，shebang 失效；CRLF 会导致 `$'\r': command not found` |
| `.py` | UTF-8 无 BOM | Python 3 源码默认 UTF-8 |
| `.json` | UTF-8 **无 BOM** | 规范禁止加 BOM，很多解析器直接报错 |
| `.yaml` `.toml` `.ini`（给 Unix 工具/跨平台工具） | UTF-8 无 BOM | |
| `.csv`，要给 **Excel** 打开 | UTF-8 **带 BOM** | 没有 BOM 时 Excel 按 ANSI 打开，中文乱码 |
| `.csv`，给程序读 | UTF-8 无 BOM | |
| `.reg` | UTF-16 LE 带 BOM（`Windows Registry Editor Version 5.00`） | regedit 导出的默认格式 |
| `.cs` 用 .NET Framework 的 `csc.exe` 编译 | 纯 ASCII，或 UTF-8 带 BOM，或加 `/codepage:65001` | 无 BOM 时按系统码页读 |
| 网页 `.html` `.css` `.js` | UTF-8 无 BOM，HTML 里写 `<meta charset="utf-8">` | |
| 项目里已有的文件 | **保持原编码和换行** | 不要顺手把整个文件转码，会产生满屏 diff |

**最省事的办法：脚本本身尽量只用 ASCII。** 注释写英文；必须输出中文时，把中文放在单独的数据文件里按明确编码读，或者用转义：

```powershell
# PowerShell 5.1: build non-ASCII text from code points, the script stays pure ASCII
$msg = -join ([char[]](0x5B8C, 0x6210))   # "完成"
```

```bat
rem batch: keep the .bat pure ASCII; put Chinese text in a separate file if really needed
```

## 用对写文件的方法

写入工具的默认编码，经常不是你以为的那个。

### Windows PowerShell 5.1（最容易踩坑）

| 写法 | 5.1 实际写出的编码 |
| --- | --- |
| `Set-Content` / `Add-Content`（不带 `-Encoding`） | 系统 ANSI 码页（中文系统是 GBK） |
| `Out-File` / `>` / `>>`（不带 `-Encoding`） | **UTF-16 LE** 带 BOM（可能被配置改过，不要依赖默认值） |
| `-Encoding UTF8` | UTF-8 **带 BOM**（5.1 没有无 BOM 选项） |

需要 UTF-8 无 BOM 时：

```powershell
[IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false))
```

需要 UTF-8 带 BOM 时：

```powershell
[IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $true))
```

PowerShell 7+ 可以直接用 `-Encoding utf8NoBOM` / `-Encoding utf8BOM`。

### Python（中文 Windows 上）

`open()` 不写 `encoding` 时用系统码页（GBK），读写 UTF-8 文件就会 `UnicodeDecodeError: 'gbk' codec can't decode`。**永远显式写编码**：

```python
open(path, encoding="utf-8")            # 读写 UTF-8 无 BOM
open(path, encoding="utf-8-sig")        # 读：自动去掉 BOM；写：加上 BOM（给 Excel 的 CSV）
```

输出到控制台乱码或 `UnicodeEncodeError` 时，设置 `PYTHONUTF8=1`（或 `python -X utf8`）。

### 智能体自带的文件工具

很多智能体的写文件工具写出的是 UTF-8 无 BOM。对大多数文件这是对的，**但对 Windows PowerShell 5.1 的 .ps1 是错的**：含中文就会出问题。写 .ps1 之前想一下它会被哪个 PowerShell 运行。

### 传给其他程序的文本

管道和命令行参数也有编码：PowerShell 5.1 向外部程序传管道数据用 `$OutputEncoding`（默认 ASCII，中文变 `?`），读外部程序输出用 `[Console]::OutputEncoding`。传中文前设置好：

```powershell
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
```

## 写完：用字节确认

不要靠"看起来对"，看文件头几个字节：

```bash
head -c 3 file | xxd          # ef bb bf = UTF-8 BOM；ff fe = UTF-16 LE
file file.ps1                 # "UTF-8 Unicode (with BOM) text" / "ASCII text"
grep -nP '[^\x00-\x7F]' file  # 找出所有非 ASCII 字符（要求纯 ASCII 时用）
```

```powershell
Format-Hex file.ps1 | Select-Object -First 1
```

改完再实际运行一次，确认中文输出正确。

## 认出编码错误

看到这些，**第一反应就该想到编码**，而不是语法或逻辑：

| 现象 | 通常的原因 |
| --- | --- |
| `锟斤拷`、`�` | UTF-8 被错误解码后又编码，或无效字节 |
| `鍙傛暟`、`娴嬭瘯` 这类生僻字串 | UTF-8 被按 GBK 读了 |
| `ï»¿` 出现在开头 | UTF-8 BOM 被当成了普通字符 |
| PowerShell："字符串缺少终止符"、"意外的标记"，出错行含中文 | 5.1 按 GBK 读了无 BOM 的 UTF-8 脚本 |
| `'@echo' 不是内部或外部命令`，命令名前面有看不见的或乱码的字符 | .bat 带了 BOM |
| `UnicodeDecodeError: 'gbk' codec can't decode` | Python `open()` 没写 `encoding` |
| `Unexpected token in JSON at position 0` / `Unexpected UTF-8 BOM` | JSON 带了 BOM |
| `/bin/bash^M: bad interpreter`、`$'\r': command not found` | 换行是 CRLF |
| 中文全变成 `?` | 经过了只支持 ASCII 的通道（`$OutputEncoding`、控制台码页） |

## 不要重复犯

- **项目已有约定就照着做。** 先看看项目里同类文件是什么编码（`file`、看 BOM），有没有 `.editorconfig`、`.gitattributes`、README 里的说明。比如有的项目约定"脚本保持纯 ASCII"。
- **一次修完同类问题。** 一个 .ps1 因为编码出错，就检查本次写过的所有 .ps1，而不是等它们一个个报错。
- **记下来。** 在这个环境里踩过的编码坑（比如"这台机器的脚本由 PowerShell 5.1 运行"），如果有持久记忆或项目说明文件，记进去，下次写之前就知道。

## 检查清单

- [ ] 这个文件含非 ASCII 字符吗？能不能改成纯 ASCII？
- [ ] 谁来读它？（PowerShell 5.1 / cmd / bash / Python / Excel / JSON 解析器 / 编译器）
- [ ] 按表选好了编码和 BOM，以及换行（LF / CRLF）？
- [ ] 写文件的方法真的会写出这个编码吗？（PowerShell 5.1 的默认值、Python 的 `encoding=`）
- [ ] 改已有文件时保持了原编码和换行？
- [ ] 写完用字节检查过文件头，并实际运行确认中文正常？
- [ ] 同类文件都一并检查了吗？
