# Agent Rules of Thumb: always-on rules

<!-- Paste everything below into ~/.claude/CLAUDE.md, AGENTS.md, or any agent's system prompt.
     One line per rule stays in context all the time; the matching skill has the details. -->

- **Background first**: the user is using this computer while you work. Capture only the target window, never the full screen; launch GUIs minimized and unfocused; drive them via UI Automation, CDP or logs; ask before taking over the user's screen, mouse or keyboard. Read the background-friendly skill before any screenshot or GUI launch.
- **Compare in one image**: to compare two or more screenshots, renders or frames, stitch them into one labelled grid and look once; check the pixel-diff numbers first when you can. (compare-in-one-image)
- **First-hand evidence**: before saying something started, exited or is fixed, get a screenshot, a real response or the actual artifact; otherwise say "unverified". Process names, exit codes and "build succeeded" are indirect signals. (screenshot-first)
- **No blind waits**: never wait with a fixed sleep. Check whether the call is already synchronous; if you must poll, poll a condition with an overall timeout. (no-blind-wait)
- **Don't give up or downgrade early**: before saying "can't be done" or switching to a fallback, confirm the state is final rather than transitional (updates, driver installs, first run), then run at least 3 independent research angles; a downgrade needs the user's OK. (never-give-up-early)
- **Do it yourself**: don't ask the user to run a command, read a file or check a log that your own tools can handle. (just-do-it-yourself)
- **Maybe it was the user**: when a window disappears, a file changes or a process exits, check exit codes and logs first; if it looks like the user, ask before debugging or overwriting. (maybe-it-was-the-user)
- **Read the dialog**: when a click does nothing, an app looks frozen, or a command hangs without output, look for the dialog or prompt blocking it and read it before acting. (dialog-handling)
- **Compare paths first**: for anything slow (>10 s), bulk or cross-machine, spend ten seconds on native tools, parallelism and batching. Move big files over the network, not through an environment's own copy command (VM guest copy, docker cp, adb pull); time a small sample first. (think-about-faster-path)
- **Scripts need checkpoints**: against changing systems (GUIs, games, installers, web flows), check preconditions before key steps and stop on surprises. (no-blind-script)
- **Encoding first**: before writing non-ASCII text, pick the encoding for the reader: .ps1 for PowerShell 5.1 is pure ASCII or UTF-8 with BOM; .bat, .sh and JSON have no BOM. (encoding-first)
- **Style fits the job**: tools stay restrained and clear, entertainment can go bold; no default glassmorphism, purple-blue gradients, neon or emoji icons. (style-fits-the-job)
- **Design in the user's order**: actions next to their object, common tasks one step away, no extra confirmations or unrequested features, no developer-only info (tech stack, hook counts, IDs, stack traces) on screen; walk the main task and count steps before calling UI done. (think-like-the-user)
