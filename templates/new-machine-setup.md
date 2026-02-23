# New Machine Setup

Use this when adding a new machine to the hive.

## 1. Prerequisites
- Node.js installed
- `git` installed
- `gh` CLI installed and authenticated (`gh auth login`)

## 2. Install Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

## 3. Clone the hive
```bash
gh repo clone YOUR-USERNAME/claude-h1ve ~/hive
```

## 4. Create the machine profile
```bash
bash ~/hive/scripts/new-machine.sh <machine-name>
```
This creates `machines/<machine-name>/machine.md` from the template, builds
`CLAUDE.md` via `propagate.sh`, and symlinks `~/.claude/CLAUDE.md` to it.

Fill in every field in `machine.md`. Use these commands to gather specs:

**Linux / WSL:**
```bash
lscpu                                    # CPU
free -h                                  # RAM
lspci | grep -i vga                      # GPU (not available inside WSL)
lsblk -d -o NAME,SIZE,MODEL,TYPE        # Storage
uname -r                                 # Kernel
cat /etc/os-release                      # OS
```

**Windows (run from PowerShell or WSL):**
```bash
powershell.exe -Command "Get-CimInstance Win32_Processor | Select Name"
powershell.exe -Command "Get-CimInstance Win32_VideoController | Select Name, AdapterRAM"
powershell.exe -Command "Get-CimInstance Win32_PhysicalMemory | Select Capacity, Speed, Manufacturer, PartNumber"
powershell.exe -Command "Get-PhysicalDisk | Select FriendlyName, MediaType, Size"
powershell.exe -Command "Get-CimInstance Win32_BIOS | Select SMBIOSBIOSVersion, ReleaseDate"
```

Also fill in: installed tools (`node -v`, `python3 --version`, `git --version`,
`gh --version`, `claude --version`), important paths, and OS-specific notes.

After editing `machine.md`, rebuild:
```bash
bash ~/hive/scripts/propagate.sh
```

## 5. Set up hooks

Hooks wire Claude Code's session lifecycle to the hive — pulling on session
start and syncing on session end.

**Linux / WSL2 (Claude Code running inside Linux or WSL2):**
```bash
cp ~/hive/shared/settings.json ~/.claude/settings.json
```

**Native Windows — Git Bash (Claude Code running in Windows, not WSL2):**

Do NOT copy `shared/settings.json` — it uses `$HOME` which breaks silently
on native Windows. Create `C:\Users\<USERNAME>\.claude\settings.json` manually:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [{
          "type": "command",
          "command": "powershell.exe -NoProfile -Command \"& 'C:/Program Files/Git/bin/bash.exe' 'C:/Users/<USERNAME>/hive/scripts/session-start.sh'\"",
          "timeout": 15
        }]
      }
    ],
    "Stop": [
      {
        "hooks": [{
          "type": "command",
          "command": "powershell.exe -NoProfile -Command \"& 'C:/Program Files/Git/bin/bash.exe' 'C:/Users/<USERNAME>/hive/scripts/sync.sh'\"",
          "timeout": 30
        }]
      }
    ]
  }
}
```
Replace `<USERNAME>` with your Windows username. See `machines/_example-windows-native/`
for full explanation of why this wrapper is necessary.

## 6. Run an optimization sweep (optional but recommended)

Open Claude Code and ask:
> "Run a system optimization sweep on this machine. Check what optimizations
> have been applied on other machines in machines/ and apply anything relevant
> here. Update machine.md with everything applied, then run propagate.sh."

## 7. Initial sync
```bash
bash ~/hive/scripts/sync.sh
```
