# =============================================================================
# ~/.aliases.sh - 统一 alias 配置
# =============================================================================
# 由 dotfiles 仓库管理，chezmoi 软链接到 ~/.aliases.sh
# 在 ~/.zshrc 中通过以下方式加载：
#   [[ -f ~/.aliases.sh ]] && source ~/.aliases.sh
# =============================================================================

# -----------------------------------------------------------------------------
# 现代命令替代
# -----------------------------------------------------------------------------

# eza - 现代 ls 替代品（带颜色、图标、git 状态）
if command -v eza &>/dev/null; then
  alias ls='eza --color=auto --group-directories-first'
  alias ll='eza -lh --color=auto --group-directories-first --git'
  alias la='eza -lah --color=auto --group-directories-first --git'
  alias lt='eza --tree --color=auto --group-directories-first'
fi

# bat - 带语法高亮的 cat
if command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
fi

# ripgrep - 快速 grep 替代
if command -v rg &>/dev/null; then
  alias grep='rg'
fi

# fd - 用户友好的 find 替代
if command -v fd &>/dev/null; then
  alias find='fd'
fi

# dust - 直观的磁盘使用分析
if command -v dust &>/dev/null; then
  alias du='dust'
fi

# btop - 现代系统监控
if command -v btop &>/dev/null; then
  alias top='btop'
fi

# procs - 现代 ps 替代
if command -v procs &>/dev/null; then
  alias ps='procs'
fi

# -----------------------------------------------------------------------------
# zoxide 初始化 - 智能 cd（记忆常用目录）
# -----------------------------------------------------------------------------
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
  alias zi='zoxide query -i'  # 交互式跳转（配合 fzf）
fi

# -----------------------------------------------------------------------------
# Git 快捷 alias
# -----------------------------------------------------------------------------
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --color --graph --decorate'

# gd: 若 delta 已安装则使用 delta 增强 diff 输出
if command -v delta &>/dev/null; then
  alias gd='git -c core.pager=delta diff'
else
  alias gd='git diff'
fi

# lg: 若 lazygit 已安装则提供快捷入口
if command -v lazygit &>/dev/null; then
  alias lg='lazygit'
fi

# -----------------------------------------------------------------------------
# 目录导航 alias
# -----------------------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias dotfiles='cd ~/dotfiles'

# -----------------------------------------------------------------------------
# 系统操作 alias / 函数
# -----------------------------------------------------------------------------

# 重载当前 shell
alias reload='exec $SHELL'

# 格式化打印 $PATH，每行一个
alias path='echo $PATH | tr ":" "\n"'

# 查询本机公网 IP
alias myip='curl -s https://api.ipify.org && echo'

# 列出当前监听端口
alias ports='ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null'

# 创建目录并进入
mkcd() {
  mkdir -p "$1" && cd "$1"
}
