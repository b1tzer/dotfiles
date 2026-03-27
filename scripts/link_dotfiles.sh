#!/usr/bin/env bash
# =============================================================================
# scripts/link_dotfiles.sh - Dotfiles Symlink Manager
# =============================================================================
# Creates symlinks from $HOME to dotfiles in the repo's dotfiles/ directory.
# Handles:
#   - Backup of existing files before linking
#   - Platform-specific dotfile selection (.zshrc.macos / .zshrc.ubuntu)
#   - Nested config files (e.g. .config/starship.toml)
#
# Usage:
#   ./scripts/link_dotfiles.sh              # Link all dotfiles
#   ./scripts/link_dotfiles.sh --dry-run    # Show what would be linked
#   ./scripts/link_dotfiles.sh --unlink     # Remove symlinks (restore backups)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOTFILES_DIR="$REPO_ROOT/dotfiles"

# Source OS detection
# shellcheck source=lib/detect_os.sh
source "$REPO_ROOT/lib/detect_os.sh"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
DRY_RUN=false
UNLINK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true  ; shift ;;
    --unlink)  UNLINK=true   ; shift ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--unlink]"
      echo "  --dry-run   Show what would be linked without making changes"
      echo "  --unlink    Remove symlinks and restore backups"
      exit 0
      ;;
    *) echo "[WARN] Unknown argument: $1" >&2 ; shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_info()  { echo "  [INFO]  $*"; }
_ok()    { echo "  [✓]     $*"; }
_skip()  { echo "  [SKIP]  $*"; }
_warn()  { echo "  [WARN]  $*" >&2; }
_error() { echo "  [✗]     $*" >&2; }

declare -a LINK_OK=()
declare -a LINK_SKIP=()
declare -a LINK_FAIL=()
declare -a LINK_BACKUP=()

# ---------------------------------------------------------------------------
# _backup_file <path>
# Backs up a file/dir to <path>.bak.<timestamp>
# ---------------------------------------------------------------------------
_backup_file() {
  local target="$1"
  local timestamp
  timestamp="$(date '+%Y%m%d_%H%M%S')"
  local backup="${target}.bak.${timestamp}"

  mv "$target" "$backup"
  _info "Backed up: $target → $backup"
  LINK_BACKUP+=("$target → $backup")
}

# ---------------------------------------------------------------------------
# _link_file <src_in_repo> <dest_in_home>
# Creates a symlink from $HOME/<dest> → <repo>/dotfiles/<src>
# ---------------------------------------------------------------------------
_link_file() {
  local src="$1"    # Absolute path in repo
  local dest="$2"   # Absolute path in $HOME

  local rel_dest="${dest/#$HOME\//~/}"

  # Ensure parent directory exists
  local dest_dir
  dest_dir="$(dirname "$dest")"
  if [ ! -d "$dest_dir" ]; then
    if [ "$DRY_RUN" = "true" ]; then
      _info "[DRY-RUN] Would create directory: $dest_dir"
    else
      mkdir -p "$dest_dir"
    fi
  fi

  # Case 1: Already a symlink pointing to our file
  if [ -L "$dest" ]; then
    local current_target
    current_target="$(readlink "$dest")"
    if [ "$current_target" = "$src" ]; then
      _skip "$rel_dest (already linked)"
      LINK_SKIP+=("$rel_dest")
      return 0
    else
      _warn "$rel_dest is a symlink to a different target: $current_target"
      if [ "$DRY_RUN" = "false" ]; then
        rm "$dest"
      fi
    fi
  fi

  # Case 2: Regular file or directory exists - backup first
  if [ -e "$dest" ]; then
    if [ "$DRY_RUN" = "true" ]; then
      _info "[DRY-RUN] Would backup: $dest"
    else
      _backup_file "$dest"
    fi
  fi

  # Create symlink
  if [ "$DRY_RUN" = "true" ]; then
    _info "[DRY-RUN] Would link: $rel_dest → $src"
    LINK_SKIP+=("$rel_dest (would link)")
  else
    ln -sf "$src" "$dest"
    _ok "Linked: $rel_dest → $src"
    LINK_OK+=("$rel_dest")
  fi
}

