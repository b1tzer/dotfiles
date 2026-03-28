# dotfiles — Cross-platform Dev Environment Manager

One command to set up any new machine. Git-tracked, platform-aware, secret-safe.

```bash
curl -fsSL https://raw.githubusercontent.com/b1tzer/dotfiles/main/install.sh | sh
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

## 新手入门

> 如果你是第一次接触这个项目，从这里开始。

### 这个项目是做什么的？

你是否遇到过这些情况：

- 换了新电脑，要花半天重新装工具、配 git、调 shell
- 公司机器和家里机器的环境不一致，alias 记不住
- 不小心把 GitHub Token 提交到了 Git 仓库

这个项目解决的就是这些问题。**一条命令，在任何新机器上还原你的完整开发环境。**

---

### 第一步：Fork 这个仓库

点击 GitHub 右上角的 **Fork**，把仓库复制到你自己的账号下。

> 为什么要 Fork？因为你需要把自己的配置（工具列表、dotfiles）提交到 Git，所以必须有一个属于你自己的仓库。

---

### 第二步：一键安装

运行以下命令，自动完成 clone、环境配置和工具安装：

```bash
curl -fsSL https://raw.githubusercontent.com/b1tzer/dotfiles/main/install.sh | sh
```

安装脚本会自动完成：
1. 将仓库 clone 到 `~/.dotfiles`
2. 将 `dotfiles` 命令写入 `~/.zshrc` / `~/.bashrc`，使其全局可用
3. 检测当前操作系统（Ubuntu / macOS / Windows WSL）
4. 安装 `tools.yaml` 中声明的所有工具
5. 通过 chezmoi 将 dotfiles 链接到 `$HOME`

> **本地执行（已 clone 的情况）：**
> ```bash
> bash ~/.dotfiles/install.sh
> ```

---

### 第三步：重载 shell

```bash
exec $SHELL
```

完成！你的终端现在应该已经有了 starship 提示符、eza、bat 等工具，并且可以直接使用 `dotfiles` 命令。

---

### 换新机器时怎么做？

```bash
# 在新机器上，只需要这一条命令：
curl -fsSL https://raw.githubusercontent.com/b1tzer/dotfiles/main/install.sh | sh
```

---

### 想修改工具列表？

编辑 `tools.yaml`，添加或删除工具，然后：

```bash
./bin/dotfiles sync        # 同步所有工具
# 或者只同步新加的工具：
./bin/dotfiles sync --only <工具名>
```

---

### 想修改 shell 配置（.zshrc）？

```bash
# 编辑模板文件
vim ~/dotfiles/dot_zshrc.tmpl

# 应用到 $HOME/.zshrc
chezmoi apply

# 重载
exec $SHELL
```

---

### 常用命令速查

| 场景 | 命令 |
|------|------|
| 新机器初始化 | `./bin/dotfiles sync` |
| 拉取最新配置并同步 | `./bin/dotfiles update` |
| 检查环境是否正常 | `./bin/dotfiles doctor` |
| 只装工具，不动 dotfiles | `./bin/dotfiles sync --tools` |
| 只链接 dotfiles，不装工具 | `./bin/dotfiles sync --dotfiles` |
| 预览会做什么（不实际执行） | `./bin/dotfiles sync --dry-run` |

---

## Quick Start

### 新机器初始化（推荐）

```bash
# 一键安装：clone + 写入 PATH + 安装工具 + 链接 dotfiles
curl -fsSL https://raw.githubusercontent.com/b1tzer/dotfiles/main/install.sh | sh

# 重载 shell
exec $SHELL
```

安装完成后，`dotfiles` 命令即可全局使用：

```bash
dotfiles sync      # 同步工具和配置
dotfiles update    # 拉取最新配置并同步
dotfiles doctor    # 检查环境健康状态
```

### 安装选项

```bash
# 仅 clone，不运行 sync（手动控制安装节奏）
curl -fsSL <install-url> | sh -s -- --no-sync

# 指定自定义安装目录（默认 ~/.dotfiles）
curl -fsSL <install-url> | sh -s -- --dir ~/my-dotfiles

