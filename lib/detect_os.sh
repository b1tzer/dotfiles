#!/usr/bin/env bash
# =============================================================================
# lib/detect_os.sh - 操作系统检测模块
# =============================================================================
# 检测当前操作系统并导出以下变量：
#   OS_TYPE   : ubuntu | macos | windows（未知时为 unknown）
#   OS_ARCH   : amd64 | arm64 | unknown
#   IS_WSL    : true | false
#
# 使用方式：
#   source "$REPO_ROOT/lib/detect_os.sh"
#   detect_os_assert_supported || exit 1
# =============================================================================

# 防止重复 source
[[ -n "${_DETECT_OS_SH_LOADED:-}" ]] && return 0
_DETECT_OS_SH_LOADED=1

# ---------------------------------------------------------------------------
# 检测 OS 类型
# ---------------------------------------------------------------------------
_detect_os_type() {
  local uname_s
  uname_s="$(uname -s 2>/dev/null || echo 'unknown')"

  case "$uname_s" in
    Linux*)
      # 检查是否为 WSL
      if grep -qi microsoft /proc/version 2>/dev/null; then
        IS_WSL="true"
      else
        IS_WSL="false"
      fi
      # 检查发行版
      if [[ -f /etc/os-release ]]; then
        local id
        id="$(. /etc/os-release && echo "${ID:-unknown}")"
        case "$id" in
          ubuntu|debian) OS_TYPE="ubuntu" ;;
          *)             OS_TYPE="ubuntu" ;;  # 默认按 ubuntu 处理（apt 系）
        esac
      else
        OS_TYPE="ubuntu"
      fi
      ;;
    Darwin*)
      OS_TYPE="macos"
      IS_WSL="false"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      OS_TYPE="windows"
      IS_WSL="false"
      ;;
    *)
      OS_TYPE="unknown"
      IS_WSL="false"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 检测 CPU 架构
# ---------------------------------------------------------------------------
_detect_os_arch() {
  local uname_m
  uname_m="$(uname -m 2>/dev/null || echo 'unknown')"

  case "$uname_m" in
    x86_64|amd64)   OS_ARCH="amd64" ;;
    aarch64|arm64)  OS_ARCH="arm64" ;;
    *)              OS_ARCH="unknown" ;;
  esac
}

# ---------------------------------------------------------------------------
# 执行检测并导出变量
# ---------------------------------------------------------------------------
OS_TYPE=""
OS_ARCH=""
IS_WSL="false"

_detect_os_type
_detect_os_arch

export OS_TYPE
export OS_ARCH
export IS_WSL

# ---------------------------------------------------------------------------
# 断言：当前 OS 受支持，否则输出 actionable error 并返回 1
# ---------------------------------------------------------------------------
detect_os_assert_supported() {
  case "$OS_TYPE" in
    ubuntu|macos)
      return 0
      ;;
    windows)
      printf "  [!]  Windows 原生环境暂不完全支持。\n" >&2
      printf "       建议使用 WSL2（Ubuntu）运行本工具。\n" >&2
      return 1
      ;;
    unknown|*)
      printf "  [✗]  error: unsupported operating system '%s'\n" "$(uname -s 2>/dev/null || echo unknown)" >&2
      printf "         hint:  This tool supports Ubuntu/Debian Linux and macOS.\n" >&2
      return 1
      ;;
  esac
}

# Helper: print OS info
detect_os_info() {
  echo "OS_TYPE : $OS_TYPE"
  echo "OS_ARCH : $OS_ARCH"
  echo "IS_WSL  : $IS_WSL"
}

# Run info if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  detect_os_info
fi
