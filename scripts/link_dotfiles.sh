#!/usr/bin/env bash
# =============================================================================
# scripts/link_dotfiles.sh - Dotfiles 软链接管理器
# =============================================================================
# 从 $HOME 创建指向仓库 dotfiles/ 目录的软链接。
# 处理：
#   - 链接前备份已存在的文件
#   - 平台特定 dotfile 选择（.zshrc.macos / .zshrc.ubuntu）
#   - 嵌套配置文件（如 .config/starship.toml）
#   - 含空格或特殊字符的文件名（使用 -print0 / read -d ''）
#
# 用法：
#   ./scripts/link_dotfiles.sh              # 链接所有 dotfiles
#   ./scripts/link_dotfiles.sh --dry-run    # 预览，不实际操作
#   ./scripts/link_dotfiles.sh --unlink     # 移除软链接（恢复备份）
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

# ---------------------------------------------------------------------------
# 解析参数
# ---------------------------------------------------------------------------
DRY_RUN=false
UNLINK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true  ; shift ;;
    --unlink)  UNLINK=true   ; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: link_dotfiles.sh [--dry-run] [--unlink]

Options:
  --dry-run   Show what would be linked without making changes
  --unlink    Remove symlinks and restore backups
  -h, --help  Show this help message
EOF
      exit 0
      ;;
    *) _warn "Unknown argument: $1" ; shift ;;
  esac
done

# ---------------------------------------------------------------------------
# 追踪数组
# ---------------------------------------------------------------------------
declare -a LINK_OK=()
declare -a LINK_SKIP=()
declare -a LINK_FAIL=()
declare -a LINK_BACKUP=()

# ---------------------------------------------------------------------------
# _backup_file <path>
# 将文件/目录备份为 <path>.bak.<timestamp>
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
# 创建从 $HOME/<dest> → <repo>/dotfiles/<src> 的软链接
# 失败时记录到 LINK_FAIL 并继续（不因 set -e 退出）
# ---------------------------------------------------------------------------
_link_file() {
  local src="$1"    # 仓库中的绝对路径
  local dest="$2"   # $HOME 中的绝对路径

  local rel_dest="${dest/#$HOME\//~/}"

  # 确保父目录存在（mkdir -p 处理嵌套路径）
  local dest_dir
  dest_dir="$(dirname "$dest")"
  if [[ ! -d "$dest_dir" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      _info "[DRY-RUN] Would create directory: $dest_dir"
    else
      mkdir -p "$dest_dir"
    fi
  fi

  # Case 1：已是指向我们文件的软链接
  if [[ -L "$dest" ]]; then
    local current_target
    current_target="$(readlink "$dest")"
    if [[ "$current_target" == "$src" ]]; then
      _skip "$rel_dest (already linked)"
      LINK_SKIP+=("$rel_dest")
      return 0
    else
      _warn "$rel_dest is a symlink to a different target: $current_target"
      if [[ "$DRY_RUN" == "false" ]]; then
        rm "$dest"
      fi
    fi
  fi

  # Case 2：普通文件或目录已存在 — 先备份
  if [[ -e "$dest" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      _info "[DRY-RUN] Would backup: $dest"
    else
      _backup_file "$dest"
    fi
  fi

  # 创建软链接
  if [[ "$DRY_RUN" == "true" ]]; then
    _info "[DRY-RUN] Would link: $rel_dest → $src"
    LINK_SKIP+=("$rel_dest (would link)")
  else
    # 使用子 shell 捕获错误，避免 set -e 导致整个脚本退出
    if ln -sf "$src" "$dest" 2>/dev/null; then
      _ok "Linked: $rel_dest → $src"
      LINK_OK+=("$rel_dest")
    else
      _error "Failed to link: $rel_dest → $src"
      LINK_FAIL+=("$rel_dest")
      # 继续处理其他文件（non-fatal per file）
    fi
  fi
}

# ---------------------------------------------------------------------------
# _unlink_file <dest_in_home>
# 移除软链接并恢复最近的备份（如有）
# ---------------------------------------------------------------------------
_unlink_file() {
  local dest="$1"
  local rel_dest="${dest/#$HOME\//~/}"

  if [[ ! -L "$dest" ]]; then
    _skip "$rel_dest (not a symlink)"
    return 0
  fi

  rm "$dest"
  _info "Removed symlink: $rel_dest"

  # 查找并恢复最近的备份
  local latest_backup
  latest_backup="$(ls -t "${dest}.bak."* 2>/dev/null | head -1 || true)"
  if [[ -n "$latest_backup" ]]; then
    mv "$latest_backup" "$dest"
    _ok "Restored backup: $latest_backup → $dest"
  fi
}

# ---------------------------------------------------------------------------
# _collect_dotfiles
# 输出所有待链接的 "src|dest" 对。
# 使用 -print0 + read -d '' 正确处理含空格的文件名。
# 跳过平台特定变体（*.macos, *.ubuntu 等）。
# ---------------------------------------------------------------------------
_collect_dotfiles() {
  # 使用 -print0 处理含空格/特殊字符的文件名
  while IFS= read -r -d '' file; do
    local rel_path="${file#$DOTFILES_DIR/}"

    # 跳过平台特定变体（它们通过 source 引入，不直接链接）
    if [[ "$rel_path" =~ \.(macos|ubuntu|windows|linux)$ ]]; then
      continue
    fi

    # 计算 $HOME 中的目标路径
    local dest="$HOME/$rel_path"

    printf '%s|%s\0' "$file" "$dest"
  done < <(find "$DOTFILES_DIR" -type f -print0 | sort -z)
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

  if [[ ! -d "$DOTFILES_DIR" ]]; then
    _error "Dotfiles directory not found: $DOTFILES_DIR"
    exit 1
  fi

  _section "Processing dotfiles"

  # 使用 -print0 / read -d '' 处理含空格的文件名
  local found_any=false
  while IFS='|' read -r -d '' src dest; do
    [[ -z "$src" ]] && continue
    found_any=true
    if [[ "$UNLINK" == "true" ]]; then
      _unlink_file "$dest"
    else
      _link_file "$src" "$dest"
    fi
  done < <(_collect_dotfiles)

  if [[ "$found_any" == "false" ]]; then
    _warn "No dotfiles found in $DOTFILES_DIR"
    exit 0
  fi

  # 打印摘要
  echo
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║               LINK SUMMARY                          ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo "  ✓  Linked   : ${#LINK_OK[@]}"
  for t in "${LINK_OK[@]:-}"; do [[ -n "$t" ]] && echo "       - $t"; done
  echo "  ⊘  Skipped  : ${#LINK_SKIP[@]}"
  for t in "${LINK_SKIP[@]:-}"; do [[ -n "$t" ]] && echo "       - $t"; done
  if [[ "${#LINK_BACKUP[@]}" -gt 0 ]]; then
    echo "  ⚑  Backed up: ${#LINK_BACKUP[@]}"
    for t in "${LINK_BACKUP[@]}"; do echo "       - $t"; done
  fi
  if [[ "${#LINK_FAIL[@]}" -gt 0 ]]; then
    echo "  ✗  Failed   : ${#LINK_FAIL[@]}"
    for t in "${LINK_FAIL[@]}"; do echo "       - $t"; done
    echo
    return 1
  fi
  echo
}

main "$@"
