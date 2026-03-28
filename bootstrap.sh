#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh - 环境初始化入口（Legacy 兼容层）
# DEPRECATED: use ./dotfiles sync instead
# =============================================================================
# 本文件保留用于向后兼容。新用法请使用 dotfiles 入口脚本：
#   ./dotfiles sync              # 全量同步
#   ./dotfiles sync --tools      # 仅同步工具
#   ./dotfiles sync --dotfiles   # 仅链接 dotfiles
#   ./dotfiles update            # git pull + sync
#
# 退出码：
#   0 - 所有步骤成功或仅有警告
#   1 - 一个或多个步骤失败
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

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

# ---------------------------------------------------------------------------
# 解析参数
# ---------------------------------------------------------------------------
DRY_RUN=false
DO_PULL=false
TOOLS_ONLY=false
DOTFILES_ONLY=false
SKIP_SECRETS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pull)          DO_PULL=true        ; shift ;;
    --dry-run)       DRY_RUN=true        ; shift ;;
    --tools-only)    TOOLS_ONLY=true     ; shift ;;
    --dotfiles-only) DOTFILES_ONLY=true  ; shift ;;
    --skip-secrets)  SKIP_SECRETS=true   ; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]
DEPRECATED: use ./dotfiles sync instead

Options:
  --pull           Git pull latest config before applying
  --dry-run        Preview changes without making modifications
  --tools-only     Only install/sync tools, skip dotfiles linking
  --dotfiles-only  Only link dotfiles, skip tool installation
  --skip-secrets   Skip the secrets initialization step
  -h, --help       Show this help message

New usage (recommended):
  ./dotfiles sync              # Full sync
  ./dotfiles sync --tools      # Tools only
  ./dotfiles sync --dotfiles   # Dotfiles only
  ./dotfiles update            # git pull + sync
EOF
      exit 0
      ;;
    *) _warn "Unknown argument: $1" ; shift ;;
  esac
done

# ---------------------------------------------------------------------------
# 步骤追踪
# ---------------------------------------------------------------------------
declare -a STEPS_OK=()
declare -a STEPS_WARN=()
declare -a STEPS_FAIL=()

_record_step() {
  local name="$1"
  local rc="$2"
  local is_warn="${3:-false}"  # 第三个参数：是否作为警告（非致命）记录

  if [[ "$rc" -eq 0 ]]; then
    STEPS_OK+=("$name")
  elif [[ "$is_warn" == "true" ]]; then
    STEPS_WARN+=("$name (exit: $rc)")
  else
    STEPS_FAIL+=("$name (exit: $rc)")
  fi
}

# ---------------------------------------------------------------------------
# Step 0: Git pull（可选）
# ---------------------------------------------------------------------------
_step_pull() {
  _section "Step 0: Pulling latest configuration"

  if ! git -C "$REPO_ROOT" rev-parse --git-dir &>/dev/null; then
    _warn "Not a git repository. Skipping pull."
    return 0
  fi

  local current_branch
  current_branch="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo 'unknown')"
  _info "Branch: $current_branch"

  if [[ "$DRY_RUN" == "true" ]]; then
    _info "[DRY-RUN] Would run: git pull --ff-only"
    return 0
  fi

  git -C "$REPO_ROOT" pull --ff-only
  _ok "Repository updated"
}

# ---------------------------------------------------------------------------
# Step 1: OS 检测
# ---------------------------------------------------------------------------
_step_detect_os() {
  _section "Step 1: Detecting operating system"
  detect_os_assert_supported || return 1
  _ok "OS: $OS_TYPE ($OS_ARCH)$([ "$IS_WSL" = "true" ] && echo " [WSL]")"
}

