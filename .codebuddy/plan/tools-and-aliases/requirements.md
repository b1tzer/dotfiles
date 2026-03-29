# 需求文档：扩充工具清单与 alias 配置

## 引言

当前 `tools.yaml` 已覆盖基础开发工具，但日常工作中还有大量高频使用的效率工具尚未纳入管理。同时，项目目前缺少统一的 alias 配置文件，导致每台机器的命令习惯不一致。

本需求旨在：
1. 向 `tools.yaml` 补充日常开发高频工具（Git 增强、系统监控、网络调试、AI 辅助等）
2. 在 dotfiles 中新增 `dot_aliases.sh`，统一管理常用 alias
3. 在 `.zshrc` 中自动 source alias 文件，确保跨机器一致

---

## 需求

### 需求 1：Git 工作流增强工具

**用户故事：** 作为一名开发者，我希望有更直观的 Git 操作工具，以便减少记忆复杂 git 命令的负担，提升代码审查和提交效率。

#### 验收标准

1. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `lazygit`（终端 Git TUI，支持 Ubuntu/macOS/Windows）
2. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `delta`（git diff 语法高亮增强，支持 Ubuntu/macOS/Windows）
3. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `git-lfs`（大文件存储支持，支持 Ubuntu/macOS/Windows）
4. IF `tools.yaml` 中已存在同名工具 THEN 系统 SHALL 跳过重复安装

---

### 需求 2：系统监控与进程管理工具

**用户故事：** 作为一名开发者，我希望有现代化的系统监控工具，以便快速定位性能瓶颈和资源占用问题。

#### 验收标准

1. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `btop`（现代 top/htop 替代品，支持 Ubuntu/macOS/Windows）
2. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `dust`（直观的磁盘使用分析，`du` 替代品，支持 Ubuntu/macOS/Windows）
3. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `procs`（现代 `ps` 替代品，支持 Ubuntu/macOS/Windows）

---

### 需求 3：网络调试工具

**用户故事：** 作为一名后端/全栈开发者，我希望有强大的网络调试工具，以便快速测试 API、排查网络问题。

#### 验收标准

1. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `httpie` 或 `xh`（现代 HTTP 客户端，`curl` 的友好替代，支持 Ubuntu/macOS/Windows）
2. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `dog`（现代 DNS 查询工具，`dig` 替代品，支持 Ubuntu/macOS）
3. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `bandwhich`（终端带宽监控，支持 Ubuntu/macOS/Windows）

---

### 需求 4：开发效率工具

**用户故事：** 作为一名开发者，我希望有提升日常编码效率的 CLI 工具，以便减少重复操作、加快工作流。

#### 验收标准

1. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `zoxide`（智能 `cd` 替代品，记忆常用目录，支持 Ubuntu/macOS/Windows）
2. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `atuin`（shell 历史记录增强，支持跨机器同步，支持 Ubuntu/macOS/Windows）
3. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `tealdeer`（`tldr` 的 Rust 重写版，兼容 tldr 页面、启动极快，支持 Ubuntu/macOS/Windows；命令为 `tldr`）
4. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `navi`（交互式 cheatsheet 工具，支持自定义 cheatsheet，支持 Ubuntu/macOS/Windows）
4. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `tokei`（代码行数统计，支持 Ubuntu/macOS/Windows）
5. WHEN 用户运行 `./bin/dotfiles sync` THEN 系统 SHALL 安装 `hyperfine`（命令行基准测试工具，支持 Ubuntu/macOS/Windows）

---

### 需求 5：统一 alias 配置文件

**用户故事：** 作为一名开发者，我希望有一个统一管理的 alias 文件，以便在所有机器上保持一致的命令习惯，不再重复配置。

#### 验收标准

1. WHEN 项目初始化 THEN 系统 SHALL 在 dotfiles 目录下创建 `dot_aliases.sh` 文件
2. WHEN `dot_aliases.sh` 存在 THEN `dot_zshrc.tmpl` SHALL 自动 source 该文件（`source ~/.aliases.sh`）
3. IF `~/.aliases.sh` 不存在 THEN shell 启动 SHALL 不报错（使用 `[[ -f ]] && source` 语法）

---

### 需求 6：现代命令替代 alias

**用户故事：** 作为一名开发者，我希望用现代工具替代传统命令，以便获得更好的输出格式、颜色高亮和使用体验。

#### 验收标准

1. WHEN `eza` 已安装 THEN `dot_aliases.sh` SHALL 包含 `ls`、`ll`、`la`、`lt`（tree 视图）的 eza alias
2. WHEN `bat` 已安装 THEN `dot_aliases.sh` SHALL 包含 `cat` → `bat` 的 alias
3. WHEN `ripgrep` 已安装 THEN `dot_aliases.sh` SHALL 包含 `grep` → `rg` 的 alias
4. WHEN `fd` 已安装 THEN `dot_aliases.sh` SHALL 包含 `find` → `fd` 的 alias
5. WHEN `zoxide` 已安装 THEN `dot_aliases.sh` SHALL 包含 `z` 和 `zi`（交互式跳转）的初始化
6. WHEN `dust` 已安装 THEN `dot_aliases.sh` SHALL 包含 `du` → `dust` 的 alias
7. WHEN `btop` 已安装 THEN `dot_aliases.sh` SHALL 包含 `top` → `btop` 的 alias
8. WHEN `procs` 已安装 THEN `dot_aliases.sh` SHALL 包含 `ps` → `procs` 的 alias

---

### 需求 7：Git 快捷 alias

**用户故事：** 作为一名开发者，我希望有常用 git 操作的短命令，以便减少每天重复输入长命令的时间。

#### 验收标准

1. THEN `dot_aliases.sh` SHALL 包含以下 git alias：
   - `g` → `git`
   - `gs` → `git status`
   - `ga` → `git add`
   - `gc` → `git commit`
   - `gp` → `git push`
   - `gl` → `git pull`
   - `gd` → `git diff`（若 delta 已安装则自动使用 delta）
   - `glog` → 美化的 git log（单行、带颜色、带图形）
   - `lg` → `lazygit`（若已安装）

---

### 需求 8：目录导航与系统 alias

**用户故事：** 作为一名开发者，我希望有常用的目录导航和系统操作快捷命令，以便减少日常操作的击键次数。

#### 验收标准

1. THEN `dot_aliases.sh` SHALL 包含目录导航 alias：
   - `..` → `cd ..`
   - `...` → `cd ../..`
   - `....` → `cd ../../..`
   - `~` → `cd ~`
   - `dotfiles` → `cd ~/dotfiles`
2. THEN `dot_aliases.sh` SHALL 包含系统操作 alias：
   - `reload` → `exec $SHELL`（重载 shell）
   - `path` → 格式化打印 `$PATH`（每行一个）
   - `myip` → 查询本机公网 IP
   - `ports` → 列出当前监听端口
   - `mkcd` → 创建目录并进入（函数形式）

---

### 需求 9：README 更新

**用户故事：** 作为一名新用户，我希望 README 中有 alias 配置的说明，以便了解有哪些可用的快捷命令。

#### 验收标准

1. WHEN 新工具和 alias 配置完成 THEN `README.md` SHALL 新增"Alias 配置"章节，列出所有 alias 分类和说明
2. WHEN `tools.yaml` 新增工具 THEN `README.md` 中的工具表格 SHALL 同步更新
