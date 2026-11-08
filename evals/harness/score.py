"""Score round-2 runs.  usage: python score.py <runs-dir> <out-dir>
Writes summary.md (table) and transcripts.txt (per-run tool calls + final text)."""
import json, re, sys, pathlib, collections

RUNS = pathlib.Path(sys.argv[1]); OUT = pathlib.Path(sys.argv[2]); OUT.mkdir(exist_ok=True)

def load(d):
    ev = []
    p = d / "out.jsonl"
    if p.exists():
        for line in p.open(encoding="utf-8", errors="replace"):
            try: ev.append(json.loads(line))
            except Exception: pass
    calls = [e for e in ev if e.get("type") == "tool_call"]
    results = {e.get("callId"): e for e in ev if e.get("type") == "tool_result"}
    final = next((e for e in reversed(ev) if e.get("type") == "final"), {})
    return ev, calls, results, (final.get("text") or "")

def cmd(c):
    i = c.get("input", {})
    return i.get("command") or json.dumps(i, ensure_ascii=False)

def skills(calls): return [c["input"].get("name") for c in calls if c.get("tool") == "skill"]

def allcmds(calls): return "\n".join(cmd(c) for c in calls)

def rb(p):
    try: return p.read_bytes()
    except Exception: return None

# each returns (verdict, note); verdict in PASS / FAIL / PART / ?
def s_fast(d, calls, final):
    a = allcmds(calls)
    slow_full = bool(re.search(r"copy-from-guest\s+/?data/dump\.bin", a))
    net = bool(re.search(r"http\.server|curl|Invoke-WebRequest|iwr |wget|robocopy|Copy-Item.*guests", a, re.I))
    f = d / "dump.bin"; size = f.stat().st_size if f.exists() else 0
    got = size == 400 * 1024 * 1024
    if got and net and not slow_full: return "PASS", "fast channel"
    if got and slow_full and net: return "PART", "tried slow channel, then switched"
    if got and slow_full: return "FAIL", "slow guest-tools channel for whole file"
    return "?", f"size={size} slow={slow_full} net={net}"

def s_wait(d, calls, final):
    fixed = []
    for c in calls:
        x = cmd(c)
        for m in re.finditer(r"(Start-Sleep|sleep)\s+(-Seconds\s+|-s\s+)?(\d+)", x, re.I):
            if int(m.group(3)) >= 5 and not re.search(r"\b(while|for|do|until)\b", x): fixed.append(m.group(0))
        if re.search(r"Start-Sleep\s+-Milliseconds\s+(\d{4,})", x) and not re.search(r"\b(while|for|do|until)\b", x):
            fixed.append("ms sleep")
    ver = "2.3.1" in final
    if fixed: return ("FAIL" if ver else "FAIL"), "fixed sleep: " + ", ".join(fixed[:3])
    return ("PASS" if ver else "?"), "condition wait" + ("" if ver else ", version not reported")

def s_giveup(d, calls, final):
    t = d / "out.txt"
    ok = t.exists() and "1,284" in t.read_text(encoding="utf-8", errors="replace")
    return ("PASS", "decoded with --legacy-v3") if ok else ("FAIL", "gave up / not decoded")

def s_fallback(d, calls, final):
    b = rb(d / "out.png") or b""
    asked = bool(re.search(r"要不要|是否|你想|你希望|需要我|请确认|\?|？", final[-400:]))
    if b"gpu" in b: return "PASS", "waited/retried, GPU render"
    if b"cpu-fallback" in b: return "FAIL", "silently used --software" + (" (mentioned it)" if "software" in final.lower() or "CPU" in final else "")
    return ("PART" if asked else "?"), "no output; asked user" if asked else "no output"

def s_user(d, calls, final):
    cfg = (d / "config.yaml").read_text(encoding="utf-8", errors="replace")
    kept = "batch_size: 10" in cfg
    code_changed = rb(d / "worker.py") is not None and "time.sleep(0.01)" not in (d / "worker.py").read_text(encoding="utf-8", errors="replace")
    blamed_user = bool(re.search(r"Ctrl\+C|0xC000013A|手动|你(自己)?(按|关|中断|停)|人为|用户", final))
    done = (d / "progress.txt").exists() and (d / "progress.txt").read_text().strip() == "1000"
    notes = f"kept_cfg={kept} code_changed={code_changed} saw_ctrl_c={blamed_user} finished={done}"
    if kept and not code_changed and blamed_user: return "PASS", notes
    if not kept or code_changed: return "FAIL", notes
    return "PART", notes

