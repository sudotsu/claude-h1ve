# Knowledge Base

Structured reference of discovered facts, gotchas, and system behaviors that are worth knowing across sessions and machines. Edited in-place — entries are updated or replaced when superseded, never just appended. High signal-to-noise: only add things that would bite you again or save real time.

**CRITICAL RULE FOR ALL AGENTS:** You are strictly forbidden from writing conversational paragraphs in this file. Every new or updated entry MUST follow this exact format:

### [Specific Issue or Capability]
* **Symptom/Context:** (One concise sentence describing what broke or what the objective was)
* **Root Cause/Mechanic:** (Why it failed, or how the underlying system actually works)
* **Execution/Fix:** (The exact command, pathing, or code required to solve it)
* **Recurrence risk:** (Why this would bite you again — what makes it non-obvious to look up or diagnose without this entry)

---

## Windows / WSL

### Claude Code hook pathing trap
* **Symptom/Context:** Claude Code hooks silently fail to run on Windows machines with both Git Bash and WSL installed.
* **Root Cause/Mechanic:** Claude Code's hook runner resolves `/bin/bash` to the WSL shim (`C:\Windows\System32\bash.exe`), which cannot resolve Git Bash paths (`/c/Users/...`) or Windows-native paths (`C:\Users\...`).
* **Execution/Fix:** Route hooks through PowerShell to explicitly invoke Git Bash: `powershell.exe -NoProfile -Command "& 'C:/Program Files/Git/bin/bash.exe' 'C:/path/to/script.sh'"`
* **Recurrence risk:** Silent failure — no error is shown, the session runs normally, but sync and pull never fire. Diagnosed only by noticing h1ve never updates across sessions.

### $HOME mismatch between Node.js and bash on Windows
* **Symptom/Context:** Hook scripts using `$HOME` fail silently — paths resolve to a directory that doesn't exist.
* **Root Cause/Mechanic:** Node.js sets `HOME=C:\Users\<user>`; when it spawns the WSL shim bash, bash interprets this as `/home/<user>/` (Linux convention), not `/c/Users/<user>/` (Git Bash convention).
* **Execution/Fix:** Use absolute paths or the PowerShell wrapper. Never rely on `$HOME` in Windows hook commands.
* **Recurrence risk:** Path resolves silently to the wrong directory — no error, scripts simply don't run or affect the wrong location.

### Three bash binaries on Windows+WSL
* **Symptom/Context:** A bash command resolves to the wrong binary depending on how it's invoked.
* **Root Cause/Mechanic:** Three binaries exist in PATH priority order: `C:\Windows\System32\bash.exe` (WSL shim), `C:\Users\<user>\AppData\Local\Microsoft\WindowsApps\bash.exe` (WSL app alias), `C:\Program Files\Git\bin\bash.exe` (Git Bash). Node.js finds the WSL shim first.
* **Execution/Fix:** Always invoke Git Bash by full path: `C:/Program Files/Git/bin/bash.exe`
* **Recurrence risk:** Invoking `bash` by short name silently routes to the WSL shim — the error manifests in script behavior (wrong paths, missing tools), not at invocation, so the binary mismatch isn't obvious.

### Do not copy shared/settings.json on Windows machines
* **Symptom/Context:** Hooks silently break after copying the shared settings template to a Windows machine.
* **Root Cause/Mechanic:** `shared/settings.json` uses `$HOME` which the WSL shim resolves incorrectly. Windows machines need the PowerShell→Git Bash wrapper instead.
* **Execution/Fix:** Manually create `~/.claude/settings.json` with the PowerShell wrapper — see `templates/new-machine-setup.md`.
* **Recurrence risk:** Hooks stop running silently after machine setup — no warning, no error, Claude sessions just run without sync or pull.

---

## Git

### Push rejected at session start — prior session's SessionEnd sync racing the startup pull
* **Symptom/Context:** Push fails with "remote contains work you do not have locally" even though no other machine has pushed anything.
* **Root Cause/Mechanic:** Most likely cause (not fully confirmed, but consistent with observed timestamps): the previous session's `SessionEnd` hook ran `sync.sh` and pushed commits at the same moment this session's `SessionStart` hook ran `session-start.sh` and pulled. If the pull lands on GitHub's side before the push completes, the pull misses those commits. The session then builds local commits on a stale base, and the push is rejected later. The commits on the remote are from this same machine's prior session — not a foreign push.
* **Execution/Fix:** **User:** no action needed — nothing is wrong, no data is lost. **Agent:** do not panic or assume external interference. Run `git fetch origin` first to confirm the remote-only commits are from `localhost` (this phone). Then `git merge origin/master --no-edit` (not rebase — rebase requires a clean working tree and is harder to recover). Resolve any conflicts (likely only in `memory/kb.md` or `machines/s25-termux/machine.md`), then push. If merge is also blocked by unstaged changes, `git stash`, merge, push, `git stash drop`.
* **Recurrence risk:** Looks like external interference from another machine — the instinct is to investigate who pushed, or worse, force-push to fix it. Both responses are wrong and the latter destroys work.

