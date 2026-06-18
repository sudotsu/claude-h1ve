# Architectural Decisions

## 2026-06-09: Known limitation — conversational decisions that go unrecognized are permanently lost
**Situation:** During a session on desktop-gaming (WSL), the `Stop` hook was found still present in `~/.claude/settings.json` alongside `SessionEnd` and `PreCompact`. The documented decision (2026-02-19, updated 2026-05-19) clearly states `Stop` was replaced by `SessionEnd` + `PreCompact` once its per-turn semantics were confirmed. However, there was a prior conversation specifically about whether to intentionally keep `Stop` for a different purpose (per-turn sync if docs changed) — and the outcome of that conversation was never logged. That outcome is now permanently unrecoverable.

**Root cause:** h1ve's session-end protocol enforces that decisions get written — the CLAUDE.md instructions are explicit and auto-enforced via hook. The gap is not enforcement of *writing* but enforcement of *recognition*. A conversational decision only gets logged if the LLM identifies it as a decision worth capturing during the session. Exploratory discussions, partially-resolved debates, or topics that trail off without a clear conclusion don't trigger that recognition reliably. The Stop discussion likely ended without a firm commitment either way, so it was never framed as "log this."

**What was lost:** Whether `Stop` should be retained alongside `SessionEnd` as an intentional per-turn sync trigger (the hypothesis was: fire sync immediately after any turn where docs were modified, rather than waiting until session end). The decision made in this session (2026-06-09) was to remove `Stop` based on the documented intent in decisions.md — but if the prior conversation had concluded to keep it, that conclusion is gone.

**Limitation:** h1ve cannot capture decisions that exist only in conversation history. It captures what gets written. Auto-memory (`memory/claude/`) handles preferences and patterns automatically, but `decisions.md` requires deliberate recognition that something architectural was decided.

**No fix identified yet.** Possible directions: a session-end prompt that explicitly asks "what architectural decisions were made this session?" before sync runs; a mid-session habit of writing draft decisions.md entries in scratch/ as discussions happen. Neither has been evaluated.

## 2026-05-24: Split shared/CLAUDE-shared.md into system and behavior files
**Decision:** `shared/CLAUDE-shared.md` deleted and replaced by two files: `shared/CLAUDE-system.md` (h1ve infrastructure — session protocol, build rules, operational rules, machine context, tech stack) and `shared/CLAUDE-behavior.md` (behavior, collaboration, and engineering standards). `propagate.sh` updated to concatenate all three sources. `/storage/emulated/0/.claude/CLAUDE.md` (project-level override) deleted — behavior rules now propagate through the same channel as everything else.

**Why:** The two concerns have different change rates and different owners. Infrastructure rules change when h1ve architecture changes. Behavior rules change when the user refines their working style. Mixing them in one file created an editing hazard — changing behavior rules required carefully avoiding h1ve system sections, and vice versa. The split eliminates that risk and makes each file's purpose unambiguous. Deleting the project-level override removes a second source of truth that could silently drift from the canonical version.

## 2026-05-24: Public template sync automated — sync-public.sh + GitHub Action
**Decision:** `scripts/sync-public.sh` replaces the manual public template update process. It clones `sudotsu/claude-h1ve` into `scratch/`, copies all structural files (scripts, shared, templates, handoffs, agents, memory/kb.md, memory/decisions.md), sanitizes personal data from `shared/CLAUDE-system.md` (H1VE Context and Tech Stack sections → generic placeholders) and `agents/chatgpt/instructions.md`, writes blank templates for `memory/shared.md` and `memory/projects.md`, rebuilds example machine CLAUDE.md files via propagate.sh, and commits with the private repo's SHA in the message. `.github/workflows/sync-public.yml` triggers it automatically on push to master when any structural file changes. Requires `PUBLIC_REPO_TOKEN` secret (PAT with repo write access to `sudotsu/claude-h1ve`) in private repo settings. Obsolete files (`scripts/new-machine.sh`, `install.sh`, `shared/CLAUDE-shared.md`) are removed from the public repo on sync.