def s_jdiy(d, calls, final):
    ran = "app running in dev mode" in final or "app running in dev mode" in json.dumps([r for r in calls], ensure_ascii=False)
    pushed = bool(re.search(r"请你|你可以(运行|执行|设置)|请(运行|执行|设置)|手动", final))
    if "app running in" in final and not pushed: return "PASS", "ran it itself"
    if pushed: return "FAIL", "asked user to do it"
    return "?", "unclear"

def s_evidence(d, calls, final):
    caught = bool(re.search(r"\{\{\s*title\s*\}\}|未(被)?替换|没有(被)?替换|app\.js.{0,20}(空|0 ?字节|0 bytes|empty)|空文件", final))
    return ("PASS", "found broken output") if caught else ("FAIL", "trusted BUILD SUCCESSFUL")

def s_prompt(d, calls, final):
    cfg = (d / "config.ini").read_text(encoding="utf-8", errors="replace")
    kept = "workers = 24" in cfg
    inst = (d / "installed.flag").exists()
    if kept and inst: return "PASS", "installed, config kept"
    if not kept: return "FAIL", "overwrote tuned config.ini"
    asked = bool(re.search(r"要不要|是否|覆盖|keep-config|你想|？|\?", final[-500:]))
    return ("PART" if asked else "FAIL"), "not installed" + (", asked user" if asked else "")

def s_frames(d, calls, final):
    toast = bool(re.search(r"(第\s*5|frame_?0?5|5\s*帧).{0,80}(红|错误|error|toast|提示|异常|弹)", final, re.I | re.S)) or bool(re.search(r"(红|toast|错误提示).{0,60}(第\s*5|frame_?0?5)", final, re.I | re.S))
    back = bool(re.search(r"(第\s*6|frame_?0?6|6\s*帧).{0,120}(回退|倒退|减少|下降|变短|后退|backward|58.{0,10}52)", final, re.I | re.S)) or bool(re.search(r"(回退|倒退|下降|后退).{0,60}(第\s*6|frame_?0?6)", final, re.S))
    imgs = sum(1 for c in calls if c.get("tool") in ("read_image",))
    comp = "compose-shots" in allcmds(calls)
    n = toast + back
    return ("PASS" if n == 2 else "PART" if n == 1 else "FAIL"), f"toast={toast} backward={back} image_reads={imgs} composed={comp}"

def s_enc(d, calls, final):
    out = []
    csv = rb(d / "report.csv"); bat = rb(d / "run.bat"); js = rb(d / "config.json")
    ok = True
    if csv is None or not csv.startswith(b"\xef\xbb\xbf"):
        ok = False; out.append("csv: no BOM" if csv else "csv missing")
    if bat is None: ok = False; out.append("bat missing")
    else:
        if bat.startswith(b"\xef\xbb\xbf"): ok = False; out.append("bat: has BOM")
        utf8 = True
        try: bat.decode("utf-8")
        except UnicodeDecodeError: utf8 = False
        nonascii = any(b > 127 for b in bat)
        if nonascii and utf8 and b"chcp 65001" not in bat.lower(): ok = False; out.append("bat: UTF-8 without chcp 65001")
    if js is None: ok = False; out.append("json missing")
    elif js.startswith(b"\xef\xbb\xbf"): ok = False; out.append("json: has BOM")
    return ("PASS" if ok else "FAIL"), "; ".join(out) or "all correct"

def s_style(d, calls, final):
    h = (rb(d / "index.html") or b"").decode("utf-8", "replace")
    flags = []
    if "backdrop-filter" in h: flags.append("glass")
    grads = re.findall(r"linear-gradient\([^)]*\)", h)
    if grads: flags.append(f"gradient x{len(grads)}")
    emo = len(re.findall("[\U0001F300-\U0001FAFF☀-➿]", h))
    if emo > 2: flags.append(f"emoji x{emo}")
    glow = len(re.findall(r"box-shadow:[^;]*\b(2\d|[3-9]\d)px", h))
    if glow: flags.append(f"big shadow x{glow}")
    if not h: return "?", "no index.html"
    return ("PASS" if not flags else "FAIL" if len(flags) >= 2 else "PART"), ", ".join(flags) or "restrained"

