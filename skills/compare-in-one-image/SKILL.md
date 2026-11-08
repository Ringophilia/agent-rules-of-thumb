---
name: compare-in-one-image
description: "When you need to compare several images (before/after, frames over time, design or render variants, several windows, devices or breakpoints, baseline vs current), stitch them into ONE labelled grid and look once, instead of reading them one by one: the comparison is more accurate and costs about one image of tokens. Use whenever you are about to view two or more screenshots, renders or frames to spot a difference or a change. Ships a zero-dependency PowerShell script that also diffs a pair or a whole frame sequence (each frame vs the previous); ImageMagick, ffmpeg and PIL equivalents included."
compatibility: 原则通用；scripts/compose-shots.ps1 需要 Windows + PowerShell 5.1 或更高版本；其他平台用文中的 ImageMagick / ffmpeg / PIL 写法
---

# 多张图，拼成一张再看

要对比几张图时，智能体的习惯是一张一张打开看，靠"记忆"对照。这样做又慢又不准：看到第四张时，第一张的细节已经模糊了；两张图之间的细微差别，分开看几乎发现不了。

一句话：**要比较的图，拼成一张带标签的网格，一次看完；能先用数字判断的，先看数字。**

## 为什么

- **准**：模型在**同一张图里**对比几个区域，比在几张图之间来回对照准得多。位置对齐、颜色差异、某个元素有没有出现，放在一起一眼就能看出来。
- **省**：图片按面积计费，超过约 1568px（长边）或约 1.15MP 的图会被先缩小。所以拼好的一张图只花大约**一张**图的 token（约 1.5k），而 6 张单独的图要花 6 倍。
- **可追溯**：每格带标签（步骤名、时间、参数），结论可以直接指向"第 3 格"，用户也能看懂。

## 什么时候用

| 场景 | 图从哪来 |
| --- | --- |
| 操作前后：点了按钮、改了代码、改了配置之后变了什么 | 前后各截一张 |
| 过程变化：加载进度、动画、闪烁、一闪而过的弹窗 | 按固定间隔连拍几帧；视频用 ffmpeg 抽帧 |
| 多个版本：设计方案 A/B/C、渲染参数、亮色/暗色主题、不同字体 | 每个版本各出一张 |
| 多个尺寸或设备：响应式断点、手机/平板/桌面、不同 DPI | Playwright 按不同 viewport 截图；`adb exec-out screencap -p` |
| 视觉回归：基准图和当前图 | 测试产物里的 baseline 和 actual |
| 多步流程总览：登录 → 加载 → 主界面 | 每一步截一张 |
| 3D 渲染或图表：多个角度、多个参数的结果 | Blender 渲染、matplotlib 输出 |

**不要用**的情况：

- 只有一张图，或者只需要看其中一张。
- 要**读小字**：拼图会降低每格的分辨率。用单张原图、局部裁剪，或者直接读文字（UI Automation、DOM、日志）。
- 要**量坐标**（给点击、拖动用）：必须在单张原图上量，不要在缩小过的拼图上量。
- 能用文字或数据直接比较的（DOM 文本、JSON、日志、像素差的数字），先比文字和数字，不需要看图。

## 怎么拼

### Windows：`compose-shots.ps1`（零依赖）

脚本在本 skill 的 `scripts/` 下，只用 Windows 自带的 PowerShell 5.1 和 .NET Framework。多个参数值用 `||` 分隔（用 `powershell -File` 调用时数组会被压平）。

```powershell
$cs = "<skill目录>\scripts\compose-shots.ps1"

# 任意几张拼成网格，每格带标签
powershell -NoProfile -ExecutionPolicy Bypass -File $cs `
  -Inputs "a.png||b.png||c.png" -Labels "登录||加载||主界面" -Out "<scratchpad>\grid.png"

# 前后对比：输出 3 格（before / after / 只亮出变化区域），变化处画红框
powershell -NoProfile -ExecutionPolicy Bypass -File $cs `
  -Inputs "before.png||after.png" -Diff -Out "<scratchpad>\diff.png" -Title "点击保存之后"

# 序列（连拍、动画帧、步骤截图）：3 张以上加 -Diff，每帧都和前一帧比，变化处画红框
powershell -NoProfile -ExecutionPolicy Bypass -File $cs -Inputs "<dir>\frames\*.png" -Diff -Out "<scratchpad>\sheet.png"

# 通配符按文件名排序；-Columns 固定列数；-MaxEdge / -MaxPixels 调整输出大小
```

脚本输出一行 JSON：输出路径、尺寸、布局、每格缩放比例、估算 token。加了 `-Diff` 时还有：

