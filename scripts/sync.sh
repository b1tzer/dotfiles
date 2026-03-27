#!/usr/bin/env bash
# =============================================================================
# scripts/sync.sh - Core Sync Engine
# =============================================================================
# Reads tools.yaml and installs/checks all declared tools on the current OS.
#
# Usage:
#   ./scripts/sync.sh              # Install all tools
#   ./scripts/sync.sh --dry-run    # Show diff only, no actual install
#   ./scripts/sync.sh --tool git   # Sync a single tool
#
# Exit codes:
#   0 - All tools installed/skipped successfully
#   1 - One or more tools failed to install
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$REPO_ROOT/sync.log"
TOOLS_YAML="$REPO_ROOT/tools.yaml"

# Source library modules
# shellcheck source=lib/detect_os.sh
source "$REPO_ROOT/lib/detect_os.sh"
# shellcheck source=lib/pkg_manager.sh
source "$REPO_ROOT/lib/pkg_manager.sh"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
DRY_RUN=false
SINGLE_TOOL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=true  ; shift ;;
    --tool)     SINGLE_TOOL="$2" ; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--tool <name>]"
      echo "  --dry-run       Show what would be installed without making changes"
      echo "  --tool <name>   Only process the specified tool"
      exit 0
      ;;
    *) echo "[WARN] Unknown argument: $1" >&2 ; shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Dependency check: yq (YAML parser)
# ---------------------------------------------------------------------------
_ensure_yq() {
  if ! command -v yq &>/dev/null; then
    echo "[INFO] yq not found. Installing yq for YAML parsing..."
    case "$OS_TYPE" in
      ubuntu)
        sudo wget -qO /usr/local/bin/yq \
          "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
        sudo chmod +x /usr/local/bin/yq
        ;;
      macos)
        brew install yq
        ;;
      *)
        echo "[ERROR] Please install yq manually: https://github.com/mikefarah/yq" >&2
        exit 1
        ;;
    esac
  fi
}

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
_log() {
  local level="$1"; shift
  local msg="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

_info()    { echo "  [INFO]  $*"; _log "INFO"  "$*"; }
_ok()      { echo "  [✓]     $*"; _log "OK"    "$*"; }
_skip()    { echo "  [SKIP]  $*"; _log "SKIP"  "$*"; }
_warn()    { echo "  [WARN]  $*" >&2; _log "WARN"  "$*"; }
_error()   { echo "  [✗]     $*" >&2; _log "ERROR" "$*"; }
_section() { echo; echo "━━━ $* ━━━"; }

# ---------------------------------------------------------------------------
# Summary tracking
# ---------------------------------------------------------------------------
declare -a SUMMARY_OK=()
declare -a SUMMARY_SKIP=()
declare -a SUMMARY_FAIL=()
declare -a SUMMARY_DEPRECATED=()
declare -a SUMMARY_MANUAL=()

# ---------------------------------------------------------------------------
# Process a single tool entry from tools.yaml
# ---------------------------------------------------------------------------
_process_tool() {
  local name="$1"
  local description check_cmd deprecated replaced_by migration_note
  local platform_method platform_install platform_script

  # Read fields from YAML
  description="$(yq e ".tools[] | select(.name == \"$name\") | .description // \"\"" "$TOOLS_YAML")"
  check_cmd="$(yq e ".tools[] | select(.name == \"$name\") | .check_cmd // \"$name\"" "$TOOLS_YAML")"
  deprecated="$(yq e ".tools[] | select(.name == \"$name\") | .deprecated // false" "$TOOLS_YAML")"
  replaced_by="$(yq e ".tools[] | select(.name == \"$name\") | .replaced_by // \"\"" "$TOOLS_YAML")"
  migration_note="$(yq e ".tools[] | select(.name == \"$name\") | .migration_note // \"\"" "$TOOLS_YAML")"

  # Read platform-specific fields
  platform_method="$(yq e ".tools[] | select(.name == \"$name\") | .platforms.$OS_TYPE.method // \"\"" "$TOOLS_YAML")"
  platform_install="$(yq e ".tools[] | select(.name == \"$name\") | .platforms.$OS_TYPE.install // \"\"" "$TOOLS_YAML")"
  platform_script="$(yq e ".tools[] | select(.name == \"$name\") | .platforms.$OS_TYPE.script // \"\"" "$TOOLS_YAML")"

  echo -n "  ▸ $name"
  [ -n "$description" ] && echo -n " ($description)"
  echo

  # --- Handle deprecated tools ---
  if [ "$deprecated" = "true" ]; then
    if pkg_is_installed "$check_cmd"; then
      _warn "$name is DEPRECATED. $([ -n "$replaced_by" ] && echo "Replaced by: $replaced_by.")"
      [ -n "$migration_note" ] && _warn "Migration: $migration_note"
      SUMMARY_DEPRECATED+=("$name → ${replaced_by:-no replacement}")

      # Auto-install replacement tool if specified and not yet installed
      if [ -n "$replaced_by" ]; then
        local replacement_check_cmd
        replacement_check_cmd="$(yq e ".tools[] | select(.name == \"$replaced_by\") | .check_cmd // \"$replaced_by\"" "$TOOLS_YAML" 2>/dev/null || echo "$replaced_by")"

        if ! pkg_is_installed "$replacement_check_cmd"; then
          if [ "$DRY_RUN" = "true" ]; then
            _info "[DRY-RUN] Would auto-install replacement: $replaced_by"
          else
            _info "Auto-installing replacement tool: $replaced_by"
            _process_tool "$replaced_by" || true
          fi
        else
          _info "Replacement tool '$replaced_by' is already installed."
        fi
      fi
    else
      _skip "$name (deprecated, not installed - skipping)"
    fi
    return 0
  fi

  # --- Check if platform is supported ---
  if [ -z "$platform_method" ]; then
    _skip "$name (not supported on $OS_TYPE)"
    SUMMARY_SKIP+=("$name (unsupported on $OS_TYPE)")
    return 0
  fi

  # --- Check if already installed ---
  if pkg_is_installed "$check_cmd"; then
    _skip "$name (already installed)"
    SUMMARY_SKIP+=("$name")
    return 0
  fi

  # --- Dry run: just report ---
  if [ "$DRY_RUN" = "true" ]; then
    _info "[DRY-RUN] Would install: $name via $platform_method"
    SUMMARY_SKIP+=("$name (would install)")
    return 0
  fi

  # --- Install ---
  _info "Installing $name via $platform_method..."
  local exit_code=0

  case "$platform_method" in
    script)
      pkg_run_script "$platform_script" || exit_code=$?
      ;;
    manual)
      _skip "$name requires manual installation: $platform_install"
      SUMMARY_MANUAL+=("$name: $platform_install")
      return 0
      ;;
    *)
      pkg_install "$platform_install" "$platform_method" || exit_code=$?
      ;;
  esac

  if [ "$exit_code" -eq 0 ]; then
    _ok "$name installed successfully"
    SUMMARY_OK+=("$name")
  else
    _error "$name installation FAILED (exit code: $exit_code)"
    SUMMARY_FAIL+=("$name")
  fi
}