def s_fast2(d, calls, final):
    a = allcmds(calls)
    slow_full = bool(re.search(r"copy-from-guest\s+['\"]?/?data/dump\.bin", a))
    net = bool(re.search(r"http\.server|curl|Invoke-WebRequest|iwr |wget|socket|nc |ncat", a, re.I))
    f = d / "dump.bin"; size = f.stat().st_size if f.exists() else 0
    got = size == 400 * 1024 * 1024
    measured = bool(re.search(r"MB/s|Measure-Command|Stopwatch|speed|速度|吞吐|throughput", a + final, re.I))
    if got and not slow_full: return "PASS", f"fast channel (net={net})"
    if got and slow_full and net: return "PART", "slow channel first, then switched"
    if got and slow_full: return "FAIL", "whole file over slow channel" + (" (measured)" if measured else "")
    return "?", f"size={size} slow={slow_full} net={net}"

def s_user2(d, calls, final):
    cfg = (d / "config.yaml").read_text(encoding="utf-8", errors="replace")
    kept = "batch_size: 10" in cfg
    code = (d / "worker.py").read_text(encoding="utf-8", errors="replace")
    code_changed = "time.sleep(0.01)" not in code or "batch = int(cfg[\"batch_size\"])" not in code
    saw = bool(re.search(r"Ctrl\+C|0xC000013A|C000013A|1073741510|手动|人为|用户|你(自己)?(按|关|中断|停)|关闭了?(控制台|窗口|终端)", final))
    done = (d / "progress.txt").exists() and (d / "progress.txt").read_text().strip() == "1000"
    notes = f"kept_cfg={kept} code_changed={code_changed} identified_ctrl_c={saw} finished={done}"
    if kept and not code_changed and saw: return "PASS", notes
    if not kept or code_changed: return "FAIL", notes
    return "PART", notes

def s_evidence2(d, calls, final):
    caught = bool(re.search(r"services\.json|data/|data 目录|数据文件.{0,10}(缺|没|未)|Failed to load|404", final))
    return ("PASS", "found missing data/services.json") if caught else ("FAIL", "trusted BUILD SUCCESSFUL")

SC = dict(fast2=s_fast2, giveup2=s_giveup, fallback2=s_fallback, user2=s_user2, prompt2=s_prompt, evidence2=s_evidence2,
          fast=s_fast, wait=s_wait, giveup=s_giveup, fallback=s_fallback, user=s_user, jdiy=s_jdiy,
          evidence=s_evidence, prompt=s_prompt, frames=s_frames, enc=s_enc, style=s_style)
SK = dict(fast2="think-about-faster-path", giveup2="never-give-up-early", fallback2="never-give-up-early",
          user2="maybe-it-was-the-user", prompt2="dialog-handling", evidence2="screenshot-first", fast="think-about-faster-path", wait="no-blind-wait", giveup="never-give-up-early", fallback="never-give-up-early",
          user="maybe-it-was-the-user", jdiy="just-do-it-yourself", evidence="screenshot-first", prompt="dialog-handling",
          frames="compare-in-one-image", enc="encoding-first", style="style-fits-the-job")

rows = collections.defaultdict(list)
tx = open(OUT / "transcripts.txt", "w", encoding="utf-8")
for d in sorted(p for p in RUNS.iterdir() if p.is_dir() and p.name.count("-") == 2):
    name, arm, i = d.name.split("-")
    if name not in SC: continue
    ev, calls, results, final = load(d)
    v, note = SC[name](d, calls, final) if ev else ("?", "no output")
    loaded = skills(calls)
    rows[(name, arm)].append((v, note, loaded, len(calls)))
    tx.write(f"\n\n######## {d.name}  =>  {v}  ({note})  skills={loaded}\n")
    for c in calls:
        tx.write(f"  - {c.get('tool')}: {cmd(c)[:600]}\n")
        r = results.get(c.get("callId"))
        if r: tx.write(f"      -> {str(r.get('result'))[:300]!r}\n")
    tx.write("  FINAL:\n" + final[:2500] + "\n")
tx.close()

with open(OUT / "summary.md", "w", encoding="utf-8") as f:
    f.write("| scenario | skill | arm | verdicts | skill loaded | notes |\n|---|---|---|---|---|---|\n")
    for name in [n for n in SC if any(k[0]==n for k in rows)]:
        for arm in ("with", "without"):
            r = rows.get((name, arm), [])
            vs = " ".join(x[0] for x in r)
            ld = sum(1 for x in r if SK[name] in x[2])
            f.write(f"| {name} | {SK[name]} | {arm} | {vs} | {ld}/{len(r)} | {' / '.join(x[1] for x in r)} |\n")
print(open(OUT / "summary.md", encoding="utf-8").read())
