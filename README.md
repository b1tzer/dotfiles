# dotfiles — Cross-platform Dev Environment Manager

One command to set up any new machine. Git-tracked, platform-aware, secret-safe.

```bash
git clone <your-repo-url> ~/dotfiles && cd ~/dotfiles && ./bootstrap.sh
```

---

## Features

| Feature | Description |
|---------|-------------|
| 🚀 One-command setup | `bootstrap.sh` handles everything end-to-end |
| 🖥️ Cross-platform | Ubuntu / macOS / Windows (WSL/Git Bash) |
| 📦 Tool manifest | Declare tools in `tools.yaml`, sync anywhere |
| 🔗 dotfiles symlinks | Auto-link shell configs with backup protection |
| 🔒 Secret-safe | Placeholder system + pre-commit hook scanning |
| 🔄 Easy sync | `bootstrap.sh --pull` to apply latest changes |
| ♻️ Tool migration | Mark deprecated tools, auto-install replacements |

---

## Repository Structure

```
dotfiles/
├── bootstrap.sh              # ← Entry point: run this on any new machine
├── tools.yaml                # ← Declare all tools here
├── secrets.template.env      # ← Sensitive config template (committed)
├── .gitignore                # ← Excludes secrets.local.env and sensitive files
│
├── lib/
│   ├── detect_os.sh          # OS detection module
│   ├── pkg_manager.sh        # Package manager adapter (apt/brew/winget...)
│   └── secret_check.sh       # Secret pattern scanner
│
├── scripts/
│   ├── sync.sh               # Tool installation engine
│   ├── link_dotfiles.sh      # Dotfiles symlink manager
│   └── init_secrets.sh       # Interactive secrets wizard
│
├── hooks/
│   └── pre-commit            # Git hook: blocks commits with secrets
│
├── dotfiles/                 # Your actual config files (symlinked to $HOME)
│   ├── .zshrc                # Common Zsh config
│   ├── .zshrc.macos          # macOS-specific additions
│   ├── .zshrc.ubuntu         # Ubuntu-specific additions
│   ├── .vimrc                # Vim config
│   └── .config/
│       └── starship.toml     # Starship prompt config
│
└── configs/
    └── git/
        └── gitconfig.template  # Git config template (uses {{PLACEHOLDERS}})
```

---

## Quick Start

### New Machine Setup

```bash
# 1. Clone your dotfiles repo
git clone https://github.com/yourname/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Run bootstrap (detects OS, installs tools, links dotfiles, sets up secrets)
./bootstrap.sh

# 3. Reload your shell
exec $SHELL
```

### Sync Latest Changes to an Existing Machine

```bash
cd ~/dotfiles
./bootstrap.sh --pull
```

### Preview Changes Without Applying

```bash
./bootstrap.sh --dry-run
```

---

## Managing Tools (`tools.yaml`)

### Add a New Tool

```yaml
tools:
  - name: lazygit
    description: "Terminal UI for git"
    platforms:
      ubuntu:
        method: apt
        install: lazygit
      macos:
        method: brew
        install: lazygit
      windows:
        method: winget
        install: JesseDuffield.lazygit
```

Then sync:
```bash
./scripts/sync.sh
# or sync a single tool:
./scripts/sync.sh --tool lazygit
```

### Replace a Tool with Another

Mark the old tool as deprecated and point to the replacement:

```yaml
  - name: exa
    deprecated: true
    replaced_by: eza
    migration_note: "exa is unmaintained. Update alias 'ls=exa' to 'ls=eza'."
    platforms:
      ubuntu:
        method: apt
        install: exa

  - name: eza
    description: "Modern ls replacement (successor to exa)"
    platforms:
      ubuntu:
        method: apt
        install: eza
      macos:
        method: brew
        install: eza
```

On next sync, the system will:
1. Warn that `exa` is deprecated
2. Automatically install `eza` as the replacement
3. Print the migration note

### Remove a Tool

Simply delete or comment out its entry in `tools.yaml`. On next sync, the system will prompt you to uninstall it (no forced removal).

---

## Managing Secrets

### How It Works

```
secrets.template.env   ← committed to Git (placeholders only)
~/.secrets.local.env   ← gitignored, stays on each machine
```

### Initialize Secrets on a New Machine

```bash
./scripts/init_secrets.sh
```

This wizard reads `secrets.template.env` and guides you to fill in real values.

### Check If All Required Secrets Are Set

```bash
./scripts/init_secrets.sh --check
```

### Add a New Secret

1. Add a line to `secrets.template.env`:
   ```
   MY_API_KEY=CHANGE_ME|Description of what this key is for|yes
   ```
2. Commit the template change
3. On each machine, run `./scripts/init_secrets.sh` to fill in the real value

### Use Secrets in Config Templates

In any file under `configs/` ending in `.template`, use `{{KEY}}` syntax:

```ini
# configs/git/gitconfig.template
[user]
    name  = {{GIT_USER_NAME}}
    email = {{GIT_USER_EMAIL}}
```

Apply templates after filling secrets:
```bash
./scripts/init_secrets.sh --apply
```

---

## Managing dotfiles

### Add a New dotfile

1. Place the file in `dotfiles/` (mirroring its `$HOME` path):
   ```
   dotfiles/.tmux.conf          → links to ~/.tmux.conf
   dotfiles/.config/nvim/init.lua → links to ~/.config/nvim/init.lua
   ```
2. Run `./scripts/link_dotfiles.sh` to create the symlink

### Platform-Specific Config

Create a platform variant alongside the base file:
```
dotfiles/.zshrc          # Common config (all platforms)
dotfiles/.zshrc.macos    # macOS additions (sourced automatically)
dotfiles/.zshrc.ubuntu   # Ubuntu additions (sourced automatically)
```

### Editing dotfiles

Since files are symlinked, editing `~/.zshrc` **directly edits the repo file**. Just commit and push:

```bash
# Edit as normal
vim ~/.zshrc

# Changes are already in the repo
cd ~/dotfiles
git add dotfiles/.zshrc
git commit -m "feat: add fzf keybindings"
git push
```

### Restore Original Files (Unlink)

```bash
./scripts/link_dotfiles.sh --unlink
```

This removes symlinks and restores the most recent backup.

---

## Syncing Across Machines

```
Machine A                    Git Remote               Machine B
─────────                    ──────────               ─────────
Edit tools.yaml         →    git push            →    bootstrap.sh --pull
Add new dotfile         →    git push            →    bootstrap.sh --pull
Update secrets template →    git push            →    init_secrets.sh
```

**Workflow:**
1. Make changes on Machine A
2. `git add . && git commit -m "..." && git push`
3. On Machine B: `cd ~/dotfiles && ./bootstrap.sh --pull`

---

## Security Notes

- `secrets.local.env` is **never committed** (enforced by `.gitignore`)
- The **pre-commit hook** scans for common secret patterns before every commit
- Config templates use `{{PLACEHOLDER}}` syntax — real values stay local
- To bypass the hook in an emergency: `git commit --no-verify` (use with caution)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `yq: command not found` | Run `./scripts/sync.sh` — it auto-installs yq |
| Tool already installed but sync tries to reinstall | Check `check_cmd` field in `tools.yaml` |
| Symlink creation fails | Check file permissions or run with `sudo` |
| Secret check false positive | Add file to `SECRET_SKIP_PATTERNS` in `lib/secret_check.sh` |
| Want to re-run secrets wizard | `./scripts/init_secrets.sh` |
