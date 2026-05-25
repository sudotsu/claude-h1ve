# New Machine Setup Checklist

Use this when adding a new machine to h1ve.

## 1. Prerequisites
- Node.js installed
- `gh` CLI installed
- `gh auth login` completed (use browser flow, not token paste)

## 2. Install Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

## 3. Clone h1ve
```bash
gh repo clone sudotsu/h1ve ~/h1ve
```

## 4. Create the machine's machine.md
```bash
mkdir -p ~/h1ve/machines/<machine-name>
cp ~/h1ve/templates/machine-template.md ~/h1ve/machines/<machine-name>/machine.md
```

Fill in every field in the template. Use these commands to gather specs:

**Linux/WSL:**
```bash
lscpu                                    # CPU
free -h                                  # RAM
lspci | grep -i vga                      # GPU (not available in WSL)
lsblk -d -o NAME,SIZE,MODEL,TYPE        # Storage
uname -r                                 # Kernel
cat /etc/os-release                      # OS
```

**Windows (via PowerShell from WSL):**
```bash
powershell.exe -Command "Get-CimInstance Win32_Processor | Select Name"
powershell.exe -Command "Get-CimInstance Win32_VideoController | Select Name, AdapterRAM"
powershell.exe -Command "Get-CimInstance Win32_PhysicalMemory | Select Capacity, Speed, Manufacturer, PartNumber"
powershell.exe -Command "Get-PhysicalDisk | Select FriendlyName, MediaType, Size"
powershell.exe -Command "Get-CimInstance Win32_BaseBoard | Select Product, Manufacturer"
powershell.exe -Command "Get-CimInstance Win32_BIOS | Select SMBIOSBIOSVersion, ReleaseDate"
```

Also fill in: installed tools (`node -v`, `python3 --version`, `git --version`, `gh --version`, `claude --version`), important paths, and OS-specific notes.

## 5. Build CLAUDE.md
```bash
bash ~/h1ve/scripts/propagate.sh
```
This generates `machines/<machine-name>/CLAUDE.md` by concatenating `machine.md` + `shared/CLAUDE-system.md` + `shared/CLAUDE-behavior.md`. CLAUDE.md is a build artifact — never edit it directly.

## 6. Run the setup script

**Linux/WSL/Termux:**
```bash
bash ~/h1ve/scripts/setup-machine.sh <machine-name>
```

**Windows (PowerShell):**
```powershell
~\h1ve\scripts\setup-machine.ps1 <machine-name>
```

The script creates the `~/.claude/CLAUDE.md` symlink, merges h1ve hooks into `~/.claude/settings.json` (preserving any existing settings), and verifies everything is wired correctly. It prints pass/fail for each step.

## 8. Run optimization sweep
Open Claude Code and ask:
> "Run a system optimization sweep on this machine. Refer to machines/envy-frankenstein/CLAUDE.md or machines/desktop-gaming/CLAUDE.md for examples of what optimizations have been applied on other machines. Check which of those apply here, surface anything else worth fixing, and update this machine's CLAUDE.md with everything applied."

## 9. Initial sync
```bash
bash ~/h1ve/scripts/sync.sh
```
