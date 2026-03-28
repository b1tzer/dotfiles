#!/usr/bin/env bash
# =============================================================================
# lib/logging.sh - 统一日志输出模块
# =============================================================================
# 提供 _info / _ok / _warn / _error / _skip / _section 函数。
# 自动检测 NO_COLOR 环境变量和 TTY 状态，决定是否输出 ANSI 颜色。
#
# 使用方式：
#   source "$REPO_ROOT/lib/logging.sh"
# =============================================================================

# 防止重复 source
[[ -n "${_LOGGING_SH_LOADED:-}" ]] && return 0
_LOGGING_SH_LOADED=1

# ---------------------------------------------------------------------------
# 颜色开关：NO_COLOR 标准 (https://no-color.org) + 非 TTY 自动禁色
# ---------------------------------------------------------------------------
_logging_use_color() {
  # 若设置了 NO_COLOR（任意值），禁色
  [[ -n "${NO_COLOR:-}" ]] && return 1
  # 若 stdout 不是 TTY，禁色
  [[ -t 1 ]] || return 1
  return 0
}

if _logging_use_color; then
  _CLR_RED='\033[0;31m'
  _CLR_GREEN='\033[0;32m'
  _CLR_YELLOW='\033[1;33m'
  _CLR_BLUE='\033[0;34m'
  _CLR_CYAN='\033[0;36m'
  _CLR_BOLD='\033[1m'
  _CLR_NC='\033[0m'
else
  _CLR_RED=''
  _CLR_GREEN=''
  _CLR_YELLOW=''
  _CLR_BLUE=''
  _CLR_CYAN=''
  _CLR_BOLD=''
  _CLR_NC=''
fi

# ---------------------------------------------------------------------------
# 日志函数
# 格式：  [符号]  消息内容（两空格缩进，符号后两空格）
# ---------------------------------------------------------------------------

# 普通信息（蓝色 i）
_info() {
  printf "  ${_CLR_BLUE}[i]${_CLR_NC}  %s\n" "$*"
}

# 成功（绿色 ✓）
_ok() {
  printf "  ${_CLR_GREEN}[✓]${_CLR_NC}  %s\n" "$*"
}

# 警告（黄色 !），输出到 stderr
_warn() {
  printf "  ${_CLR_YELLOW}[!]${_CLR_NC}  %s\n" "$*" >&2
}

# 错误（红色 ✗），输出到 stderr
_error() {
  printf "  ${_CLR_RED}[✗]${_CLR_NC}  %s\n" "$*" >&2
}

# 跳过（青色 ⊘）
_skip() {
  printf "  ${_CLR_CYAN}[⊘]${_CLR_NC}  %s\n" "$*"
}

# 章节标题（粗体分隔线）
_section() {
  printf "\n  ${_CLR_BOLD}━━━ %s ━━━${_CLR_NC}\n" "$*"
}

# 横幅（用于脚本开头）
_banner() {
  local title="$1"
  printf "\n${_CLR_BOLD}${_CLR_BLUE}╔══════════════════════════════════════════════════════╗${_CLR_NC}\n"
  printf "${_CLR_BOLD}${_CLR_BLUE}║${_CLR_NC}  %s\n" "$title"
  printf "${_CLR_BOLD}${_CLR_BLUE}╚══════════════════════════════════════════════════════╝${_CLR_NC}\n"
}

# Actionable 错误（error + cause + hint 三段式）
_error_actionable() {
  local what="$1"
  local cause="${2:-}"
  local hint="${3:-}"
  printf "  ${_CLR_RED}[✗]${_CLR_NC}  error: %s\n" "$what" >&2
  [[ -n "$cause" ]] && printf "         cause: %s\n" "$cause" >&2
  [[ -n "$hint"  ]] && printf "         hint:  %s\n" "$hint"  >&2
}
