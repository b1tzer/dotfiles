#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh - DEPRECATED 兼容层
# 请使用新入口：./dotfiles sync
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_BIN="$SCRIPT_DIR/bin/dotfiles"

printf "\033[1;33m[DEPRECATED]\033[0m bootstrap.sh 已废弃，请改用: ./dotfiles sync\n" >&2

if [[ ! -x "$DOTFILES_BIN" ]]; then
  printf "\033[0;31m[ERROR]\033[0m bin/dotfiles 不存在或不可执行: %s\n" "$DOTFILES_BIN" >&2
  exit 1
fi

# 参数映射：旧参数 → 新命令
CMD="sync"
EXTRA_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --pull)          CMD="update"              ;;
    --tools-only)    EXTRA_ARGS+=("--tools")   ;;
    --dotfiles-only) EXTRA_ARGS+=("--dotfiles") ;;
    --dry-run)       EXTRA_ARGS+=("--dry-run") ;;
    --skip-secrets)  ;;  # 新版无此参数，静默忽略
    -h|--help)
      printf "Usage: %s [options]\n" "$0"
      printf "DEPRECATED: 请使用 ./dotfiles sync\n\n"
      printf "参数映射：\n"
      printf "  --pull           → dotfiles update\n"
      printf "  --tools-only     → dotfiles sync --tools\n"
      printf "  --dotfiles-only  → dotfiles sync --dotfiles\n"
      printf "  --dry-run        → dotfiles sync --dry-run\n"
      exit 0
      ;;
    *) EXTRA_ARGS+=("$arg") ;;
  esac
done

exec "$DOTFILES_BIN" "$CMD" "${EXTRA_ARGS[@]}"