# ---------------------------------------------------------------------------
# Step 2: 安装 Git hooks
# ---------------------------------------------------------------------------
_step_install_hooks() {
  _section "Step 2: Installing Git hooks"

  local hooks_src="$REPO_ROOT/hooks"
  local hooks_dest="$REPO_ROOT/.git/hooks"

  if [[ ! -d "$REPO_ROOT/.git" ]]; then
    _warn "No .git directory found. Skipping hook installation."
    return 0
  fi

  if [[ ! -d "$hooks_src" ]]; then
    _warn "No hooks/ directory found. Skipping."
    return 0
  fi

  for hook_file in "$hooks_src"/*; do
    local hook_name
    hook_name="$(basename "$hook_file")"
    local dest="$hooks_dest/$hook_name"

    if [[ "$DRY_RUN" == "true" ]]; then
      _info "[DRY-RUN] Would install hook: $hook_name"
      continue
    fi

    cp "$hook_file" "$dest"
    chmod +x "$dest"
    _ok "Installed hook: $hook_name"
  done
}

# ---------------------------------------------------------------------------
# Step 3: Secrets 初始化（非致命步骤）
# ---------------------------------------------------------------------------
_step_secrets() {
  _section "Step 3: Secrets configuration"

  local secrets_script="$REPO_ROOT/scripts/init_secrets.sh"

  if [[ ! -f "$secrets_script" ]]; then
    _warn "init_secrets.sh not found. Skipping."
    return 0
  fi

  if [[ -f "$HOME/.secrets.local.env" ]]; then
    _info "Found existing secrets at ~/.secrets.local.env"
    if bash "$secrets_script" --check; then
      _ok "All required secrets are configured."
      bash "$secrets_script" --apply
      return 0
    else
      _warn "Some required secrets are missing. Running interactive setup..."
    fi
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    _info "[DRY-RUN] Would run: init_secrets.sh"
    return 0
  fi

  bash "$secrets_script"
}

# ---------------------------------------------------------------------------
# Step 4: 工具同步
# ---------------------------------------------------------------------------
_step_sync_tools() {
  _section "Step 4: Synchronizing tools"

  local sync_script="$REPO_ROOT/scripts/sync.sh"

  if [[ ! -f "$sync_script" ]]; then
    _error_actionable \
      "sync.sh not found at: $sync_script" \
      "The scripts/ directory may be incomplete" \
      "Run: git status  to check for missing files"
    return 1
  fi

  local args=()
  [[ "$DRY_RUN" == "true" ]] && args+=("--dry-run")

  bash "$sync_script" "${args[@]}"
}

# ---------------------------------------------------------------------------
# Step 5: Dotfiles 链接
# ---------------------------------------------------------------------------
_step_link_dotfiles() {
  _section "Step 5: Linking dotfiles"

  local link_script="$REPO_ROOT/scripts/link_dotfiles.sh"

  if [[ ! -f "$link_script" ]]; then
    _error_actionable \
      "link_dotfiles.sh not found at: $link_script" \
      "The scripts/ directory may be incomplete" \
      "Run: git status  to check for missing files"
    return 1
  fi

  local args=()
  [[ "$DRY_RUN" == "true" ]] && args+=("--dry-run")

  bash "$link_script" "${args[@]}"
}

# ---------------------------------------------------------------------------
# Step 6: 安装后提示
# ---------------------------------------------------------------------------
_step_post_setup() {
  _section "Step 6: Post-setup"

  echo
  echo "  Next steps:"
  echo "  ─────────────────────────────────────────────────────"

  if [[ "$SHELL" != "$(command -v zsh 2>/dev/null)" ]]; then
    if command -v zsh &>/dev/null; then
      echo "  • Set zsh as default shell:"
      echo "      chsh -s \$(which zsh)"
    fi
  fi

  if ! command -v mise &>/dev/null; then
    echo "  • Install mise (runtime version manager):"
    echo "      curl https://mise.run | sh"
  fi

  if [[ ! -f "$HOME/.secrets.local.env" ]]; then
    echo "  • Configure your secrets:"
    echo "      ./scripts/init_secrets.sh"
  fi

  echo "  • Reload your shell:"
  echo "      exec \$SHELL"
  echo
}

# ---------------------------------------------------------------------------
# 最终摘要（三态：✓ OK / ⚠ WARN / ✗ FAIL）
# ---------------------------------------------------------------------------
_print_final_summary() {
  echo
  _banner "BOOTSTRAP SUMMARY  •  $(date '+%Y-%m-%d %H:%M:%S')"
  echo

  if [[ "${#STEPS_OK[@]}" -gt 0 ]]; then
    printf "  \033[0;32m✓  OK      : %d\033[0m\n" "${#STEPS_OK[@]}"
    for s in "${STEPS_OK[@]}"; do echo "       - $s"; done
  fi

  if [[ "${#STEPS_WARN[@]}" -gt 0 ]]; then
    printf "  \033[1;33m⚠  WARN    : %d\033[0m\n" "${#STEPS_WARN[@]}" >&2
    for s in "${STEPS_WARN[@]}"; do echo "       - $s" >&2; done
  fi

  if [[ "${#STEPS_FAIL[@]}" -gt 0 ]]; then
    printf "  \033[0;31m✗  FAIL    : %d\033[0m\n" "${#STEPS_FAIL[@]}" >&2
    for s in "${STEPS_FAIL[@]}"; do echo "       - $s" >&2; done
    echo
    printf "  \033[0;31mBootstrap completed with failures. See above for details.\033[0m\n" >&2
    echo
    return 1
  fi

  echo
  printf "  \033[0;32mBootstrap complete!\033[0m\n"
  echo
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  _banner "dotfiles bootstrap  •  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "  Repo    : $REPO_ROOT"
  echo "  Dry run : $DRY_RUN"
  echo "  Pull    : $DO_PULL"

  # Step 0: Pull（可选）
  if [[ "$DO_PULL" == "true" ]]; then
    _step_pull
    local rc_pull=$?
    _record_step "git pull" "$rc_pull"
  fi

  # Step 1: OS 检测（必须成功）
  _step_detect_os || {
    _error "OS detection failed. Aborting."
    exit 1
  }
  _record_step "OS detection" 0

  # Step 2: Git hooks
  _step_install_hooks
  local rc_hooks=$?
  _record_step "Git hooks" "$rc_hooks"

  # Step 3: Secrets（非致命步骤，失败记为 WARN）
  if [[ "$SKIP_SECRETS" == "false" && "$TOOLS_ONLY" == "false" ]]; then
    _step_secrets  # non-fatal: user can configure secrets later
    local rc_secrets=$?
    _record_step "Secrets init" "$rc_secrets" "true"  # 第三参数 true = 失败记为 WARN
  fi

  # Step 4: 工具同步（除非 dotfiles-only）
  if [[ "$DOTFILES_ONLY" == "false" ]]; then
    _step_sync_tools
    local rc_tools=$?
    _record_step "Tool sync" "$rc_tools"
  fi

  # Step 5: Dotfiles 链接（除非 tools-only）
  if [[ "$TOOLS_ONLY" == "false" ]]; then
    _step_link_dotfiles
    local rc_dotfiles=$?
    _record_step "Dotfiles link" "$rc_dotfiles"
  fi

  # Step 6: 安装后提示
  _step_post_setup
  _record_step "Post-setup" 0

  _print_final_summary
  # 有 FAIL 则退出码 1；仅 WARN 则退出码 0（警告不阻断 CI）
  [[ "${#STEPS_FAIL[@]}" -eq 0 ]]
}

main "$@"