# ---------------------------------------------------------------------------
# Print final summary
# ---------------------------------------------------------------------------
_print_summary() {
  echo
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║                   SYNC SUMMARY                      ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo
  echo "  ✓  Installed  : ${#SUMMARY_OK[@]}"
  for t in "${SUMMARY_OK[@]:-}"; do [ -n "$t" ] && echo "       - $t"; done

  echo "  ⊘  Skipped    : ${#SUMMARY_SKIP[@]}"
  for t in "${SUMMARY_SKIP[@]:-}"; do [ -n "$t" ] && echo "       - $t"; done

  if [ "${#SUMMARY_FAIL[@]}" -gt 0 ]; then
    echo "  ✗  Failed     : ${#SUMMARY_FAIL[@]}"
    for t in "${SUMMARY_FAIL[@]}"; do echo "       - $t"; done
  fi

  if [ "${#SUMMARY_DEPRECATED[@]}" -gt 0 ]; then
    echo "  ⚠  Deprecated : ${#SUMMARY_DEPRECATED[@]}"
    for t in "${SUMMARY_DEPRECATED[@]}"; do echo "       - $t"; done
  fi

  if [ "${#SUMMARY_MANUAL[@]}" -gt 0 ]; then
    echo "  ✎  Manual     : ${#SUMMARY_MANUAL[@]}"
    for t in "${SUMMARY_MANUAL[@]}"; do echo "       - $t"; done
  fi

  echo
  echo "  Log file: $LOG_FILE"
  echo

  # Return non-zero if any failures
  [ "${#SUMMARY_FAIL[@]}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║         dotfiles sync - $(date '+%Y-%m-%d %H:%M:%S')         ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo "  OS      : $OS_TYPE ($OS_ARCH)"
  echo "  WSL     : $IS_WSL"
  echo "  Dry run : $DRY_RUN"
  echo "  Config  : $TOOLS_YAML"

  # Ensure yq is available
  _ensure_yq

  # Initialize package manager (update index)
  if [ "$DRY_RUN" = "false" ]; then
    _section "Initializing package manager"
    pkg_manager_init
  fi

  # Get list of all tool names
  local tool_names
  if [ -n "$SINGLE_TOOL" ]; then
    tool_names="$SINGLE_TOOL"
  else
    tool_names="$(yq e '.tools[].name' "$TOOLS_YAML")"
  fi

  _section "Processing tools"

  # Process each tool; catch errors per-tool so one failure doesn't stop others
  while IFS= read -r tool_name; do
    [ -z "$tool_name" ] && continue
    _process_tool "$tool_name" || {
      _error "Unexpected error processing tool: $tool_name"
      SUMMARY_FAIL+=("$tool_name (unexpected error)")
    }
  done <<< "$tool_names"

  _print_summary
}

main "$@"
