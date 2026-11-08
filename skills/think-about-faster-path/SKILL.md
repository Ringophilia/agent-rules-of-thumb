---
name: think-about-faster-path
description: "Before an operation that takes more than ~10 seconds, moves a large file (~100 MB+), or is repeated, bulk or cross-machine, spend ten seconds comparing paths: skip it, a native tool, parallelism, one batch call, processing where the data lives. The habitual or built-in tool is often an order of magnitude slower; an environment's own copy command (VM guest copy, docker cp, adb pull, remote-shell upload) is usually a slow control channel, so move big data over the network instead. Use before transfers, bulk file work, looped remote or API calls, and whenever a step is much slower than expected."
---

# 先想有没有更快的做法

## 反面案例（真实发生）

**目标**：把一个 44.4 MB 的文件从一台机器传到另一台。

**我的做法**：Windows PowerShell 5.1 的 `Invoke-WebRequest`。

**结果**：几十秒，有时直接超时失败。

**换成 `curl.exe` 之后**：

```
size=46571520  speed=24356572 B/s  time=1.912s
```

**1.9 秒，快了二十倍。** 而我一开始就知道有 curl，只是"顺手用了 PowerShell 的 cmdlet"。

（事后查明根因：5.1 的进度条渲染会把下载拖慢几十倍，设置 `$ProgressPreference = 'SilentlyContinue'` 就能消掉大部分差距。另外，**在 PowerShell 5.1 里 `curl` 是 `Invoke-WebRequest` 的别名**，必须写成 `curl.exe` 才会调用真正的 curl。）

## 问题出在哪

不是不知道更好的工具，是**下手前没做这个比较**。习惯性地选了"最熟悉的"，而不是"最合适的"。

## 动手前的五问

### 1. 能不能不做？

- 结果是不是已经存在了（缓存、上一次的产物、对方已经有这个文件）
- 能不能只取需要的那一部分：`git clone --depth 1`、HTTP Range、只查需要的列、`head` 代替全量读取
- 能不能直接在数据所在的机器上处理，只把结果传回来

### 2. 有没有原生工具？

系统自带或专用的命令行工具，通常比脚本层的封装快一个数量级：

| 任务 | 慢 | 快 |
| --- | --- | --- |
| HTTP 下载 | PS 5.1 的 `Invoke-WebRequest`（带进度条） | `curl.exe -L -o`；或者先关掉进度条 |
| 跨机器 / 跨环境传大文件 | 环境自带的拷贝命令：虚拟机的 guest 拷贝（`vmrun copyFileFromGuestToHost`、`Copy-VMFile`）、`docker cp`、`adb pull`、WinRM `Copy-Item -ToSession`。它们是给小文件和控制命令设计的管理通道，大文件很慢 | 走网络数据通道：一端 `python -m http.server`，另一端 `curl.exe`；SMB 共享；`scp` / `rsync`。能压缩的先压缩，传完校验哈希 |
| 大量小文件复制 | `Copy-Item` 循环 | `robocopy src dst /E /MT:16`；`rsync -a` |
| 文本搜索 | `Select-String` 递归、逐个文件读取 | `rg`（ripgrep） |
| 批量解压 | `Expand-Archive` 循环 | `7z x "*.zip" -o*` 一次处理 |
| PowerShell 收集结果 | 循环里 `$arr += $x`（每次都复制整个数组，O(n²)） | `$list = foreach (...) { $x }` 或 `[System.Collections.Generic.List[object]]` |
| PowerShell 逐行写文件 | 循环里 `Add-Content`（每次开关文件） | 收集好后一次 `Set-Content`，或者用 `StreamWriter` |
| 大文件逐字节扫描 | 脚本层 `for` 循环 | Python + `mmap` / `numpy`；或者交给 `rg -a` |

### 3. 能不能并行？

串行处理 N 个独立任务耗时 N×T，并行只要 ~T（受核数、带宽、配额限制）。

```
独立的网络请求     → 并发（注意对方的限流）
独立的文件处理     → 分批并行：xargs -P、PowerShell 7 的 ForEach-Object -Parallel
独立的子智能体任务 → 一次全部派出去
独立的工具调用     → 放在同一轮里一起发出
```

不该并行的情况：任务之间有顺序依赖、共享可变状态、目标是机械硬盘（并行随机读写反而更慢）、对方 API 有严格的速率限制。PowerShell 5.1 的 `Start-Job` 每个任务都要起一个进程，开销很大，小任务并行反而更慢。

### 4. 能不能一次做完？

- 传一个打包好的大文件，不要传一百个小文件
- 一次批量查询，不要循环单条查询
- 一次远程执行一个完整脚本，不要每条命令各走一次往返

```powershell
# 慢：每个命令一次往返
runRemote "cmd1"; runRemote "cmd2"; runRemote "cmd3"
# 快：一个脚本做完所有事，一次往返
runRemote -File all_in_one.ps1
```

### 5. 不确定哪个快？量一下，别猜

先拿一个小样本计时，再推算全量：

```powershell
Measure-Command { <方法A 处理 100 条> }
Measure-Command { <方法B 处理 100 条> }
```

```bash
time <方法A 处理 100 条>
```

## 执行中：比预期慢就停下来

某一步耗时明显超出预估（比如预计 10 秒，跑了 1 分钟还没完），**不要干等**：
- 看它实际卡在哪（见 no-blind-wait 的阶段标记）
- 重新问一遍上面五个问题
- 判断是该换方法，还是确实需要这么久

## 不要过度优化

这条规则的反面是"为了快而把事情搞复杂"。判断标准：

```
换方法只需 1 分钟，能省 5 分钟以上   → 值得换
换方法要研究 30 分钟，只省 2 分钟     → 不值得
只跑一次、本来就 3 秒的操作           → 别想了，直接做
```

**但"用 `curl.exe` 代替 `Invoke-WebRequest`"这种零成本的替换，永远值得。**

## 检查清单

- [ ] 能不能不做，或者只做需要的那一部分
- [ ] 有没有原生命令行工具可以替代
- [ ] 预估耗时超过 10 秒吗？超过就先想替代方案
- [ ] 大文件先算一下：数据量 ÷ 通道速度。不知道速度，就拿一个小样本（如 50 MB）测一次再推算
- [ ] 能不能一次做完，而不是循环
- [ ] 能不能并行？有没有不该并行的理由
- [ ] 不确定时，用小样本量过了吗
- [ ] 换方法的成本和能省下的时间比，划算吗
