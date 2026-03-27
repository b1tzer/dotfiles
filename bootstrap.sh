#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh - One-command Environment Initialization Entry Point
# =============================================================================
# This is the SINGLE entry point for setting up a new machine or syncing
# an existing one with the latest configuration.
#
# Usage:
#   # First-time setup on a new machine:
#   git clone <your-dotfiles-repo> ~/dotfiles && cd ~/dotfiles
#   ./bootstrap.sh
#
#   # Sync latest changes from remote (pull + apply):
#   ./bootstrap.sh --pull
#
#   # Preview what would change without making modifications:
#   ./bootstrap.sh --dry-run
#
#   # Only sync tools (skip dotfiles linking):
#   ./bootstrap.sh --tools-only
#
#   # Only link dotfiles (skip tool installation):
#   ./bootstrap.sh --dotfiles-only
#
# Exit codes:
#   0 - Success (all steps completed or skipped cleanly)
#   1 - One or more steps failed
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# Parse arguments
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

Options:
  --pull           Git pull latest config before applying
  --dry-run        Preview changes without making modifications
  --tools-only     Only install/sync tools, skip dotfiles linking
  --dotfiles-only  Only link dotfiles, skip tool installation
  --skip-secrets   Skip the secrets initialization step
  -h, --help       Show this help message

Examples:
  ./bootstrap.sh                  # Full setup on a new machine
  ./bootstrap.sh --pull           # Sync latest changes from remote
  ./bootstrap.sh --dry-run        # Preview what would change
  ./bootstrap.sh --tools-only     # Only install tools
EOF
      exit 0
      ;;
    *) echo "[WARN] Unknown argument: $1" >&2 ; shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Color output helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'  # No Color

_banner() {
  echo
  echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${BLUE}║${NC}  $1"
  echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
}

_step()    { echo; echo -e "${BOLD}━━━ $* ━━━${NC}"; }
_ok()      { echo -e "  ${GREEN}[✓]${NC}  $*"; }
_info()    { echo -e "  ${BLUE}[i]${NC}  $*"; }
_warn()    { echo -e "  ${YELLOW}[!]${NC}  $*" >&2; }
_error()   { echo -e "  ${RED}[✗]${NC}  $*" >&2; }
_section_result() {
  local status="$1"; shift
  if [ "$status" -eq 0 ]; then
    _ok "$* completed successfully"
  else
    _warn "$* completed with warnings/errors (exit: $status)"
  fi
}

# ---------------------------------------------------------------------------
# Step tracking
# ---------------------------------------------------------------------------
declare -a STEPS_OK=()
declare -a STEPS_WARN=()
declare -a STEPS_FAIL=()

_record_step() {
  local name="$1"
  local exit_code="$2"
  if [ "$exit_code" -eq 0 ]; then
    STEPS_OK+=("$name")
  elif [ "$exit_code" -eq 2 ]; then
    STEPS_WARN+=("$name")
  else
    STEPS_FAIL+=("$name")
  fi
}

# ---------------------------------------------------------------------------
# Step 0: Git pull (optional)
# ---------------------------------------------------------------------------
_step_pull() {
  _step "Step 0: Pulling latest configuration"

  if ! git -C "$REPO_ROOT" rev-parse --git-dir &>/dev/null; then
    _warn "Not a git repository. Skipping pull."
    return 0
  fi

  local current_branch
  current_branch="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo 'unknown')"
  _info "Branch: $current_branch"

  if [ "$DRY_RUN" = "true" ]; then
    _info "[DRY-RUN] Would run: git pull"
    return 0
  fi

  git -C "$REPO_ROOT" pull --ff-only
  _ok "Repository updated"
}

# ---------------------------------------------------------------------------
# Step 1: OS detection
# ---------------------------------------------------------------------------
_step_detect_os() {
  _step "Step 1: Detecting operating system"
  # shellcheck source=lib/detect_os.sh
  source "$REPO_ROOT/lib/detect_os.sh"
  detect_os_assert_supported || return 1
  _ok "OS: $OS_TYPE ($OS_ARCH)$([ "$IS_WSL" = "true" ] && echo " [WSL]")"
}

