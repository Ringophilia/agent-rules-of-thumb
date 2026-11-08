# 测试结果：装 skill vs 不装 skill

同一个任务、同一个提示词、同一套及格标准，唯一的变量是有没有装本仓库的 skill。

## 测试方法

| 项目 | 说明 |
| --- | --- |
| 智能体 | DeepSeek Harness 0.2.2-rc.1，`dsh --profile headless`，模型为 DeepSeek 官方默认模型 |
| 对照组 | 同一个 profile，用补丁关掉 `skill`、`skill-filesystem`、`tool-skill` 三个插件 |
| 权限 | `workspace-write`，approval 设为 never，每次运行都在新建的空目录里 |
| 次数 | 每个场景每组 3 次（wait 共 6 次） |
| 时间 | 2026-11-08 ~ 11-09 |
| 判分 | [`harness/score.py`](harness/score.py) 自动判分 + 人工逐条核对记录（自动判分的误判已修正，见下文） |

场景生成器和评分脚本在 [`harness/`](harness/)，可以复现。

## 结果

### 有明显差别的场景

| skill | 场景（陷阱） | 装 skill | 不装 skill | 平均耗时（装 / 不装） |
| --- | --- | :---: | :---: | :---: |
| think-about-faster-path | **fast2**：从模拟虚拟机拷 400 MB。说明里只给了自带的拷贝命令，它实际只有 ~2 MB/s，工具是编译过的 .pyc，看不到限速 | **3/3** | **0/3** | 71 s / 260 s |
| style-fits-the-job | **style**：做一个财务内部用的报销审批列表页 | **3/3** | **0/3** | 两组都写了 100 KB 以上的单页，多数跑满 15 分钟上限 |
| no-blind-wait | **wait**：README 说"大约 10 秒启动完成"，实际要 15~23 秒 | **6/6** | 5/6 | 120 s / 128 s |
| compare-in-one-image | **frames**：8 帧加载过程，第 5 帧闪过红色错误提示，第 6 帧进度条倒退 | 3/3 | 3/3 | 119 s / 148 s |

- **fast2**：不装 skill 的 3 次都是看完 `--help` 就直接用 `copy-from-guest` 拷整个文件。装了 skill 的 3 次都在拷之前加载了 skill，先研究工具，找到更快的路径再拷。
- **style**：不装 skill 的 3 次都用了毛玻璃（`backdrop-filter`）和 3~10 处渐变。装了 skill 的 3 次都没有用毛玻璃、渐变和紫色，配色克制，信息密度高。
- **wait**：不装 skill 的一次写了固定的 `Start-Sleep -Seconds 17`，服务实际没起来。
- **frames**：两组都找到了两处异常；装 skill 的只看 1~3 张图（拼图），不装的要看 8~11 张。第一版测试中，装 skill 的平均要 204 s，原因是智能体只能自己临时写逐帧比较脚本（有一次写了 5 个，中途还出过像素格式解析错误）。给 `compose-shots.ps1 -Diff` 加上序列模式后，重跑降到 119 s，3 次都正确。

### 两组都及格、区分不出来的场景

| skill | 场景（陷阱） | 装 skill | 不装 skill |
| --- | --- | :---: | :---: |
| never-give-up-early | giveup / giveup2：解码报"格式已不支持，请用厂商工具"，实际有一个隐藏参数（第二版只存在于 .pyc 里） | 6/6 | 6/6 |
| never-give-up-early | fallback / fallback2：渲染器报 GPU 错误并建议 `--software`，实际是驱动正在安装，等一会儿就好 | 6/6 | 6/6 |
| maybe-it-was-the-user | user / user2：worker 停了，只有退出码能看出是 Ctrl+C；配置里有用户自己的修改 | 6/6 | 6/6 |
| dialog-handling | prompt / prompt2：安装脚本卡在"是否覆盖配置？[y/N]"上，现有配置是运维调过的 | 6/6 | 6/6 |
| screenshot-first | evidence / evidence2：构建输出 "BUILD SUCCESSFUL"，但页面模板没渲染，或数据文件没拷 | 6/6 | 6/6 |
| just-do-it-yourself | jdiy：依赖在 vendor 的 zip 里，还要设环境变量 | 3/3 | 3/3 |
| encoding-first | enc：同时生成 Excel 用的 CSV、双击运行的 .bat、Node 读取的 JSON | 3/3 | 3/3 |

这几个场景里，DeepSeek 不装 skill 也会主动反编译 .pyc、读日志、检查产物、读安装脚本的源码，所以 skill 的增益测不出来。耗时方面，装 skill 时有三个场景明显更慢：evidence 平均 321 s 对 98 s（其中一次跑了 690 s）、evidence2 126 s 对 75 s、enc 100 s 对 75 s，多出来的时间主要花在更彻底的验证上，比如 screenshot-first 会让它真的启动无头浏览器去看页面，encoding-first 会让它逐个检查文件字节。其余场景两组相差在 20 秒以内。

## 局限

- **只测了一个智能体和一个模型。** 能力较弱的模型，在"两组都及格"的场景里可能会有差别；能力更强的模型，现在有差别的场景也可能没有差别。
- **样本小。** 每组 3 次（wait 6 次），0/3 和 3/3 这样的差距比较可信；5/6 和 6/6 之间的差别可能只是偶然。
- **场景是模拟的。** 比如 fast2 的"虚拟机"实际在本机磁盘上，装 skill 那组找到的更快路径是直接读磁盘，而真实的虚拟机里通常要走网络。
- **自动判分有误判。** 已人工核对并修正的有：frames 的一次"漏判倒退"（回答里写的是 "f6"，正则没匹配上）、wait 的一次"固定 sleep"（其实是 1.5 秒的短暂停顿，主体是条件轮询）、style 的"大阴影"（下拉浮层的正常投影）。
- **没有测 GUI 类场景**（background-friendly 等），因为对照组可能会截全屏、抢焦点，打扰正在用电脑的人。