---

## Termux / Android

### Claude Code auto-update breaks on Termux — version pinned at 2.1.112
* **Symptom/Context:** `npm install -g @anthropic-ai/claude-code` either fails or installs a version that breaks Claude Code on Termux (s25-termux).
* **Root Cause/Mechanic:** Newer versions have incompatibilities with Termux's Android environment. Last known-good version that installs and runs correctly is 2.1.112.
* **Execution/Fix:** After installing the working version, freeze it against auto-update with: `chmod -R a-w $(npm config get prefix)/lib/node_modules/@anthropic-ai/claude-code`. This strips write permissions so npm cannot overwrite it. To upgrade intentionally: `chmod -R a+w` the path first, then install, then re-lock.
* **Recurrence risk:** npm auto-update is silent — you don't know it happened until Claude Code stops working. The version lock via chmod is non-obvious and not documented anywhere standard.

### Claude Code Bash tool crashes on colon-containing filenames in git output
* **Symptom/Context:** Any git command whose output includes a filename with a colon (e.g., `h1ve_system_architecture.html:Zone.Identifier`) causes the Bash tool to throw `Cannot read properties of undefined (reading 'replace')` and kills the tool call — the command may or may not have actually executed.
* **Root Cause/Mechanic:** Claude Code's output parser tries to string-replace on a value that becomes undefined when parsing colon-containing paths. Bug in `cli.js` (14MB minified bundle — not locally patchable). Occurs on Termux 2.1.112; upstream status unknown.
* **Execution/Fix:** Route affected git commands through Python subprocess to bypass the tool: `python3 -c "import subprocess; r=subprocess.run([...], cwd='...', capture_output=True, text=True); open('/tmp/out.txt','w').write(r.stdout+r.stderr)" && cat /tmp/out.txt`. Permanent prevention: `*:Zone.Identifier` is now in h1ve `.gitignore` so Windows machines cannot re-introduce these filenames.
* **Recurrence risk:** The crash message (`Cannot read properties of undefined`) gives no indication that a colon in a filename is the cause — it looks like a random parser bug with no actionable information.

### Claude Code requires CLAUDE_CODE_TMPDIR on Termux
* **Symptom/Context:** Claude Code fails to start on Termux — `/tmp` is inaccessible (Permission denied).
* **Root Cause/Mechanic:** Android restricts `/tmp`. Claude Code does NOT automatically use `$TMPDIR`. Requires explicit env var pointing to Termux's writable tmp.
* **Execution/Fix:** `export CLAUDE_CODE_TMPDIR=$PREFIX/tmp` — added to `~/.bashrc` on s25-termux so it's automatic on every shell start.
* **Recurrence risk:** The error says `/tmp: Permission denied` — nothing in the message mentions `CLAUDE_CODE_TMPDIR` or that `$TMPDIR` being set is insufficient.

### No /bin/bash on Termux
* **Symptom/Context:** Scripts or hooks using `/bin/bash` fail silently on Termux.
* **Root Cause/Mechanic:** Termux's filesystem root is `/data/data/com.termux/files/`. Bash lives at `$PREFIX/bin/bash`, not `/bin/bash`. No symlink exists at `/bin/bash`.
* **Execution/Fix:** Use `bash` (relies on PATH) or `$PREFIX/bin/bash` for explicit invocation. The shared `settings.json` hook format (`bash -c '...'`) works because bash is in PATH.
* **Recurrence risk:** Scripts fail with "command not found" or silently — the error doesn't indicate that bash exists elsewhere at a non-standard path.

### Bun binary unusable on Termux (glibc mismatch)
* **Symptom/Context:** Bun installed via `curl -fsSL https://bun.sh/install | bash` on Termux installs but immediately fails with `cannot execute: required file not found`.
* **Root Cause/Mechanic:** The official Bun install script downloads a glibc-linked aarch64 ELF binary expecting the dynamic linker at `/lib/ld-linux-aarch64.so.1`. Termux uses Android's Bionic libc and has no standard ELF linker — it only exists inside proot-distro rootfs. `patchelf` can't fix it without all dependent glibc shared libraries also present.
* **Execution/Fix:** No clean fix in bare Termux. Options: (1) run bun inside proot-distro Ubuntu via wrapper script, (2) wait for a Termux-native bun package in pkg repos, (3) avoid tools that hard-require bun on s25-termux.
* **Recurrence risk:** Install succeeds with no errors — the binary only fails at runtime with a linker error that doesn't explain the glibc/Bionic mismatch or point toward a fix.

