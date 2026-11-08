---
name: no-blind-wait
description: 编排"发起 → 等待 → 取结果"时，用同步返回、完成事件或带总超时的条件轮询代替固定时长的 sleep，并给长流程打阶段标记，超时时能定位卡在哪一步。当准备写 sleep / Start-Sleep / time.sleep / setTimeout 来"等它好"，等待服务就绪、端口、文件、页面、窗口出现，远程或后台执行任务，或某一步耗时远超预期、分不清是卡住还是在正常运行时使用。Use whenever you are about to sleep a fixed time to wait for something.
---

# 拒绝盲等

## 核心事实

`sleep` 解决不了"我不知道它什么时候结束"这个信息问题。它只是把不确定的等待换成了确定的浪费：睡短了，结果没出来；睡长了，时间白白浪费。

等待手段按代价从低到高排列，**永远先看能不能用更靠前的那个**：

| 手段 | 代价 | 何时可用 |
| --- | --- | --- |
| 同步调用（阻塞到对端结束，自带超时） | 零 | 对端支持；绝大多数 CLI、单条 ssh / curl / 远程执行都是 |
| 完成事件（退出码、回调、webhook、宿主的后台任务通知） | 低 | 对端会主动通知 |
| 条件轮询（查完成标志，带总超时） | 中 | 对端只能落盘或写状态 |
| 固定时长 sleep | 高 | 几乎没有正当理由 |

最常见的事故不是"用了 sleep"，而是**把同步调用当成了异步，又在外面套了一层 sleep**。

> 如果你运行在支持后台任务、会在任务结束时通知你的智能体环境里，长任务就放到后台跑、等通知，不要在前台循环 sleep。

## 错误写法

实测：本来 10 秒就能完成的活，等了 100 多秒。

```powershell
# 任务脚本内部
Start-Sleep -Seconds 50
# 宿主又等了一遍
Start-Sleep -Seconds 54
```

两个问题同时存在：时间全浪费了（任务实际 10 秒就完成），出错时也只能看到一个"超时"，看不出卡在哪一步。

根因很朴素：那个调用本身就是同步的（远程执行、本地子进程、单条 `curl`、单条 `ssh`），返回时任务就已经完成，根本不需要再等。

## 正确写法

### A. 靠同步返回，并检查结果

```powershell
vmrun -T ws -gu USER -gp PASS runProgramInGuest VMX powershell.exe -NoProfile -File C:\task.ps1
# 阻塞到对端进程退出。返回后立刻检查退出码和输出，不要假设成功
if ($LASTEXITCODE -ne 0) { throw "task failed: $LASTEXITCODE" }
```

同步调用也要有超时上限：`timeout 300 cmd`（Linux）、`curl --max-time`、`ssh -o ConnectTimeout=10`，或者工具本身的超时参数。

### B. 条件轮询：条件 + 间隔 + 总超时 + 超时后做什么

**四样缺一不可。** 通用写法：

```powershell
function Wait-Until([scriptblock]$Cond, [string]$What, [int]$TimeoutSec = 60, [int]$IntervalMs = 500) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if (& $Cond) { return }                       # 先查后睡：已经好了就不必等
        if ($sw.Elapsed.TotalSeconds -ge $TimeoutSec) { throw "Timeout ${TimeoutSec}s waiting for: $What" }
        Start-Sleep -Milliseconds $IntervalMs
    }
}
Wait-Until { Test-Path C:\out\DONE } -What 'DONE marker'
Wait-Until { try { (Invoke-WebRequest http://localhost:8080/health -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200 } catch { $false } } -What 'health 200'
```

```bash
timeout 60 bash -c 'until curl -sf http://localhost:8080/health >/dev/null; do sleep 0.5; done' \
  || { echo "health check timeout"; exit 1; }
```

**间隔怎么定**：
- 默认 0.5~2 秒
- 单次检查本身就慢（比如每次都要从虚拟机里拷一个文件出来）→ 间隔取单次检查耗时的 1~2 倍。实测跨虚拟机拷文件取 1~1.5 秒比较合适
- 预计要几分钟以上的任务 → 放宽到 5~15 秒，或者用指数退避
- 再短也没有意义，检查本身的往返时间就是下限

## 阶段标记比超时值重要

任务每完成一个阶段就写一行，并 flush：

```powershell
'phase1 download done' | Out-File C:\out.txt -Encoding utf8
# ... 干活 ...
'phase2 install done'  | Out-File C:\out.txt -Append -Encoding utf8
'DONE'                 | Out-File C:\out.txt -Append -Encoding utf8
```

调度端在条件轮询里查 `DONE`。超时时**打印最后一个阶段**：

```
phase1 download done
phase2 install done
                       ← 卡在 phase3
```

没有阶段信息时，超时只说明"没成功"；有了阶段信息，超时直接指向故障点。这比任何错误码都有用，而且不需要改任务逻辑，只是多写几行。

## 超时之后：先诊断，别加时长

超时的第一反应**不应该**是"把 60 秒改成 120 秒再试一次"。先看：
- 最后一个阶段标记停在哪
- 对端日志的最后几行
- 一手画面：是不是有弹窗在等人点（见 screenshot-first、dialog-handling）
- 进程还活着吗？CPU 有没有在动？

确认它确实只是慢、在正常推进，才去调大超时。

## GUI 和服务：等条件，不等时钟

窗口切换、页面跳转、服务就绪，本质都是**状态迁移**，不是时间流逝。

```powershell
# 错
Click-Button
Start-Sleep -Seconds 5      # 假设 5 秒够切换
Click-Next

# 对
Click-Button
Wait-Until { Find-Window -Class 'WTWindow' -Title '*模式*' } -What 'mode window' -TimeoutSec 10 -IntervalMs 300
Click-Next
```

同一个模式适用于：等端口进入 listen、等健康检查返回 200、等文件出现、等日志里出现某一行、等页面元素可点击（浏览器自动化工具一般自带 wait-for-selector，优先用它）。

## 检查清单

- [ ] 这处 sleep 能不能换成同步返回或完成事件
- [ ] 同步调用返回后，检查退出码和输出了吗
- [ ] 每个等待都有"条件 + 间隔 + 总超时 + 超时后做什么"吗
- [ ] 有没有超过 2 秒的固定 sleep？理由是什么
- [ ] 长流程每个阶段都写标记了吗？超时能不能定位到阶段
- [ ] 超时后是先诊断，还是直接加时长
