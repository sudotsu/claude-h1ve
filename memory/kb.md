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

### Stale "PREVIOUS SYNC FAILED" banner + machine stranded on an agent branch
* **Symptom/Context:** `session-start.sh` prints `=== H1VE: PREVIOUS SYNC FAILED ===` with a weeks-old timestamp and a merge-conflict message, but `git status` shows a clean tree, `git stash list` is empty, and there are no conflicted files. (Observed 2026-08-07 on desktop-gaming: banner dated 2026-07-26.)
* **Root Cause/Mechanic:** Two independent problems that present as one. (1) `sync.sh` writes `FAILED <ts>` to `scratch/last-sync-status` but nothing clears it when a human resolves the conflict by hand — the banner then cries wolf indefinitely. (2) The real breakage: the machine was left checked out on a feature branch (`agent/animate-h1ve-readme`) and never returned to `master`. `sync.sh` operates on whatever branch is checked out, so it kept syncing the agent branch while `master` fell 6 commits behind. **Note the default branch is `master`, not `main`** — `origin/main` does not exist and commands referencing it fail with `ambiguous argument`.
* **Execution/Fix:** Diagnose in this order: `git status` (clean? then the banner is stale, ignore it), `git branch -vv` (on master? behind?). Before switching, confirm nothing is lost: `git log --oneline origin/master..HEAD` — empty output means the branch is fully merged and it's safe. Then `git checkout master && git pull`, and clear the stale flag: `echo "OK $(date +'%Y-%m-%d %H:%M:%S')" > scratch/last-sync-status`.
* **Recurrence risk:** The banner's message actively misdirects — it names a merge conflict that no longer exists, so the obvious move is hunting for conflicts and concluding it's fine when the actual problem (wrong branch, silently not syncing) is invisible unless you check `git branch -vv`. Any agent-branch workflow can strand a machine this way.

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
* **Root Cause/Mechanic:** Next.js 16 defaults to Turbopack for production builds. On Termux, native SWC bindings aren't available so it falls back to WASM bindings, which don't implement `createProject`.
* **Execution/Fix:** Next.js 16.3 **does** accept `next build --webpack` (supersedes the earlier note here that no opt-out flag existed — verify it works on Termux before relying on it, as the SWC binding problem may persist independently of the bundler). Otherwise: use `npx tsc --noEmit` for type checking locally, push to GitHub and let Vercel build — Vercel has native bindings and builds correctly.
* **Recurrence risk:** The error message doesn't explain why WASM bindings are being used or that Vercel is the correct build environment — the instinct is to debug the Turbopack config, which is a dead end.

### Next.js 16 + Tailwind v4 build fails on WSL2 (Turbopack PostCSS worker pool)
* **Symptom/Context:** `next build` dies at `Execution of PostCssTransformedAsset::process failed` → `creating new process` → `node process exited before we could connect to it with exit status: 0`. Empty process output. Reproduces on a completely untouched `create-next-app` scaffold, so it is never project code.
* **Root Cause/Mechanic:** Turbopack processes `postcss.config.mjs` in a **Node.js worker pool** (documented at `node_modules/next/dist/docs/01-app/03-api-reference/08-turbopack.md`, "PostCSS" row). On desktop-gaming's WSL2 that worker exits status 0 before Turbopack connects, so every Tailwind v4 build fails. Not caused by the fnm multishell node path (`/mnt/wslg/runtime-dir/...`) — tested by running the build with the real `~/.local/share/fnm/...` binary and it fails identically. Adding `postcss` as an explicit dep (pnpm isolated node_modules doesn't hoist it) also does not fix it.
* **Execution/Fix:** Pin both scripts to webpack — `"dev": "next dev --webpack"`, `"build": "next build --webpack"`. Builds clean. Keep `build` on webpack too so Vercel uses the same bundler as local and can't diverge. Confirmed working on `second-storey-painting` and already the pattern in `omahatreecare-next`.
* **Recurrence risk:** The stack trace points at CSS, so the instinct is to debug the Tailwind theme or `globals.css` — a dead end that can burn an hour. Isolate in one step by replacing `globals.css` with a single `@import "tailwindcss";` line: if it still fails, it's environmental. Hits every new Next 16 project on this machine.

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

### `/memory` command — what it actually does (corrected)
* **Symptom/Context:** User runs `/memory`, sees it prompt to edit a file, and it feels like it "does nothing." Frustration is that its full function isn't obvious.
* **Root Cause/Mechanic:** Per current Claude Code docs (`code.claude.com/docs/en/commands`), built-in `/memory` does THREE things: (1) edit `CLAUDE.md` memory files, (2) enable/disable auto-memory, (3) **view auto-memory entries**. The "edit a file" prompt is only branch (1). On this machine `autoMemoryDirectory` → `~/h1ve/memory/claude/` (see [[feedback_automemory_location]]), so `/memory` IS the UI into the h1ve auto-memory store — viewing/toggling the very files that drive h1ve persistence. It is NOT a no-op and IS h1ve-integrated.
* **Execution/Fix:** `/memory` is legit for viewing auto-memory entries and toggling capture. For *adding* a specific fact fast, still just tell Claude "update h1ve" — the assistant edits `~/h1ve/memory/` directly and the SessionEnd/PreCompact hooks sync. Both paths are valid.
* **Recurrence risk / self-note:** Do NOT claim `/memory` "does nothing" from training memory — that was asserted wrongly on 2026-07-18 and corrected only after checking docs. The `remember` and `episodic-memory` plugins are hook-driven and define NO slash commands — they are not the source of `/memory`. Verify command behavior against live docs before asserting.

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

