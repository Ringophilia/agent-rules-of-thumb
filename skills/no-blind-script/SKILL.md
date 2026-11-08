---
name: no-blind-script
description: "A fixed end-to-end script suits deterministic work (renames, conversions, builds, batch API calls) but not changing systems (game or GUI automation, installers, web flows, VMs, long deploys): check preconditions before key steps, stop and report on unexpected state, or go step by step and observe. Use before scripting a long action sequence against a changing system, and after a one-shot script has failed twice."
---

# 脚本不要闭着眼睛跑

## 反面案例（真实发生）

**目标**：测试一个游戏，让角色自动打怪。

**AI 的做法**：写了一个脚本：移动到某处 → 攻击 → 等几秒 → 再攻击 → 捡东西 → 移动到下一处……一个固定的动作序列，从头跑到尾。

**结果**：中途角色被怪打死了。脚本完全不知道，依然默认角色活着，继续发送移动、攻击、捡东西的指令，对着死亡画面操作了很久。后面的所有"测试结果"都没有意义，而且要从日志里倒推才发现问题从哪一步开始。

## 问题出在哪

脚本把**"我发出了指令"当成了"事情按预期发生了"**。一个固定序列的脚本，隐含了一个假设：每一步之后，世界都处在你预想的状态。

这个假设在有些场景下成立，在有些场景下根本不成立：

| 场景 | 变数 | 一次性脚本 |
| --- | --- | --- |
| 批量改名、格式转换、批量处理文件 | 几乎没有 | ✓ 最快，就该这么做 |
| 调用确定的 CLI / API，失败会返回错误码 | 少，且失败可检测 | ✓ 加上错误即停 |
| 构建、测试、打包 | 少 | ✓ |
| 游戏自动操作、GUI 自动点击 | 多：角色死亡、弹窗、加载、随机事件、界面变化 | ✗ 必须边做边检查 |
| 安装向导、网页多步流程 | 中：弹窗、验证码、页面结构变化、网络慢 | 需要检查点 |
| 跨机、长链路部署、虚拟机操作 | 中到多：重启、超时、中间状态 | 需要检查点，或分阶段 |
| 与人或其他程序同时操作的系统 | 多：别人会改状态（见 maybe-it-was-the-user） | 需要检查点 |

## 三种做法，按情况选

### 1. 一次性脚本

**适合**：确定、可预测、失败能被检测到的操作。不要把这种事拆成很多步手动做，那只是浪费时间（见 think-about-faster-path）。

但一定要**出错即停**，不要让它带着错误继续跑：

```powershell
$ErrorActionPreference = 'Stop'
```
```bash
set -euo pipefail
```

### 2. 带检查点的脚本

**适合**：流程基本固定，但中途可能出现意外状态。

在每个关键动作前**检查前置条件**，状态不对就停下来报告，而不是继续：

```python
def require(cond, msg):
    if not cond:
        save_screenshot(f"unexpected_{step}.png")
        raise RuntimeError(f"[{step}] 意外状态：{msg}")

for step, target in enumerate(targets):
    require(player.hp > 0,          "角色已死亡")
    require(not ui.has_dialog(),    "出现了弹窗")
    require(ui.scene() == "field",  f"不在战斗场景，当前是 {ui.scene()}")

    move_to(target)
    require(player.near(target),    "没有走到目标位置")
    attack(target)
    wait_until(lambda: target.dead or player.hp <= 0, timeout=30)   # 条件等待，见 no-blind-wait
```

更进一步，把线性序列改成**状态机**：每一轮先读当前状态，再决定做什么。

```python
while not done:
    s = read_state()
    if s.player_dead:   handle_death(); continue      # 复活 / 记录 / 停止
    if s.dialog:        handle_dialog(s.dialog); continue
    if s.low_hp:        heal(); continue
    if s.enemy_nearby:  attack(s.nearest_enemy); continue
    explore()
```

检查点要用**能直接反映状态的信号**：血量、场景 ID、窗口标题、控件是否存在、截图特征、接口返回值，而不是"上一步执行了没报错"（见 screenshot-first）。

### 3. 分步执行

**适合**：变数很多、你还不了解这个系统的行为、或者一次性脚本已经失败过。

执行一步 → 观察结果（截图、读状态、看输出）→ 再决定下一步。慢一些，但每一步都踩在真实状态上。摸清楚流程之后，再把稳定的部分写回脚本里。

## 什么时候该切换

**一次性脚本失败两次以上**，特别是**每次失败的地方不一样**，就说明这个流程里有你没预料到的变数。不要继续修修补补、加更长的 sleep、再跑一遍：

1. 停下来，看清楚每次是在哪一步、因为什么状态失败的。
2. 在那些地方加检查点；或者干脆改成分步执行，先把流程摸清楚。
3. 稳定之后，再合并回脚本。

反过来，分步执行了好几轮，每一步都完全按预期发生，那就可以把它们合成一个脚本，提升效率。

## 让脚本好排查

- **每一步打阶段标记**，失败时能立刻知道卡在哪一步（见 no-blind-wait）。
- **意外状态时留证据**：截图、当时的状态快照、最后几行日志。
- **能续跑**：失败后能从出错的那一步继续，而不是全部从头再来。已完成的步骤可以跳过（幂等）。
- **破坏性操作先空跑**：批量删除、批量修改之前，先 `-WhatIf` / `--dry-run` 看一遍会做什么。

## 边界

- 不要把所有事情都拆成分步执行。确定的批量操作就该一个脚本跑完，拆开反而慢、反而更容易漏。
- 检查点不需要每一行都加，加在**状态可能偏离预期的地方**：等待外部反馈之后、跨越界面/场景之后、长时间操作的每一轮开头。
- 用户明确要一个一次性脚本时，照做，但要在可能出现变数的地方加检查点，并告诉用户你加了哪些。

## 检查清单

- [ ] 这个流程中途会出现变数吗？（随机性、外部反馈、界面变化、别人的操作、重启、超时）
- [ ] 确定的批量操作：用了一次性脚本，并设置了出错即停？
- [ ] 有变数的流程：关键动作前检查了前置条件？意外状态会停下来报告，而不是继续操作？
- [ ] 检查用的是直接反映状态的信号，而不是"上一步没报错"？
- [ ] 一次性脚本已经失败两次以上了吗？是不是该加检查点或改成分步？
- [ ] 失败时能知道卡在哪一步、能留下证据、能从那一步续跑吗？