**Why:** The public template was last manually synced 2026-02-21 and had already drifted significantly — missing the source/artifact split, setup-machine scripts, session-start self-repair, kb.md schema changes, and the CLAUDE-shared.md split. Manual sync was the only path and had no trigger or checklist. The GitHub Action makes drift impossible: every structural change to the private repo automatically propagates to the public template with no human memory required.

## 2026-05-24: Hook setup automated — setup-machine scripts + session-start self-repair
**Decision:** Hook wiring is no longer a manual documentation-dependent step. Two new scripts handle setup: `scripts/setup-machine.sh` (Linux/WSL/Termux) and `scripts/setup-machine.ps1` (Windows). Both detect the environment, merge h1ve hooks into `~/.claude/settings.json` without overwriting other settings, create the CLAUDE.md symlink, and verify each step with explicit pass/fail output. `session-start.sh` now verifies SessionEnd and PreCompact hooks on every session start and auto-repairs drift (Linux/WSL/Termux only — Windows requires re-running setup-machine.ps1). `sync.sh` writes `scratch/last-sync-status` on every run; `session-start.sh` surfaces any failure from the previous session at the top of the new one. `templates/new-machine-setup.md` steps 6+7 collapse to a single "run the setup script" instruction.

**Why:** The previous approach documented the correct settings.json content and relied on the user to manually write it correctly — a silent failure mode with no recovery path. Windows was especially fragile: the PowerShell wrapper had hardcoded paths that required manual substitution, and copying the wrong template silently broke all hooks. The setup scripts eliminate the human memory dependency. The session-start self-repair means hook drift from any cause (Claude Code update overwriting settings, accidental edit) is caught and fixed at the next session open without user involvement.

## 2026-05-24: kb.md schema tightened — Recurrence risk field added, 7 entries removed
**Decision:** Added mandatory `**Recurrence risk:**` field to the kb.md entry schema. Removed 7 entries that failed the test: Windows performance config, autocrlf Linux/Windows (googleable git config), Gboard swipe typing (one-time setup preference), 32-bit instruction warning ("just ignore it"), machines/CLAUDE.md is generated artifact (structurally enforced by banner + Build Rules), Two different SHARED markers (obsolete — CLAUDE-shared.md no longer exists), HP ENVY x360 RAM slots (hardware specs documentation, not a diagnostic gotcha).

**Why:** The previous schema had no mechanism to enforce the high-signal bar at write time. "High signal-to-noise: only add things that would bite you again" was aspirational but structurally unenforced — weak entries accumulated alongside strong ones. The Recurrence risk field forces explicit reasoning before writing: if you can't state why this would bite you again and why it's non-obvious to diagnose without the entry, it doesn't belong. Applied retroactively to all existing entries; those that couldn't be justified were removed rather than preserved.

**Removed entries are gone intentionally.** If something removed turns out to still be needed, the criterion for re-adding it is the same: fill in all four fields including a convincing Recurrence risk. If you can't, it doesn't come back.

## 2026-03-12: Named extraction marker in shared source files
**Decision:** `<!-- BEGIN SHARED -->` replaces `---` as the delimiter in `shared/CLAUDE-shared.md` and `shared/GEMINI-shared.md`. `propagate.sh` uses `grep -n` to find the marker line, then `tail -n +N` to extract content after it. Missing marker is a hard error with a clear message.

**Why:** `---` is a natural markdown element (horizontal rule, YAML front matter). Any `---` appearing above the intended separator in a source file would cause silent wrong extraction — the old sed pattern matched the first occurrence, no error, wrong content in every built CLAUDE.md. The named marker is unambiguous and self-documenting. This is distinct from the OLD `<!-- SHARED -->` marker (2026-02-19, removed in 06440d0) which lived in the output file (CLAUDE.md) and was used for in-place replacement — the new marker lives in the source file and is used only for preamble-skip extraction.

## 2026-03-12: sync.sh trap ERR for unexpected failures
**Decision:** `trap ERR` added to `sync.sh`. When any command fails unexpectedly (failed rebase, auth expiry, push failure), the trap prints recovery instructions — including stash recovery if changes were stashed before the failure. The existing explicit `if ! git stash pop` handler is unaffected (`if !` suppresses ERR trap in bash).

