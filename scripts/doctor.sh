#!/usr/bin/env bash
# =============================================================================
# scripts/doctor.sh - 环境健康检查
# =============================================================================
# 检查开发环境的各项状态，类似 brew doctor。
#
# 检查项：
#   1. lib/ 依赖模块是否存在
#   2. tools.yaml 中声明的工具安装状态
#   3. dotfiles 软链接状态
#   4. secrets 配置状态
#
# 退出码：
#   0 - 环境健康（或仅有警告）
#   1 - 发现严重问题
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_YAML="${DOTFILES_TOOLS_YAML:-$REPO_ROOT/tools.yaml}"
DOTFILES_DIR="$REPO_ROOT/dotfiles"

# ---------------------------------------------------------------------------
# 加载 lib 模块（带缺失检测守卫）
# ---------------------------------------------------------------------------
_require_lib() {
  local lib_file="$REPO_ROOT/lib/$1"
  if [[ ! -f "$lib_file" ]]; then
    printf "  [✗]  error: required module 'lib/%s' not found. Is your repo complete?\n" "$1" >&2
    printf "         hint:  Run: git status  to check for missing files.\n" >&2
    exit 127
  fi
  # shellcheck source=/dev/null
  source "$lib_file"
}

_require_lib "logging.sh"
_require_lib "detect_os.sh"
_require_lib "pkg_manager.sh"

# ---------------------------------------------------------------------------
# 问题追踪
# ---------------------------------------------------------------------------
declare -a ISSUES_CRITICAL=()   # 严重问题（退出码 1）
declare -a ISSUES_WARN=()       # 警告（退出码 0）

_issue_critical() {
  ISSUES_CRITICAL+=("$1")
  _error "$1"
  [[ -n "${2:-}" ]] && printf "         hint:  %s\n" "$2" >&2
}

_issue_warn() {
  ISSUES_WARN+=("$1")
  _warn "$1"
  [[ -n "${2:-}" ]] && printf "         hint:  %s\n" "$2" >&2
}

# ---------------------------------------------------------------------------
# 检查 1：lib/ 依赖模块
# ---------------------------------------------------------------------------
_check_lib_modules() {
  _section "Checking lib/ modules"

  local required_modules=("logging.sh" "detect_os.sh" "pkg_manager.sh")
  local all_ok=true

  for mod in "${required_modules[@]}"; do
    local mod_path="$REPO_ROOT/lib/$mod"
    if [[ -f "$mod_path" ]]; then
      _ok "lib/$mod"
    else
      _issue_critical \
        "lib/$mod is missing" \
        "Run: git status  to check for missing files"
      all_ok=false
    fi
  done

  [[ "$all_ok" == "true" ]] && return 0 || return 1
}

# ---------------------------------------------------------------------------
# 检查 2：tools.yaml 中声明的工具
# ---------------------------------------------------------------------------
_check_tools() {
  _section "Checking tool installations"

  if [[ ! -f "$TOOLS_YAML" ]]; then
    _issue_critical \
      "tools.yaml not found at: $TOOLS_YAML" \
      "Run: git status  to check for missing files"
    return 1
  fi

  # 确保 yq 可用
  if ! command -v yq &>/dev/null; then
    _issue_warn \
      "yq not installed — cannot parse tools.yaml" \
      "Run: ./bin/dotfiles sync --only yq  to install yq first"
    return 0
  fi

  local tool_count
  tool_count="$(yq e '.tools | length' "$TOOLS_YAML" 2>/dev/null || echo 0)"

  local i=0
  while [[ "$i" -lt "$tool_count" ]]; do
    local name check_cmd deprecated replaced_by platform_method

    name="$(yq e ".tools[$i].name" "$TOOLS_YAML")"
    check_cmd="$(yq e ".tools[$i].check_cmd // \"$name\"" "$TOOLS_YAML")"
    deprecated="$(yq e ".tools[$i].deprecated // false" "$TOOLS_YAML")"
    replaced_by="$(yq e ".tools[$i].replaced_by // \"\"" "$TOOLS_YAML")"
    platform_method="$(yq e ".tools[$i].platforms.$OS_TYPE.method // \"\"" "$TOOLS_YAML")"

    if [[ "$deprecated" == "true" ]]; then
      if pkg_is_installed "$check_cmd"; then
        _issue_warn \
          "$name is DEPRECATED$([ -n "$replaced_by" ] && echo " (replaced by: $replaced_by)")" \
          "Run: ./bin/dotfiles sync  to auto-migrate to replacement"
      else
        _skip "$name (deprecated, not installed)"
      fi
    elif [[ -z "$platform_method" ]]; then
      _skip "$name (not supported on $OS_TYPE)"
    elif pkg_is_installed "$check_cmd"; then
      _ok "$name"
    else
      _issue_critical \
        "$name is not installed" \
        "Run: ./bin/dotfiles sync --only $name"
    fi

    i=$(( i + 1 ))
  done
}

