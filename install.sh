#!/usr/bin/env bash
# =============================================================================
# install.sh - dotfiles 一键安装脚本
# =============================================================================
# 用法（推荐）：
#   curl -fsSL https://raw.githubusercontent.com/<你的用户名>/dotfiles/main/install.sh | sh
#
# 或者克隆后本地执行：
#   bash install.sh
#   bash install.sh --repo https://github.com/<你的用户名>/dotfiles.git
#   bash install.sh --dir ~/.dotfiles --no-sync
#
# 安装内容：
#   1. 将仓库 clone 到 ~/.dotfiles（可通过 --dir 自定义）
#   2. 将 ~/.dotfiles/bin 写入 PATH（写入 ~/.zshrc 或 ~/.bashrc）
#   3. 可选：立即运行 dotfiles sync 完成工具安装和 dotfiles 链接
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# 颜色输出
# -----------------------------------------------------------------------------
_tty_red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
_tty_green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
_tty_yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
_tty_bold()   { printf '\033[1m%s\033[0m\n'    "$*"; }
_tty_cyan()   { printf '\033[0;36m%s\033[0m\n' "$*"; }

_info()  { printf '  \033[0;36m→\033[0m  %s\n' "$*"; }
_ok()    { printf '  \033[0;32m✓\033[0m  %s\n' "$*"; }
_warn()  { printf '  \033[1;33m⚠\033[0m  %s\n' "$*" >&2; }
_error() { printf '  \033[0;31m✗\033[0m  %s\n' "$*" >&2; }
_step()  { printf '\n\033[1m  ▶  %s\033[0m\n' "$*"; }

# -----------------------------------------------------------------------------
# 默认配置（可通过参数覆盖）
# -----------------------------------------------------------------------------
DOTFILES_REPO="${DOTFILES_REPO:-__DOTFILES_REPO__}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"  # 安装目录
NO_SYNC=false                               # 跳过 dotfiles sync
NO_SHELL_SETUP=false                        # 跳过写入 shell 配置

# -----------------------------------------------------------------------------
# 解析参数
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)        DOTFILES_REPO="$2"  ; shift 2 ;;
    --dir)         DOTFILES_DIR="$2"   ; shift 2 ;;
    --no-sync)     NO_SYNC=true        ; shift   ;;
    --no-shell)    NO_SHELL_SETUP=true ; shift   ;;
    -h|--help)
      cat <<EOF

$(tput bold 2>/dev/null || true)dotfiles 一键安装脚本$(tput sgr0 2>/dev/null || true)

用法：
  curl -fsSL <install-url> | sh
  bash install.sh [选项]

选项：
  --repo <url>    指定仓库地址（默认从脚本内读取）
  --dir  <path>   安装目录（默认：~/.dotfiles）
  --no-sync       仅 clone，不运行 dotfiles sync
  --no-shell      不修改 shell 配置文件
  -h, --help      显示帮助

环境变量：
  DOTFILES_REPO   仓库地址（同 --repo）
  DOTFILES_DIR    安装目录（同 --dir）

EOF
      exit 0
      ;;
    *) _warn "未知参数：$1，已忽略" ; shift ;;
  esac
done

# -----------------------------------------------------------------------------
# 检测仓库地址
# -----------------------------------------------------------------------------
# 如果脚本是从 GitHub raw URL 下载的，自动推断仓库地址
if [[ -z "$DOTFILES_REPO" ]]; then
  # 尝试从脚本所在目录推断（本地执行时）
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
  if [[ -n "$SCRIPT_DIR" && -d "$SCRIPT_DIR/.git" ]]; then
    DOTFILES_REPO="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"
  fi
fi

if [[ -z "$DOTFILES_REPO" ]]; then
  _error "未指定仓库地址。请通过以下方式之一提供："
  _error "  1. 环境变量：DOTFILES_REPO=https://github.com/你的用户名/dotfiles.git bash install.sh"
  _error "  2. 参数：bash install.sh --repo https://github.com/你的用户名/dotfiles.git"
  exit 1
fi

# -----------------------------------------------------------------------------
# 打印欢迎信息
# -----------------------------------------------------------------------------
echo
_tty_bold "  ╔══════════════════════════════════════════════════╗"
_tty_bold "  ║         dotfiles 一键安装程序                   ║"
_tty_bold "  ╚══════════════════════════════════════════════════╝"
echo
_info "仓库地址  : $DOTFILES_REPO"
_info "安装目录  : $DOTFILES_DIR"
_info "运行同步  : $( [[ "$NO_SYNC" == "true" ]] && echo "否" || echo "是" )"
echo

# -----------------------------------------------------------------------------
# 前置检查
# -----------------------------------------------------------------------------
_step "检查依赖"

_check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    _error "缺少必要命令：$1"
    _error "请先安装后重试。"
    exit 1
  fi
  _ok "$1 已就绪"
}

_check_cmd git
_check_cmd curl