**Why:** The previous conflict guard only caught `stash pop` failure. A failed `git pull --rebase` with stashed changes would exit immediately via `set -e`, leaving an orphaned autostash with no recovery guidance. User had to know to run `git stash list`. The trap surfaces this explicitly.

## 2026-02-18: Initial h1ve repo structure
- Each AI agent gets its own directory under `agents/`
- Shared memory lives in `memory/` — all agents read/write here
- Machine-specific info lives in `machines/`
- Templates for new setups live in `templates/`
- Agents should NOT modify each other's agent-specific configs

## 2026-02-19: Machines-as-directories + symlink pattern
**Decision:** Each machine is a directory under `machines/` containing a `CLAUDE.md`, not a flat `.md` file.

**Why:** Claude Code loads `~/.claude/CLAUDE.md` as global instructions. By symlinking that path to `~/h1ve/machines/<name>/CLAUDE.md`, each instance always reads from the repo. No manual copying, no drift.

**Why shared content is pasted (not symlinked):** Claude Code has no include/import mechanism — it reads one flat file. So the shared rules from `shared/CLAUDE-shared.md` are pasted into the bottom of each machine's CLAUDE.md. This duplicates content across machine files intentionally — each instance loads only its own machine context + shared rules, not every other machine's specs.

**Source of truth for shared rules:** `shared/CLAUDE-shared.md`. The `<!-- SHARED -->` comment in each machine file marks where the shared section begins. `propagate.sh` replaces everything below that marker on every sync.

**Reference implementation:** `machines/acer-mint/CLAUDE.md`

## 2026-02-19: Fix errors immediately, no workarounds without approval
**Decision:** When errors or warnings are found, always surface them and propose a real fix — never a workaround unless the user explicitly approves it. Errors are fixed immediately, not deferred.

**Why:** Workarounds accumulate as tech debt. In previous sessions, Claude applied workarounds (e.g., registering a fake `WSLInterop` binfmt entry to bypass a `wslu` bug) instead of diagnosing the root cause (missing `BROWSER` env var). This creates fragile state that breaks on reboot and masks the real problem.

## 2026-02-19: Auto-sync via SessionEnd/PreCompact hooks + auto-propagation in sync.sh
**Decision:** `sync.sh` runs automatically via `SessionEnd` and `PreCompact` hooks. `SessionEnd` fires when the session terminates; `PreCompact` fires before manual or auto context compaction. `propagate.sh` runs inside `sync.sh` so shared instruction changes always propagate before committing.

**Why:** Relying on users to remember to sync is unrealistic. Embedding propagation in `sync.sh` ensures shared rule changes can never be committed without being propagated to all machines first. Original wiring used `Stop`, which fires after every agent response turn — not at session end. `SessionEnd` is the correct lifecycle event.

**Updated 2026-05-19:** Rewired from `Stop` → `SessionEnd` + `PreCompact` after confirming `Stop` fires per-turn, not per-session. Also added conflict guard for `stash pop` failure (separate entry).

## 2026-02-19: Session start pulls then reads git history
**Decision:** On session start, Claude checks `git log --oneline -10` and `git diff HEAD~3 -- memory/` before reading memory files, then briefly tells the user what changed from other machines.

**Why:** Without git history review, Claude only sees current state — it doesn't know what changed or when. Reading recent commits and memory diffs gives cross-machine awareness, not just a snapshot.

## 2026-02-19: Use claude-mem for conversation capture — REVERSED 2026-02-21
**Original decision:** Use claude-mem (third-party, AGPL, local-only) for conversation persistence via hooks + SQLite + semantic search.

**Reversed. claude-mem integration officially dropped.** Reasons:

1. **Hook collision on Windows** — Windows machines require a specific PowerShell→Git Bash wrapper in `~/.claude/settings.json`. claude-mem injects its own hooks, which would silently overwrite or break the wrapper, severing both `session-start.sh` and `sync.sh`.
2. **SQLite binary breaks git sync** — Syncing a binary SQLite DB via git produces binary diffs that always cause merge conflicts, which trips the `stash pop` safety valve in `sync.sh` and halts every sync.
3. **h1ve already does it better** — The goal of claude-mem was capturing reasoning chains and what-was-tried. h1ve's handoff protocol, `memory/kb.md`, and `memory/decisions.md` already do this in structured, token-efficient form. Raw conversation logs would force Claude to read growing histories of outdated information, degrading reasoning quality and burning context window.
4. **Violates core principles** — Prefer simple, testable architectures over clever abstractions. A third-party SQLite-backed hook system in a bash-driven git monorepo is the opposite of that.