# 本地执行（已有仓库时）
bash ~/.dotfiles/install.sh
```

### 同步最新配置到已有机器

```bash
dotfiles update          # git pull --ff-only + sync
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
|------|------|--------|-------|------|
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
| **lazygit** | 终端 Git TUI | apt | brew | winget |
| **delta** | git diff 语法高亮增强 | GitHub release | brew | winget |
| git-lfs | Git 大文件存储 | apt | brew | winget |
| **btop** | 现代 top/htop 替代品 | apt | brew | winget |
| dust | 直观磁盘使用分析（du 替代） | GitHub release | brew | winget |
| procs | 现代 ps 替代品 | GitHub release | brew | winget |
| **xh** | 现代 HTTP 客户端（curl 友好替代） | GitHub release | brew | winget |
| dog | 现代 DNS 查询工具（dig 替代） | GitHub release | brew | — |
| bandwhich | 终端带宽监控 | GitHub release | brew | winget |
| **zoxide** | 智能 cd（记忆常用目录） | script | brew | winget |
| **atuin** | shell 历史记录增强（跨机器同步） | script | brew | winget |
| **tealdeer** | tldr 的 Rust 重写版（命令：`tldr`） | GitHub release | brew | winget |
| navi | 交互式 cheatsheet 工具 | GitHub release | brew | winget |
| tokei | 代码行数统计 | GitHub release | brew | winget |
| hyperfine | 命令行基准测试工具 | GitHub release | brew | winget |
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

## Alias 配置（`dot_aliases.sh`）

本项目通过 `dot_aliases.sh` 统一管理所有 alias，chezmoi 将其链接到 `~/.aliases.sh`，并在 `~/.zshrc` 中自动加载。

### 现代命令替代

| Alias | 替代命令 | 依赖工具 | 说明 |
|-------|---------|---------|------|
| `ls` | `eza --color=auto --group-directories-first` | eza | 带颜色和目录优先排序 |
| `ll` | `eza -lh --git` | eza | 详细列表，显示 git 状态 |
| `la` | `eza -lah --git` | eza | 含隐藏文件的详细列表 |
| `lt` | `eza --tree` | eza | 树形目录视图 |
| `cat` | `bat --paging=never` | bat | 带语法高亮的文件查看 |
| `grep` | `rg` | ripgrep | 快速全文搜索 |
| `find` | `fd` | fd | 用户友好的文件查找 |
| `du` | `dust` | dust | 直观的磁盘使用分析 |
| `top` | `btop` | btop | 现代系统监控 |
| `ps` | `procs` | procs | 现代进程查看 |
| `z <dir>` | `zoxide <dir>` | zoxide | 智能跳转到常用目录 |
| `zi` | `zoxide query -i` | zoxide + fzf | 交互式目录跳转 |

> 所有替代 alias 均使用 `command -v` 检测工具是否已安装，未安装时自动跳过，不影响 shell 启动。

### Git 快捷 alias

| Alias | 完整命令 | 说明 |
|-------|---------|------|
| `g` | `git` | git 缩写 |
| `gs` | `git status` | 查看工作区状态 |
| `ga` | `git add` | 暂存文件 |
| `gc` | `git commit` | 提交 |
| `gp` | `git push` | 推送 |
| `gl` | `git pull` | 拉取 |
| `gd` | `git diff`（delta 增强） | 查看差异，若 delta 已安装自动启用语法高亮 |
| `glog` | `git log --oneline --color --graph --decorate` | 美化的提交历史图 |
| `lg` | `lazygit` | 打开 lazygit TUI（需已安装） |

### 目录导航 alias

| Alias | 命令 | 说明 |
|-------|------|------|
| `..` | `cd ..` | 返回上一级 |
| `...` | `cd ../..` | 返回两级 |
| `....` | `cd ../../..` | 返回三级 |
| `~` | `cd ~` | 回到 Home |
| `dotfiles` | `cd ~/dotfiles` | 快速进入 dotfiles 目录 |

### 系统操作 alias / 函数

| Alias | 说明 |
|-------|------|
| `reload` | 重载当前 shell（`exec $SHELL`） |
| `path` | 格式化打印 `$PATH`，每行一个 |
| `myip` | 查询本机公网 IP |
| `ports` | 列出当前监听端口 |
| `mkcd <dir>` | 创建目录并立即进入 |

### 修改 alias

```bash
# 编辑 alias 文件
vim ~/dotfiles/dot_aliases.sh

# 应用到 $HOME
chezmoi apply

# 重载 shell 使其生效
reload
```

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