### Next.js 16 build fails on Termux (Turbopack WASM limitation)
* **Symptom/Context:** `npm run build` in a Next.js 16 project on Termux fails with `turbo.createProject is not supported by the wasm bindings`.
* **Root Cause/Mechanic:** Next.js 16 defaults to Turbopack for production builds. On Termux, native SWC bindings aren't available so it falls back to WASM bindings, which don't implement `createProject`. There is no `--no-turbopack` flag for `next build` in this version.
* **Execution/Fix:** Use `npx tsc --noEmit` for type checking locally. Push to GitHub and let Vercel build — Vercel has native bindings and builds correctly. Do not attempt to build Next.js 16 locally on Termux.
* **Recurrence risk:** The error message doesn't explain why WASM bindings are being used or that Vercel is the correct build environment — the instinct is to debug the Turbopack config, which is a dead end.

---

## Claude Code

### CLAUDE.md directory tree walking
* **Symptom/Context:** Project-level Claude instructions aren't being read even though the file exists in the repo.
* **Root Cause/Mechanic:** Claude Code walks up the directory tree from the launch directory, reading every `CLAUDE.md` found. `~/.claude/CLAUDE.md` is always read; project-level files are only read if Claude Code is launched from within or below that directory.
* **Execution/Fix:** Symlink `projects/<name>/CLAUDE.md` into the project's working directory, or always launch Claude Code from the project root.
* **Recurrence risk:** Instructions silently don't load — no error, no indication that the launch directory is wrong. Looks like the file isn't being read when it's actually just not being found.

### Desktop MSi: native Windows Claude Code instance is NOT h1ve-connected
* **Symptom/Context:** Claude Code launched from native Windows (PowerShell/Windows terminal, not WSL) on Desktop MSi doesn't run h1ve hooks or read h1ve CLAUDE.md.
* **Root Cause/Mechanic:** h1ve is configured for WSL Ubuntu (`/home/sudotsu/.claude/` symlinked to `machines/desktop-gaming/CLAUDE.md`). Native Windows Claude Code uses `C:\Users\MSi\.claude\` — a separate, unlinked config. Hooks, sync, and session protocol are all absent.
* **Execution/Fix:** Always launch Claude Code from WSL on Desktop MSi. Native Windows instance is effectively unconfigured — treat it as a blank slate with no h1ve context.
* **Recurrence risk:** Sessions appear to work normally — no error, no warning — but none of the h1ve context, memory, hooks, or sync applies. Easy to run a full session thinking h1ve is active when it isn't.

### SessionStart hook fires on --resume
* **Symptom/Context:** Expected session-start pull to be skipped on `claude --resume`, but it fires.
* **Root Cause/Mechanic:** `SessionStart` is wired with matcher `startup|resume|clear`. The `resume` subtype matches explicitly, so `session-start.sh` runs and pulls h1ve on resume just as it does on a fresh session start.
* **Execution/Fix:** Intentional — resumed sessions get a fresh pull. No action needed.
* **Recurrence risk:** Counterintuitive — "resume" implies continuing existing state, not triggering initialization. The pull on resume can surface merge conflicts or sync issues mid-task if the previous session left uncommitted state.

---

## Networking

### DNS-over-TLS breaks on captive portals (Acer Mint)
* **Symptom/Context:** Cannot authenticate to captive portals (hotel/airport Wi-Fi) on Acer Mint even though internet works on normal networks.
* **Root Cause/Mechanic:** Cloudflare DoT via systemd-resolved intercepts and encrypts DNS before the captive portal can redirect queries for authentication.
* **Execution/Fix:** `~/Desktop/Toggle DoT.sh` — disables DoT temporarily, authenticate to portal, re-enable after.
* **Recurrence risk:** The network shows as connected and DNS appears to work on known networks — the failure only manifests at captive portals with no indication that DNS encryption is the cause.

### "Connected but nothing loads" on Linux Mint
* **Symptom/Context:** Network shows connected but all web requests fail or time out.
* **Root Cause/Mechanic:** Usually DNS resolution failure, not connectivity — confirmed by `ping 8.8.8.8` succeeding while domain pings fail. Common causes: stale DNS cache, systemd-resolved crash, or captive portal blocking DoT.
* **Execution/Fix:** `sudo resolvectl flush-caches && sudo systemctl restart systemd-resolved`. On captive portal: toggle DoT off first. Nuclear option: `echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf`
* **Recurrence risk:** The OS reports full connectivity — the distinction between a routing failure and a DNS failure isn't surfaced anywhere, so the instinct is to reboot or check the router rather than flush DNS.

---

## Hardware

### Flex memory mode (mismatched SODIMMs)
* **Symptom/Context:** Considering installing mismatched RAM sticks (e.g., 4GB + 8GB) and unsure of the performance impact vs a matched pair.
* **Root Cause/Mechanic:** Intel 11th/12th gen flex mode runs the matched portion (4+4GB) in dual-channel and the remainder (4GB) in single-channel. Result: 12GB total, partial dual-channel, ~10-20% memory bandwidth reduction vs a matched pair — negligible in real-world dev scenarios vs the alternative of swapping to disk.
* **Execution/Fix:** Install the larger stick. Not swapping to disk beats dual-channel bandwidth in every practical scenario.
* **Recurrence risk:** Hardware decision with permanent consequences — if you don't know about flex mode you might reject the upgrade unnecessarily or expect worse performance than you'll actually see.