---

## opend-ai (uncensored CLI agent)

### Uncapped tool output → context overflow (grep capped matches, not line width)
* **Symptom/Context:** `opend` streamed `The input (~580k tokens) is longer than the model's context length (202752)`, retried 3× ("attempt 3/3"), then died. Same blob got saved into a session file (1.7 MB for 6 messages), so `/load` also broke.
* **Root Cause/Mechanic:** A single `grep_search` over a broad workspace (`~`) returned **1.6M chars in one tool result**. `grepSearch` capped the *number* of matches (100) but not each line's *width* — minified/one-line files (bundles, `.map`, lock files) make one matched "line" megabytes long. That whole result lands in the CURRENT round, which `splitForPrune` can never evict, so no amount of history pruning helps. Two secondary bugs let it escape cleanly: `isContextOverflow` gated on `err.status === 400`, but streamed (SSE) overflow errors carry no status → recovery never fired; `isRetryable` treated the status-less error as transient → wasted the 3 retries.
* **Execution/Fix:** (1) `grepSearch` trims each line to 500 chars; (2) universal cap at the tool-dispatch choke point in `agent.ts` (`capToolResult`) truncates EVERY tool result to `toolOutputCap(contextTokens)` ≈ contextTokens chars (~¼ of window); (3) `isContextOverflow` now matches on message text regardless of status; (4) `isRetryable` returns false for overflows. Live repo is `/home/sudotsu/opend-ai` (global `opend` symlinks into its `dist/` — rebuild `dist` = fix is live, no reinstall). 181 tests pass.
* **Recurrence risk:** "Limit the rows but not the row width" is invisible until a minified file is in scope. The prune/summarize system looks bulletproof, so the instinct is to trust it — but it structurally cannot shrink a single oversized round; the only real fix is bounding tool output at the source.
* **Follow-up (same session, shipped):** made `grep_search` quality-good from a broad workspace: added the `ignore` npm lib (7.0.6) for correct nested `.gitignore` matching incl. ancestor repo `.gitignore` above the search root; `ALWAYS_SKIP_DIRS` set (node_modules/.git/dist/build/.next/.venv/target/… ~30 dirs); NUL-byte binary content-sniff (not extension guessing); explicit-target search still overrides ignore rules. 185 tests. Verified end-to-end outside a repo (600KB one-line file → 602-char output).

---

## Agent handoffs & multi-tool workflows

### A prior agent's "completion report" is not evidence the work exists
* **Symptom/Context:** A prompt arrived saying `brand-teardown` "has already been designed and locally tested in this conversation — do not start over," with three supporting artifact files attached. Nothing had been built. The artifacts were 423, 397, and 155 bytes.
* **Root Cause/Mechanic:** The files were the prior run's *failure report*, not its output — `brand-teardown-completion.md` literally recorded "Draft PR: **not found**", "Branch head: `unavailable`", "Changed files: `0`", and three missing retrieval files. The branch `agent/add-brand-teardown` did exist on GitHub, which made the claim look plausible, but `compare/main...agent/add-brand-teardown` returned `status: identical, ahead_by: 0, files: []` — a branch pointer created off main and never written to. The summary of an implementation survives a context handoff; the implementation files do not.
* **Execution/Fix:** Verify against the system of record before accepting any handoff claim. For GitHub: `gh api repos/O/R/compare/main...BRANCH` (ahead_by + files), `gh api "repos/O/R/git/trees/BRANCH?recursive=1"` filtered by path (per-branch, reads real git objects), and `gh api "search/code?q=TERM+user:USER"` as corroboration only — code search lags and doesn't reliably cover non-default branches. Also check local clones for uncommitted work, stashes, and dangling objects before concluding absence.
* **Recurrence risk:** High and rising with cross-tool workflows (ChatGPT/Codex → Claude Code). A confident handoff prompt plus a real-looking branch name plus attached "evidence" files is extremely convincing, and the natural move is to start executing step 2 of the instructions rather than verifying step 1. Reading the attached artifacts *first* is what exposed it — they documented their own failure.

### Editing a ported copy instead of the source gets silently reverted
* **Symptom/Context:** Made four improvements to `~/.claude/skills/{project-teardown,project-revision}/SKILL.md`. Both bundles validated, all tests passed, work looked complete.
* **Root Cause/Mechanic:** Those directories are a *port*. The source of truth is `~/.codex/skills/` (AJ authors these in ChatGPT/Codex). The documented refresh is `rsync -a --exclude '__pycache__' ~/.codex/skills/<name>/ ~/.claude/skills/<name>/`, which overwrites the destination — the next source update would have destroyed the edits with no error, no conflict, and no diff to notice.
* **Execution/Fix:** Edit `~/.codex/skills/` first, then re-port. Verify with `diff -r -q --exclude=__pycache__ ~/.codex/skills/<n> ~/.claude/skills/<n>` (expect no output), then `python3 <dir>/scripts/validate_skill_bundle.py <dir> --mode installed` and `cd <dir>/scripts && python3 -m unittest discover -s . -p 'test_*.py'`.
* **Recurrence risk:** `git status` in `~/.claude/skills/` returns "not a repository," which reads as "untracked, nothing to worry about" — the wrong conclusion. The right question is not *is this directory tracked* but *where does the canonical copy live and what direction does sync flow*. Applies to any install-location-vs-source-location setup.

