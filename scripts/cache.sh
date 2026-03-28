#!/usr/bin/env bash
# =============================================================================
# scripts/cache.sh - 下载缓存管理
# =============================================================================
# 管理 dotfiles 工具的本地下载缓存，避免重复下载资源。
#
# 用法：
#   ./scripts/cache.sh status    # 列出所有缓存条目
#   ./scripts/cache.sh clear     # 清除所有缓存
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# 加载 lib 模块
# ---------------------------------------------------------------------------
_require_lib() {
  local lib_file="$REPO_ROOT/lib/$1"
  if [[ ! -f "$lib_file" ]]; then
    printf "  [✗]  error: required module 'lib/%s' not found. Is your repo complete?\n" "$1" >&2
    exit 127
  fi
  # shellcheck source=/dev/null
  source "$lib_file"
}

_require_lib "logging.sh"

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
DOTFILES_CACHE_DIR="${DOTFILES_CACHE_DIR:-$HOME/.cache/dotfiles}"
DOTFILES_CACHE_TTL_DAYS="${DOTFILES_CACHE_TTL_DAYS:-7}"

# ---------------------------------------------------------------------------
# 格式化文件大小（人类可读）
# ---------------------------------------------------------------------------
_format_size() {
  local bytes="$1"
  if (( bytes >= 1073741824 )); then
    printf "%.1f GB" "$(echo "scale=1; $bytes / 1073741824" | bc)"
  elif (( bytes >= 1048576 )); then
    printf "%.1f MB" "$(echo "scale=1; $bytes / 1048576" | bc)"
  elif (( bytes >= 1024 )); then
    printf "%.1f KB" "$(echo "scale=1; $bytes / 1024" | bc)"
  else
    printf "%d B" "$bytes"
  fi
}

# ---------------------------------------------------------------------------
# 获取文件修改时间（跨平台）
# ---------------------------------------------------------------------------
_file_mtime() {
  local file="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f %m "$file" 2>/dev/null || echo 0
  else
    stat -c %Y "$file" 2>/dev/null || echo 0
  fi
}

# ---------------------------------------------------------------------------
# cache status：列出所有缓存条目
# ---------------------------------------------------------------------------
_cmd_status() {
  if [[ ! -d "$DOTFILES_CACHE_DIR" ]]; then
    _info "Cache directory does not exist: $DOTFILES_CACHE_DIR"
    _info "No cached files found."
    return 0
  fi

  echo
  echo "  Cache directory: $DOTFILES_CACHE_DIR"
  echo "  TTL: $DOTFILES_CACHE_TTL_DAYS days"
  echo

  local total_bytes=0
  local file_count=0
  local now
  now="$(date +%s)"
  local ttl_seconds=$(( DOTFILES_CACHE_TTL_DAYS * 86400 ))

  # 表头
  printf "  %-50s  %8s  %-20s  %s\n" "FILE" "SIZE" "CACHED AT" "STATUS"
  printf "  %-50s  %8s  %-20s  %s\n" "$(printf '%0.s─' {1..50})" "$(printf '%0.s─' {1..8})" "$(printf '%0.s─' {1..20})" "$(printf '%0.s─' {1..10})"

  while IFS= read -r -d '' file; do
    [[ -f "$file" ]] || continue

    local rel_path="${file#$DOTFILES_CACHE_DIR/}"
    local file_size
    file_size="$(wc -c < "$file" 2>/dev/null || echo 0)"
    local mtime
    mtime="$(_file_mtime "$file")"
    local cached_at
    cached_at="$(date -d "@$mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$mtime" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
    local age=$(( now - mtime ))
    local status

    if (( age < ttl_seconds )); then
      local remaining=$(( (ttl_seconds - age) / 86400 ))
      status="valid (${remaining}d left)"
    else
      status="expired"
    fi

    printf "  %-50s  %8s  %-20s  %s\n" \
      "${rel_path:0:50}" \
      "$(_format_size "$file_size")" \
      "$cached_at" \
      "$status"

    total_bytes=$(( total_bytes + file_size ))
    file_count=$(( file_count + 1 ))
  done < <(find "$DOTFILES_CACHE_DIR" -type f -print0 2>/dev/null | sort -z)

  echo
  if [[ "$file_count" -eq 0 ]]; then
    _info "No cached files found."
  else
    printf "  Total: %d files, %s\n" "$file_count" "$(_format_size "$total_bytes")"
  fi
  echo
}

# ---------------------------------------------------------------------------
# cache clear：删除所有缓存文件
# ---------------------------------------------------------------------------
_cmd_clear() {
  if [[ ! -d "$DOTFILES_CACHE_DIR" ]]; then
    _info "Cache directory does not exist. Nothing to clear."
    return 0
  fi

  # 计算总大小
  local total_bytes=0
  while IFS= read -r -d '' file; do
    [[ -f "$file" ]] || continue
    local file_size
    file_size="$(wc -c < "$file" 2>/dev/null || echo 0)"
    total_bytes=$(( total_bytes + file_size ))
  done < <(find "$DOTFILES_CACHE_DIR" -type f -print0 2>/dev/null)

  if [[ "$total_bytes" -eq 0 ]]; then
    _info "Cache is already empty."
    return 0
  fi

  _info "Clearing cache: $DOTFILES_CACHE_DIR"
  rm -rf "${DOTFILES_CACHE_DIR:?}"/*
  _ok "Cache cleared. Freed: $(_format_size "$total_bytes")"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local action="${1:-}"

  case "$action" in
    status)
      _cmd_status
      ;;
    clear)
      _cmd_clear
      ;;
    ""|--help|-h)
      cat <<'EOF'
Usage: dotfiles cache <action>

Actions:
  status    List all cached files with size and expiry info
  clear     Delete all cached files and show freed disk space

Examples:
  dotfiles cache status    # Show cache contents
  dotfiles cache clear     # Clear all cached files
EOF
      ;;
    *)
      printf "  [✗]  error: unknown cache action '%s'\n" "$action" >&2
      printf "         hint:  Use 'status' or 'clear'\n" >&2
      exit 1
      ;;
  esac
}

main "$@"