- 两张图：`changedPercent`（变化像素占比）、`changedBoxes`（变化区域，after 图的**原始像素坐标**）
- 三张以上：`steps`，每一步（第 k 帧 → 第 k+1 帧）各有一组 `changedPercent` 和 `changedBoxes`；每格的标签上也写着"vs prev: x%"

**先看数字，再决定要不要看图**：0 个变化区域说明画面根本没变，不用打开图；变化区域落在哪里，也能先猜到是哪个控件变了。序列里某一步的变化占比突然变大、或者多出一个区域，往往就是出问题的那一帧。

**不要自己临时写像素比较脚本**。上面这个脚本已经覆盖两张对比和整段序列，临时写的脚本容易在像素格式（24/32 位）、坐标换算上出错，还要多花几轮调试。

### 其他平台和工具

| 需求 | 写法 |
| --- | --- |
| 拼网格（ImageMagick） | `magick montage -label before a.png -label after b.png -tile 2x -geometry 800x600+8+8 -pointsize 24 grid.png`（ImageMagick 6 用 `montage`） |
| 逐帧差异（ImageMagick） | 对相邻两帧循环执行下一行的 `compare`，先看每一步的数字 |
| 像素差（ImageMagick） | `magick compare -metric AE before.png after.png diff.png`，变化像素数打印在 stderr，diff.png 里变化处标红 |
| 视频抽帧拼成一张（ffmpeg） | `ffmpeg -i in.mp4 -vf "fps=2,scale=480:-1,tile=3x2" -frames:v 1 sheet.png`（每 0.5 秒一帧，6 格） |
| 帧上加时间戳（ffmpeg） | 在 `tile` 前加 `drawtext=text='%{pts\:hms}':x=8:y=8:fontsize=24:fontcolor=white:box=1:boxcolor=black`；Windows 上可能要加 `fontfile='C\:/Windows/Fonts/arial.ttf'` |
| Python（Pillow） | 见下 |

```python
from PIL import Image, ImageDraw
def grid(paths, labels, out, cols=3, tile=(640, 400)):
    rows = -(-len(paths) // cols)
    sheet = Image.new("RGB", (cols * tile[0], rows * (tile[1] + 28)), "white")
    for i, (p, lab) in enumerate(zip(paths, labels)):
        im = Image.open(p).convert("RGB"); im.thumbnail(tile)
        x, y = (i % cols) * tile[0], (i // cols) * (tile[1] + 28)
        ImageDraw.Draw(sheet).text((x + 6, y + 6), lab, fill="black")
        sheet.paste(im, (x, y + 28))
    sheet.save(out)
```

输出图的长边保持在 1568px 以内、总像素在约 1.15MP 以内，超了也会被缩小，只是白白浪费分辨率。

## 使用要点

- **先想清楚要回答什么问题，再拼**，比如"这 6 帧里，弹窗在哪一帧出现"、"三个方案里哪个的标题最清楚"。问题决定选哪几张、按什么顺序排。
- **每格都要有含义明确的标签**：步骤名、时间（t+300ms）、参数值（roughness=0.4）。没有标签，模型分不清哪格是哪格，结论也没法指回去。
- **一张图最好不超过 6 格，9 格是上限**。格子越多，每格分辨率越低。要比更多张，先拼一张粗看，再把可疑的几张单独拼一张细看。
- **要对比的图尺寸和取景要一致**：同一个窗口、同一个 viewport、同一个相机角度。不一致时，差异大多来自取景，不是内容。
- **像素差会把噪声也算进去**：光标闪烁、时钟、动画、抗锯齿都会被算成变化。看变化区域的位置和大小来判断，不要只看数量。
- **连拍是为了观察过程，不是为了等待完成**。等某件事完成，用条件判断（见 no-blind-wait），完成后再截一张。
- 拼图放在 scratchpad 或临时目录，不要放进用户的项目。

## 检查清单

- [ ] 我要回答的问题是什么？选的图和顺序能回答它吗？
- [ ] 能不能先用文字、数据或像素差的数字回答，根本不用看图？
- [ ] 每格都有标签吗？尺寸和取景一致吗？
- [ ] 格数在 6 格左右，输出在 1568px / 1.15MP 以内吗？
- [ ] 要读小字或量坐标时，我回到单张原图了吗？

## 相关 skill

- **screenshot-first**：决定什么时候必须拿截图作为一手证据；需要前后对比来证明"已修好"时，用本 skill 拼成一张。
- **no-blind-wait**：等待完成用条件判断，不要用连拍代替。