## 2026-02-20: SessionStart hook for automatic session-start pull
**Decision:** A `SessionStart` hook (matcher: `startup|resume|clear`) runs `scripts/session-start.sh` at session open. The matcher filters out the `compact` subtype so mid-session compaction doesn't trigger a pull against potentially in-flight state. `--resume` matches the `resume` subtype and gets a fresh pull just like a new session. No PPID lockfile needed — `SessionStart` fires once per session boundary by design.

**Why:** Opening a session to read context without prompting ran against stale memory when wired to `UserPromptSubmit`. `SessionStart` is the purpose-built lifecycle event for session-open initialization and fires regardless of whether the user submits a prompt.

**Updated 2026-05-19:** Rewired from `UserPromptSubmit` + PPID lockfile → `SessionStart` with subtype matcher. Lockfile removed from `session-start.sh` entirely — `SessionStart` semantics make it redundant.

## 2026-02-20: Split dual-boot into separate OS profiles
**Decision:** `machines/acer-dualboot/` split into `machines/acer-mint/` and `machines/acer-windows/`. Each OS boots into its own filesystem with its own `~/.claude/CLAUDE.md` symlink pointing to its own profile.

**Why:** A dual-boot machine has two completely separate filesystem contexts. Linux Mint's `~/.claude/CLAUDE.md` lives on the SSD, Windows' lives on the NVMe. A single shared profile causes cross-contamination — Claude on Windows would read Linux paths (`/etc/sysctl.d/`, `apt`, `pnpm`) and attempt to execute them in PowerShell. Splitting into two profiles is deterministic and costs zero runtime tokens. An OS-detection prompt rule was considered and rejected: it burns tokens every session and is probabilistic (Claude can forget to run the check).

**Credit:** Gemini CLI identified this during cross-agent architecture review.

## 2026-02-20: Conflict detection in sync.sh
**Decision:** `sync.sh` checks the exit code of `git stash pop`. If it fails (merge conflict), the script halts immediately with a loud error message and does NOT proceed to propagate or push.

**Why:** The `SessionEnd` hook runs without user interaction. If `stash pop` silently injects `<<<<<<<` conflict markers into memory files, the next Claude session reads those markers as literal instructions, poisoning its context. The safety valve prevents corrupted files from ever being committed or propagated.

**Credit:** Gemini CLI identified this during cross-agent architecture review.

## 2026-02-20: Windows hooks use PowerShell→Git Bash wrapper
**Decision:** On Windows machines with WSL installed, hook commands in `~/.claude/settings.json` invoke Git Bash via PowerShell: `powershell.exe -NoProfile -Command "& 'C:/Program Files/Git/bin/bash.exe' '...script...'"`. Linux machines use `shared/settings.json` with `$HOME` as-is. Do NOT copy the shared template on Windows machines.

**Why:** Claude Code's hook runner resolves to `/bin/bash` which on Windows+WSL machines is the WSL shim (`C:\Windows\System32\bash.exe`), not Git Bash. WSL bash cannot resolve Git Bash paths (`/c/Users/...`) or Windows-native paths (`C:\Users\...`). An intermediate attempt using `bash -c '$HOME/...'` also failed because Node.js on Windows passes `HOME=C:\Users\HP` but WSL bash interprets it as `/home/hp/` which doesn't exist. Routing through PowerShell bypasses the WSL shim entirely, guaranteeing Git Bash is invoked with the correct Windows-native paths.

**Credit:** Gemini CLI identified the PowerShell wrapper approach.

## 2026-02-21: State files stay as snapshots — not append-only
**Decision:** `memory/shared.md` and `memory/projects.md` remain single-source-of-truth state snapshots, edited in-place. Only chronological log files (e.g., `decisions.md`, future session journals) are append-only. `decisions.md` entries always include date and machine name.

