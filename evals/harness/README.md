# 测试工具

[results.md](../results.md) 里的数据就是用这几个脚本跑出来的。

| 文件 | 作用 |
| --- | --- |
| `make_round2.py` | 生成第二轮的 11 个陷阱场景：`python make_round2.py <输出目录> <每组次数> [场景,场景]` |
| `make_round3.py` | 生成第三轮去掉提示后的 7 个场景，用法同上 |
| `score.py` | 读取每个场景目录下的 `out.jsonl`，按场景的及格标准自动判分：`python score.py <场景根目录> <输出目录>`，输出 `summary.md` 和 `transcripts.txt` |

每个场景目录名为 `<场景>-<with|without>-<序号>`，里面有 `task.txt`（原样发给智能体的任务）和场景需要的文件。

## 怎么跑

对每个目录，在该目录下用智能体的无界面模式执行 `task.txt`，`with` 组装好 skill，`without` 组关掉 skill，把事件流存成 `out.jsonl`。例如：

- **DeepSeek Harness**：`dsh --profile headless --json - < task.txt > out.jsonl`；`without` 组加一个 `--patch`，把 `skill`、`skill-filesystem`、`tool-skill` 三个插件设为 `disabled: true`。
- **Claude Code**：`claude -p --output-format stream-json --verbose < task.txt > out.jsonl`；`without` 组加 `--disable-slash-commands`。

`score.py` 按 dsh 的事件格式（`tool_call` / `tool_result` / `final`）解析；换成其他智能体时，需要先把事件转换成这个格式，或者改一下 `load()`。

## 注意

- `fast` / `fast2` 会生成 400 MB 的稀疏文件，跑完记得删除；`wait`、`fast*` 会在本机起 HTTP 服务，不要并行跑这几个场景，端口可能冲突。
- 自动判分只是第一道筛选：判为 FAIL 或 `?` 的，一定要打开 `transcripts.txt` 人工核对，正则判断会有误判。
- 所有场景都在本地后台运行，不打开窗口。
