# dotfiles — Cross-platform Dev Environment Manager

One command to set up any new machine. Git-tracked, platform-aware, secret-safe.

```bash
git clone <your-repo-url> ~/dotfiles && cd ~/dotfiles && ./bin/dotfiles sync
```

---

## Features

| Feature | Description |
|---------|-------------|
| 🚀 One-command setup | `./bin/dotfiles sync` handles everything end-to-end |
| 🖥️ Cross-platform | Ubuntu / macOS / Windows (WSL/Git Bash) |
| 📦 Tool manifest | Declare tools in `tools.yaml`，sync anywhere |
| 🔗 dotfiles 管理 | 软链接管理，支持平台特定配置 |
| 🔒 Secret-safe | Placeholder 系统 + pre-commit hook 扫描 |
| 🔄 Easy sync | `./bin/dotfiles update` 拉取最新配置并同步 |
| ♻️ Tool migration | 标记废弃工具，自动安装替代品 |
| 🩺 Health check | `./bin/dotfiles doctor` 诊断环境状态 |
| 📦 Smart cache | 下载资源本地缓存，避免重复下载 |

---

## Repository Structure

```
dotfiles/
├── bin/
│   └── dotfiles              # ← 入口脚本（子命令路由器）
│
├── tools.yaml                # ← 声明所有工具
├── secrets.template.env      # ← 敏感配置模板（已提交）
├── .gitignore                # ← 排除 secrets.local.env 等敏感文件
│
├── lib/
│   ├── logging.sh            # 统一日志模块（NO_COLOR 支持）
│   ├── detect_os.sh          # OS 检测模块（OS_TYPE/OS_ARCH/IS_WSL）
│   └── pkg_manager.sh        # 包管理器抽象层（apt/brew + 缓存）
│
├── scripts/
│   ├── sync.sh               # 工具安装引擎
│   ├── link_dotfiles.sh      # dotfiles 软链接管理
│   ├── doctor.sh             # 环境健康检查
│   ├── cache.sh              # 下载缓存管理
│   └── init_secrets.sh       # 交互式 secrets 向导
│
├── dotfiles/                 # dotfiles 源文件目录
│   ├── .zshrc
│   ├── .vimrc
│   └── .config/
│       └── starship.toml
│
├── tests/
│   ├── unit/                 # 单元测试（无网络，< 30s）
│   │   ├── test_detect_os.sh
│   │   ├── test_logging.sh
│   │   └── test_sync_logic.sh
│   ├── integration/          # 集成测试（使用缓存）
│   │   └── test_full_sync.sh
│   └── fixtures/
│       ├── mock_pkg_manager.sh
│       └── sample_tools.yaml
│
├── hooks/
│   └── pre-commit            # Git hook：提交前阻断敏感信息
│
└── bootstrap.sh              # DEPRECATED: use ./bin/dotfiles sync instead
```

---

## Quick Start

### 新机器初始化

```bash
# 1. 克隆 dotfiles 仓库
git clone https://github.com/yourname/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. 全量同步（检测 OS、安装工具、链接 dotfiles）
./bin/dotfiles sync

# 3. 重载 shell
exec $SHELL
```

### 同步最新配置到已有机器

```bash
cd ~/dotfiles
./bin/dotfiles update          # git pull --ff-only + sync
```

### 诊断环境健康状态

```bash
./bin/dotfiles doctor          # 检查工具、dotfiles、secrets 状态
```

### 其他常用命令

```bash
# 只同步工具（跳过 dotfiles 链接）
./bin/dotfiles sync --tools

# 只链接 dotfiles（跳过工具安装）
./bin/dotfiles sync --dotfiles

# 只同步指定工具
./bin/dotfiles sync --only git,ripgrep

# 预览变更（不实际执行）
./bin/dotfiles sync --dry-run

# 跳过 mise 运行时（CI 环境推荐）
./bin/dotfiles sync --skip-runtimes

# 查看下载缓存状态
./bin/dotfiles cache status

# 运行单元测试
./bin/dotfiles test
```

---

## 工具管理（`tools.yaml`）

### 当前已配置工具

| 工具 | 说明 | Ubuntu | macOS | Windows |
|------|------|--------|-------|---------|
| zsh | Z Shell | apt | brew | manual (WSL) |
| starship | 跨 shell 提示符 | script | brew | winget |
| git | 版本控制 | apt | brew | winget |
| gh | GitHub CLI | apt | brew | winget |
| docker | 容器平台 | script | brew cask | winget |
| **mise** | 多语言版本管理器（替代 nvm/pyenv） | script | brew | winget |
| fzf | 模糊查找 | apt | brew | winget |
| ripgrep | 快速 grep（rg） | apt | brew | winget |
| bat | 带语法高亮的 cat | apt | brew | winget |
| eza | 现代 ls 替代品 | deb repo | brew | winget |
| **yazi** | 终端文件管理器 | GitHub release | brew | winget |
| **zellij** | 终端工作区/多路复用器 | GitHub release | brew | manual (WSL) |
| fd | 用户友好的 find 替代品 | apt | brew | winget |
| tmux | 终端复用器 | apt | brew | manual (WSL) |
| jq | JSON 处理器 | apt | brew | winget |
| curl / wget | 网络下载工具 | apt | brew | — |
| ghostty | 终端模拟器 | — | brew cask | — |
| iterm2 | macOS 终端替代品 | — | brew cask | — |