# ---------------------------------------------------------------------------
# _unlink_file <dest_in_home>
# Removes a symlink and restores the most recent backup if available
# ---------------------------------------------------------------------------
_unlink_file() {
  local dest="$1"
  local rel_dest="${dest/#$HOME\//~/}"

  if [ ! -L "$dest" ]; then
    _skip "$rel_dest (not a symlink)"
    return 0
  fi

  rm "$dest"
  _info "Removed symlink: $rel_dest"

  # Find and restore most recent backup
  local latest_backup
  latest_backup="$(ls -t "${dest}.bak."* 2>/dev/null | head -1 || true)"
  if [ -n "$latest_backup" ]; then
    mv "$latest_backup" "$dest"
    _ok "Restored backup: $latest_backup → $dest"
  fi
}

# ---------------------------------------------------------------------------
# _resolve_platform_dotfile <base_name>
# Returns the platform-specific dotfile path if it exists,
# otherwise returns the base dotfile path.
# e.g. .zshrc → .zshrc.macos (on macOS) or .zshrc.ubuntu (on Ubuntu)
# ---------------------------------------------------------------------------
_resolve_platform_dotfile() {
  local base_name="$1"
  local platform_file="$DOTFILES_DIR/${base_name}.${OS_TYPE}"

  if [ -f "$platform_file" ]; then
    echo "$platform_file"
  else
    echo "$DOTFILES_DIR/$base_name"
  fi
}

# ---------------------------------------------------------------------------
# _collect_dotfiles
# Outputs a list of "src|dest" pairs for all dotfiles to be linked.
# Skips platform-specific variants (*.macos, *.ubuntu) - they are sourced
# from within the main dotfile.
# ---------------------------------------------------------------------------
_collect_dotfiles() {
  # Find all files in dotfiles/ directory
  find "$DOTFILES_DIR" -type f | sort | while read -r file; do
    local rel_path="${file#$DOTFILES_DIR/}"

    # Skip platform-specific variants (they are sourced, not linked directly)
    if [[ "$rel_path" =~ \.(macos|ubuntu|windows|linux)$ ]]; then
      continue
    fi

    # Compute destination path in $HOME
    local dest="$HOME/$rel_path"

    echo "$file|$dest"
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║              dotfiles symlink manager                ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo "  OS        : $OS_TYPE"
  echo "  Dotfiles  : $DOTFILES_DIR"
  echo "  Home      : $HOME"
  echo "  Dry run   : $DRY_RUN"
  echo "  Unlink    : $UNLINK"
  echo

  if [ ! -d "$DOTFILES_DIR" ]; then
    _error "Dotfiles directory not found: $DOTFILES_DIR"
    exit 1
  fi

  # Collect all dotfile pairs
  local pairs
  pairs="$(_collect_dotfiles)"

  if [ -z "$pairs" ]; then
    _warn "No dotfiles found in $DOTFILES_DIR"
    exit 0
  fi

  echo "━━━ Processing dotfiles ━━━"
  while IFS='|' read -r src dest; do
    [ -z "$src" ] && continue
    if [ "$UNLINK" = "true" ]; then
      _unlink_file "$dest"
    else
      _link_file "$src" "$dest"
    fi
  done <<< "$pairs"

  # Print summary
  echo
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║               LINK SUMMARY                          ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo "  ✓  Linked   : ${#LINK_OK[@]}"
  for t in "${LINK_OK[@]:-}"; do [ -n "$t" ] && echo "       - $t"; done
  echo "  ⊘  Skipped  : ${#LINK_SKIP[@]}"
  for t in "${LINK_SKIP[@]:-}"; do [ -n "$t" ] && echo "       - $t"; done
  if [ "${#LINK_BACKUP[@]}" -gt 0 ]; then
    echo "  ⚑  Backed up: ${#LINK_BACKUP[@]}"
    for t in "${LINK_BACKUP[@]}"; do echo "       - $t"; done
  fi
  if [ "${#LINK_FAIL[@]}" -gt 0 ]; then
    echo "  ✗  Failed   : ${#LINK_FAIL[@]}"
    for t in "${LINK_FAIL[@]}"; do echo "       - $t"; done
  fi
  echo
}

main "$@"