# ---------------------------------------------------------------------------
# Step 2: Install Git hooks
# ---------------------------------------------------------------------------
_step_install_hooks() {
  _step "Step 2: Installing Git hooks"

  local hooks_src="$REPO_ROOT/hooks"
  local hooks_dest="$REPO_ROOT/.git/hooks"

  if [ ! -d "$REPO_ROOT/.git" ]; then
    _warn "No .git directory found. Skipping hook installation."
    return 0
  fi

  if [ ! -d "$hooks_src" ]; then
    _warn "No hooks/ directory found. Skipping."
    return 0
  fi

  for hook_file in "$hooks_src"/*; do
    local hook_name
    hook_name="$(basename "$hook_file")"
    local dest="$hooks_dest/$hook_name"

    if [ "$DRY_RUN" = "true" ]; then
      _info "[DRY-RUN] Would install hook: $hook_name"
      continue
    fi

    cp "$hook_file" "$dest"
    chmod +x "$dest"
    _ok "Installed hook: $hook_name"
  done
}

# ---------------------------------------------------------------------------
# Step 3: Secrets initialization
# ---------------------------------------------------------------------------
_step_secrets() {
  _step "Step 3: Secrets configuration"

  local secrets_script="$REPO_ROOT/scripts/init_secrets.sh"

  if [ ! -f "$secrets_script" ]; then
    _warn "init_secrets.sh not found. Skipping."
    return 0
  fi

  # Check if secrets already configured
  if [ -f "$HOME/.secrets.local.env" ]; then
    _info "Found existing secrets at ~/.secrets.local.env"
    if bash "$secrets_script" --check; then
      _ok "All required secrets are configured."
      # Re-apply templates in case configs changed
      bash "$secrets_script" --apply
      return 0
    else
      _warn "Some required secrets are missing. Running interactive setup..."
    fi
  fi

  if [ "$DRY_RUN" = "true" ]; then
    _info "[DRY-RUN] Would run: init_secrets.sh"
    return 0
  fi

  bash "$secrets_script"
}

# ---------------------------------------------------------------------------
# Step 4: Tool synchronization
# ---------------------------------------------------------------------------
_step_sync_tools() {
  _step "Step 4: Synchronizing tools"

  local sync_script="$REPO_ROOT/scripts/sync.sh"

  if [ ! -f "$sync_script" ]; then
    _error "sync.sh not found at: $sync_script"
    return 1
  fi

  local args=()
  [ "$DRY_RUN" = "true" ] && args+=("--dry-run")

  bash "$sync_script" "${args[@]}"
}

# ---------------------------------------------------------------------------
# Step 5: Dotfiles linking
# ---------------------------------------------------------------------------
_step_link_dotfiles() {
  _step "Step 5: Linking dotfiles"

  local link_script="$REPO_ROOT/scripts/link_dotfiles.sh"

  if [ ! -f "$link_script" ]; then
    _error "link_dotfiles.sh not found at: $link_script"
    return 1
  fi

  local args=()
  [ "$DRY_RUN" = "true" ] && args+=("--dry-run")

  bash "$link_script" "${args[@]}"
}

# ---------------------------------------------------------------------------
# Step 6: Post-setup instructions
# ---------------------------------------------------------------------------
_step_post_setup() {
  _step "Step 6: Post-setup"

  echo
  echo "  Next steps:"
  echo "  ─────────────────────────────────────────────────────"

  # Check if zsh is default shell
  if [ "$SHELL" != "$(command -v zsh 2>/dev/null)" ]; then
    if command -v zsh &>/dev/null; then
      echo "  • Set zsh as default shell:"
      echo "      chsh -s \$(which zsh)"
    fi
  fi

  # Check if oh-my-zsh is installed
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "  • Install Oh My Zsh plugins after setup:"
    echo "      git clone https://github.com/zsh-users/zsh-autosuggestions \\"
    echo "        \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    echo "      git clone https://github.com/zsh-users/zsh-syntax-highlighting \\"
    echo "        \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
  fi

  # Remind about secrets
  if [ ! -f "$HOME/.secrets.local.env" ]; then
    echo "  • Configure your secrets:"
    echo "      ./scripts/init_secrets.sh"
  fi

  echo "  • Reload your shell:"
  echo "      exec \$SHELL"
  echo
}

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
_print_final_summary() {
  echo
  echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║               BOOTSTRAP SUMMARY                     ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
  echo
  echo -e "  ${GREEN}✓  Completed : ${#STEPS_OK[@]}${NC}"
  for s in "${STEPS_OK[@]:-}"; do [ -n "$s" ] && echo "       - $s"; done

  if [ "${#STEPS_WARN[@]}" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠  Warnings  : ${#STEPS_WARN[@]}${NC}"
    for s in "${STEPS_WARN[@]}"; do echo "       - $s"; done
  fi

  if [ "${#STEPS_FAIL[@]}" -gt 0 ]; then
    echo -e "  ${RED}✗  Failed    : ${#STEPS_FAIL[@]}${NC}"
    for s in "${STEPS_FAIL[@]}"; do echo "       - $s"; done
    echo
    return 1
  fi

  echo
  echo -e "  ${GREEN}${BOLD}Bootstrap complete!${NC}"
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

  local exit_code=0

  # Step 0: Pull (optional)
  if [ "$DO_PULL" = "true" ]; then
    _step_pull
    _record_step "git pull" $?
  fi

  # Step 1: OS detection (always required)
  _step_detect_os || { _error "OS detection failed. Aborting."; exit 1; }
  _record_step "OS detection" 0

  # Step 2: Git hooks
  _step_install_hooks
  _record_step "Git hooks" $?

  # Step 3: Secrets (unless skipped)
  if [ "$SKIP_SECRETS" = "false" ] && [ "$TOOLS_ONLY" = "false" ]; then
    _step_secrets || true  # Non-fatal: user can configure secrets later
    _record_step "Secrets init" $?
  fi

  # Step 4: Tool sync (unless dotfiles-only)
  if [ "$DOTFILES_ONLY" = "false" ]; then
    _step_sync_tools
    exit_code=$?
    _record_step "Tool sync" $exit_code
  fi

  # Step 5: Dotfiles linking (unless tools-only)
  if [ "$TOOLS_ONLY" = "false" ]; then
    _step_link_dotfiles
    exit_code=$?
    _record_step "Dotfiles link" $exit_code
  fi

  # Step 6: Post-setup hints
  _step_post_setup
  _record_step "Post-setup" 0

  _print_final_summary
}

main "$@"