**mise 管理的运行时：**

| 运行时 | 版本 |
|--------|------|
| Java | latest |
| Python | latest |
| Node.js | lts |
| Rust | latest |
| CMake | latest |

### 添加新工具

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

然后同步：
```bash
./bin/dotfiles sync
# 或只同步单个工具：
./bin/dotfiles sync --only lazygit
```

### 安装方式（method）说明

| method | 说明 |
|--------|------|
| `apt` / `brew` / `winget` | 包管理器直接安装 |
| `script` | 下载远程脚本执行（支持 `script_args` 传参） |
| `script` + `install_type: tar_binary` | 下载 tar.gz，提取指定二进制到 `/usr/local/bin` |
| `script` + `install_type: zip_binary` | 下载 zip，提取指定二进制到 `/usr/local/bin` |
| `script` + `install_type: eza_deb` | 通过官方 deb 仓库安装 eza（Ubuntu 专用） |
| `manual` | 打印手动安装说明，跳过自动安装 |

示例（tar.gz 二进制安装）：
```yaml
  - name: zellij
    platforms:
      ubuntu:
        method: script
        script: "https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz"
        install_type: tar_binary
        binary: zellij
```

### 标记废弃工具

```yaml
  - name: exa
    deprecated: true
    replaced_by: eza
    migration_note: "exa 已停止维护，请将别名 'ls=exa' 改为 'ls=eza'"
    platforms:
      ubuntu:
        method: apt
        install: exa
```

下次同步时，系统会：
1. 警告 `exa` 已废弃
2. 自动安装 `eza` 作为替代品
3. 打印迁移说明

---

## dotfiles 管理（chezmoi）

本项目使用 [chezmoi](https://www.chezmoi.io/) 管理 dotfiles。

### 工作原理

```
dotfiles 仓库（source）  →  chezmoi apply  →  $HOME（target）
dot_zshrc.tmpl          →                →  ~/.zshrc
dot_gitconfig.tmpl      →                →  ~/.gitconfig
dot_vimrc               →                →  ~/.vimrc
```

### 模板变量

在 `.tmpl` 文件中可使用 chezmoi 模板语法：

```
{{ .chezmoi.data.git_name }}   # 来自 ~/.config/chezmoi/chezmoi.toml
{{ .chezmoi.os }}              # 操作系统类型
```

初始化时 `bootstrap.sh` 会引导填写 `chezmoi.toml`：

```toml
[data]
  git_name  = "Your Name"
  git_email = "you@example.com"
```

### 手动应用 dotfiles

```bash
chezmoi apply
```

### 编辑 dotfiles

```bash
# 编辑 source 文件（推荐）
chezmoi edit ~/.zshrc

# 或直接编辑仓库文件
vim ~/dotfiles/dot_zshrc.tmpl

# 应用变更
chezmoi apply
```

---

## Secrets 管理

### 工作原理

```
secrets.template.env   ← 已提交到 Git（仅占位符）
~/.secrets.local.env   ← gitignored，保留在各机器本地
```

### 在新机器上初始化 Secrets

```bash
./scripts/init_secrets.sh
```

### 检查所有必要 Secrets 是否已设置

```bash
./scripts/init_secrets.sh --check
```

### 添加新 Secret

1. 在 `secrets.template.env` 中添加一行：
   ```
   MY_API_KEY=CHANGE_ME|该 key 的用途说明|yes
   ```
2. 提交模板变更
3. 在每台机器上运行 `./scripts/init_secrets.sh` 填入真实值

---

## 跨机器同步

```
机器 A                       Git Remote               机器 B
──────                       ──────────               ──────
修改 tools.yaml         →    git push            →    bootstrap.sh --pull
修改 dotfiles           →    git push            →    bootstrap.sh --pull
更新 secrets 模板       →    git push            →    init_secrets.sh
```

**工作流：**
1. 在机器 A 上做修改
2. `git add . && git commit -m "..." && git push`
3. 在机器 B 上：`cd ~/dotfiles && ./bootstrap.sh --pull`

---

## 安全说明

- `secrets.local.env` **永远不会提交**（由 `.gitignore` 强制执行）
- **pre-commit hook** 在每次提交前扫描常见敏感信息模式
- 配置模板使用 `{{PLACEHOLDER}}` 语法 — 真实值保留在本地
- 紧急情况绕过 hook：`git commit --no-verify`（谨慎使用）

---

## 故障排查

| 问题 | 解决方案 |
|------|----------|
| `yq: command not found` | 运行 `./bin/dotfiles sync`，会自动安装 yq |
| 工具已安装但 sync 仍尝试重装 | 检查 `tools.yaml` 中的 `check_cmd` 字段 |
| mise runtimes 安装失败（GitHub rate limit） | 等待 rate limit 重置，或使用 `--skip-runtimes` 跳过 |
| cmake 安装失败（rate limit） | cmake 通过 GitHub API 获取版本，rate limit 时会失败，属非致命错误 |
| symlink 创建失败 | 检查文件权限，或以 `sudo` 运行 |
| Secret 误报 | 在 `lib/secret_check.sh` 的 `SECRET_SKIP_PATTERNS` 中添加例外 |
| 重新运行 secrets 向导 | `./scripts/init_secrets.sh` |
| 环境检查 | `./bin/dotfiles doctor` 查看详细诊断报告 |
| 清理下载缓存 | `./bin/dotfiles cache clear` |