# -----------------------------------------------------------------------------
# Step 1：Clone 仓库
# -----------------------------------------------------------------------------
_step "克隆仓库到 $DOTFILES_DIR"

if [[ -d "$DOTFILES_DIR" ]]; then
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    _warn "目录已存在且是 git 仓库，执行 git pull 更新..."
    git -C "$DOTFILES_DIR" pull --ff-only
    _ok "仓库已更新"
  else
    _error "目录 $DOTFILES_DIR 已存在但不是 git 仓库。"
    _error "请手动删除后重试：rm -rf $DOTFILES_DIR"
    exit 1
  fi
else
  git clone --depth=1 "$DOTFILES_REPO" "$DOTFILES_DIR"
  _ok "仓库已克隆到 $DOTFILES_DIR"
fi

# -----------------------------------------------------------------------------
# Step 2：确保 bin/dotfiles 可执行
# -----------------------------------------------------------------------------
_step "设置可执行权限"

BIN_DIR="$DOTFILES_DIR/bin"
if [[ -f "$BIN_DIR/dotfiles" ]]; then
  chmod +x "$BIN_DIR/dotfiles"
  _ok "bin/dotfiles 已设置可执行权限"
else
  _warn "未找到 $BIN_DIR/dotfiles，跳过权限设置"
fi

# -----------------------------------------------------------------------------
# Step 3：写入 shell 配置文件
# -----------------------------------------------------------------------------
_step "配置 shell 环境"

# 需要写入的内容
SHELL_SNIPPET="# dotfiles - 由 install.sh 自动添加
export DOTFILES_DIR=\"$DOTFILES_DIR\"
export PATH=\"\$DOTFILES_DIR/bin:\$PATH\""

# 检测当前 shell 并确定配置文件
_detect_shell_rc() {
  local shell_name
  shell_name="$(basename "${SHELL:-sh}")"

  case "$shell_name" in
    zsh)  echo "$HOME/.zshrc"  ;;
    bash) echo "$HOME/.bashrc" ;;
    *)
      # 回退：优先 .zshrc，其次 .bashrc，最后 .profile
      if [[ -f "$HOME/.zshrc" ]]; then
        echo "$HOME/.zshrc"
      elif [[ -f "$HOME/.bashrc" ]]; then
        echo "$HOME/.bashrc"
      else
        echo "$HOME/.profile"
      fi
      ;;
  esac
}

if [[ "$NO_SHELL_SETUP" == "true" ]]; then
  _warn "已跳过 shell 配置（--no-shell）"
  _warn "请手动将以下内容添加到你的 shell 配置文件："
  echo
  echo "$SHELL_SNIPPET"
  echo
else
  SHELL_RC="$(_detect_shell_rc)"

  # 检查是否已写入（避免重复）
  if grep -qF 'DOTFILES_DIR' "$SHELL_RC" 2>/dev/null; then
    _ok "shell 配置已存在，跳过写入（$SHELL_RC）"
  else
    # 追加到配置文件
    printf '\n%s\n' "$SHELL_SNIPPET" >> "$SHELL_RC"
    _ok "已写入 $SHELL_RC"
  fi

  # 同时写入 .zshrc（如果当前是 bash 但 .zshrc 存在）
  if [[ "$SHELL_RC" != "$HOME/.zshrc" && -f "$HOME/.zshrc" ]]; then
    if ! grep -qF 'DOTFILES_DIR' "$HOME/.zshrc" 2>/dev/null; then
      printf '\n%s\n' "$SHELL_SNIPPET" >> "$HOME/.zshrc"
      _ok "同时写入 ~/.zshrc"
    fi
  fi
fi

# 让当前 shell 立即生效（source 对 pipe 执行无效，但本地执行时有用）
export DOTFILES_DIR="$DOTFILES_DIR"
export PATH="$DOTFILES_DIR/bin:$PATH"

# -----------------------------------------------------------------------------
# Step 4：运行 dotfiles sync
# -----------------------------------------------------------------------------
if [[ "$NO_SYNC" == "true" ]]; then
  _warn "已跳过 dotfiles sync（--no-sync）"
  _warn "安装完成后请手动运行：dotfiles sync"
else
  _step "运行 dotfiles sync"
  "$BIN_DIR/dotfiles" sync
fi

# -----------------------------------------------------------------------------
# 完成提示
# -----------------------------------------------------------------------------
echo
_tty_bold "  ╔══════════════════════════════════════════════════╗"
_tty_bold "  ║              安装完成！                         ║"
_tty_bold "  ╚══════════════════════════════════════════════════╝"
echo
_tty_green "  dotfiles 已安装到：$DOTFILES_DIR"
echo
_tty_cyan  "  下一步："
echo "    1. 重载 shell 使 PATH 生效："
echo "         exec \$SHELL"
echo
echo "    2. 之后即可直接使用 dotfiles 命令："
echo "         dotfiles sync       # 同步工具和配置"
echo "         dotfiles update     # 拉取最新配置并同步"
echo "         dotfiles doctor     # 检查环境健康状态"
echo