# ---------------------------------------------------------------------------
# 检查 3：dotfiles 软链接状态
# ---------------------------------------------------------------------------
_check_dotfiles() {
  _section "Checking dotfile symlinks"

  if [[ ! -d "$DOTFILES_DIR" ]]; then
    _issue_critical \
      "dotfiles/ directory not found at: $DOTFILES_DIR" \
      "Run: git status  to check for missing files"
    return 1
  fi

  # 遍历 dotfiles/ 目录中的所有文件
  while IFS= read -r -d '' file; do
    local rel_path="${file#$DOTFILES_DIR/}"

    # 跳过平台特定变体（.macos / .ubuntu / .windows / .linux）
    if [[ "$rel_path" =~ \.(macos|ubuntu|windows|linux)$ ]]; then
      continue
    fi

    local dest="$HOME/$rel_path"
    local rel_dest="${dest/#$HOME\//~/}"

    if [[ -L "$dest" ]]; then
      local current_target
      current_target="$(readlink "$dest")"
      if [[ "$current_target" == "$file" ]]; then
        _ok "$rel_dest → linked"
      else
        _issue_warn \
          "$rel_dest is a symlink to a different target: $current_target" \
          "Run: ./bin/dotfiles sync --dotfiles  to re-link"
      fi
    elif [[ -e "$dest" ]]; then
      _issue_warn \
        "$rel_dest exists but is not a symlink (regular file/dir)" \
        "Run: ./bin/dotfiles sync --dotfiles  to link (will backup existing file)"
    else
      _issue_critical \
        "$rel_dest is not linked" \
        "Run: ./bin/dotfiles sync --dotfiles"
    fi
  done < <(find "$DOTFILES_DIR" -type f -print0 | sort -z)
}

# ---------------------------------------------------------------------------
# 检查 4：secrets 配置状态
# ---------------------------------------------------------------------------
_check_secrets() {
  _section "Checking secrets configuration"

  local secrets_template="$REPO_ROOT/secrets.template.env"
  local secrets_local="$HOME/.secrets.local.env"

  # 检查模板文件
  if [[ ! -f "$secrets_template" ]]; then
    _skip "secrets.template.env not found — skipping secrets check"
    return 0
  fi

  # 检查本地 secrets 文件
  if [[ ! -f "$secrets_local" ]]; then
    _issue_warn \
      "~/.secrets.local.env not found" \
      "Run: ./scripts/init_secrets.sh  to configure secrets"
    return 0
  fi

  _ok "~/.secrets.local.env exists"

  # 检查模板中的必要 key 是否都已配置
  local missing_keys=()
  while IFS= read -r line; do
    # 跳过注释和空行
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    # 提取 key 名（= 前的部分）
    local key="${line%%=*}"
    [[ -z "$key" ]] && continue

    # 检查 key 是否在本地 secrets 中有非空值
    local value
    value="$(grep -E "^${key}=" "$secrets_local" 2>/dev/null | cut -d= -f2- || echo "")"
    if [[ -z "$value" || "$value" == '""' || "$value" == "''" ]]; then
      missing_keys+=("$key")
    fi
  done < "$secrets_template"

  if [[ "${#missing_keys[@]}" -gt 0 ]]; then
    for key in "${missing_keys[@]}"; do
      _issue_warn \
        "Secret key '$key' is not configured" \
        "Edit ~/.secrets.local.env and set $key=<value>"
    done
  else
    _ok "All required secrets are configured"
  fi
}

# ---------------------------------------------------------------------------
# 最终报告
# ---------------------------------------------------------------------------
_print_report() {
  echo
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║               DOCTOR REPORT                         ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo

  if [[ "${#ISSUES_CRITICAL[@]}" -eq 0 && "${#ISSUES_WARN[@]}" -eq 0 ]]; then
    _ok "Your environment looks healthy."
    echo
    return 0
  fi

  if [[ "${#ISSUES_WARN[@]}" -gt 0 ]]; then
    printf "  \033[1;33m⚠  Warnings (%d):\033[0m\n" "${#ISSUES_WARN[@]}"
    for issue in "${ISSUES_WARN[@]}"; do
      echo "     - $issue"
    done
    echo
  fi

  if [[ "${#ISSUES_CRITICAL[@]}" -gt 0 ]]; then
    printf "  \033[0;31m✗  Issues (%d):\033[0m\n" "${#ISSUES_CRITICAL[@]}"
    for issue in "${ISSUES_CRITICAL[@]}"; do
      echo "     - $issue"
    done
    echo
    printf "  \033[0;31mRun './bin/dotfiles sync' to fix critical issues.\033[0m\n"
    echo
    return 1
  fi

  echo
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  _banner "dotfiles doctor  •  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "  OS      : $OS_TYPE ($OS_ARCH)"
  echo "  Repo    : $REPO_ROOT"
  echo

  _check_lib_modules
  _check_tools
  _check_dotfiles
  _check_secrets

  _print_report
}

main "$@"