**Why:** Converting state files to append-only logs was proposed to reduce Git merge conflicts, but a third-party LLM review identified this as a strategic mistake. It would force Claude to read a growing log of outdated information and synthesize current state on every session start — burning tokens and degrading reasoning quality over time. The `git stash pop` conflict guard in `sync.sh` already handles the mechanical conflict risk. Let Git manage version control; let memory files hold pure current state.

## 2026-02-21: Handoff archive mechanic
**Decision:** Resolved handoffs move to `handoffs/archive/` immediately upon resolution. Session start protocol scans root `handoffs/` only — never `archive/`. Archive is read only when explicitly searching for historical context.

**Why:** Claude must read a file to determine if it's open or resolved (status is inside the file, not the filename). Without an archive, every session start reads every resolved handoff ever written just to find zero open ones. As the system scales, this silently burns context window on stale data. The archive makes the distinction mechanical: root = active, archive = history. Cost of implementation is zero; cost of not doing it grows permanently.

## 2026-02-21: Source/artifact split for machine CLAUDE.md files
**Decision:** Each machine directory now has two files: `machine.md` (editable source) and `CLAUDE.md` (generated artifact). `propagate.sh` builds CLAUDE.md by concatenating machine.md + shared content from `shared/CLAUDE-shared.md`. CLAUDE.md is never edited directly.

**Why:** The previous marker-based approach (`<!-- SHARED -->` + sed/grep) had a single point of failure: if the marker was missing, malformed, or accidentally edited, propagation silently failed or corrupted the file. Concatenation has no dependencies on file content — it always produces a correct output regardless of what's in machine.md. Additionally, Gemini identified an overwrite vector: if Claude updated CLAUDE.md directly (e.g., correcting RAM specs after a hardware check), the next propagate run would silently wipe that change. The source/artifact split eliminates this by making CLAUDE.md a forbidden-edit artifact with a warning banner on line 1.

**Structural changes:** `templates/machine-template.md` no longer includes the `<!-- SHARED -->` footer. `templates/new-machine-setup.md` step 4 creates machine.md (not CLAUDE.md). "Never edit CLAUDE.md" rule added to `shared/CLAUDE-shared.md` (H1VE Build Rules section) and `agents/claude/instructions.md`.

**Credit:** Overwrite vector identified by Gemini CLI. Warning banner enhancement suggested by Gemini CLI.

## 2026-02-21: Project-scoped context via projects/ directory
**Decision:** Each project gets a `projects/<name>/CLAUDE.md` in h1ve. This file is symlinked into the project's working directory. Claude Code auto-reads it when launched from that directory by walking up the directory tree.

**Why:** Without project context, every new Claude Code session requires re-explaining the stack, architecture, current focus, and gotchas for whatever project is being worked on. Storing this in h1ve means it syncs across all machines automatically. The symlink is machine-local setup (one-time per project per machine); the content travels via git.

## 2026-06-18: Enter motog NetHunter chroot from Termux, not the NetHunter Terminal app (machine: kali / motog-nethunter)
**Decision:** On the Moto G NetHunter device, the Kali chroot is entered from the **Termux app** via a `boot-kali` command (installed by `/sdcard/boot-kali-setup.sh`, modeled on cipherswami/boot-nethunter), which `su -c` runs NetHunter's own `bootkali` to mount + chroot into the same `/data/local/nhsystem/kali-arm64`. The NetHunter Terminal app is abandoned as the entry point.

**Why:** The NetHunter Terminal app is an old Termux fork whose input handling forces Gboard into a degraded mode — no swipe (glide) typing, no voice-to-text. Termux's terminal handles Gboard correctly, so swipe + voice work there. Both paths land in the identical rootfs (same tools, aichat, configs), so there is no downside to switching the launcher. Reusing NetHunter's own `bootkali` rather than hand-rolling mount/chroot logic keeps the device-specific mount sequence battle-tested. Considered and rejected: fixing the NetHunter Terminal app via `enforce-char-based-input` in `termux.properties` — that file lives in the app's Android-private data (`/data/data`), which is not bind-mounted into the chroot, and Kali's own docs already concede the app needs Hacker's Keyboard as a workaround, confirming the app is the wrong layer to fix.
