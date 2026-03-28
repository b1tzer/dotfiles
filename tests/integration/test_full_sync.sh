#!/usr/bin/env bash
# =============================================================================
# tests/integration/test_full_sync.sh - 完整 sync 流程集成测试
# =============================================================================
# 使用 sample_tools.yaml + 缓存机制，验证完整 sync 流程。
# 首次运行可能下载资源，后续运行使用缓存，不重复下载。
#
# 注意：此测试在 DOTFILES_TEST_MODE=1 下运行，不执行实际安装，
# 但会验证缓存逻辑和流程控制的完整性。
# =============================================================================

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../.." && pwd)"
FIXTURES_DIR="$TESTS_DIR/../fixtures"
SAMPLE_YAML="$FIXTURES_DIR/sample_tools.yaml"

# 使用临时缓存目录，避免污染用户缓存
TEST_CACHE_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_CACHE_DIR"' EXIT

# 简单测试框架
_PASS=0
_FAIL=0

_assert_eq() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  [PASS] $desc"
    _PASS=$(( _PASS + 1 ))
  else
    echo "  [FAIL] $desc" >&2
    echo "         expected: '$expected'" >&2
    echo "         actual:   '$actual'" >&2
    _FAIL=$(( _FAIL + 1 ))
  fi
}

_assert_exit_code() {
  local desc="$1"
  local expected_code="$2"
  local actual_code="$3"
  if [[ "$expected_code" == "$actual_code" ]]; then
    echo "  [PASS] $desc (exit code: $actual_code)"
    _PASS=$(( _PASS + 1 ))
  else
    echo "  [FAIL] $desc" >&2
    echo "         expected exit code: $expected_code" >&2
    echo "         actual exit code:   $actual_code" >&2
    _FAIL=$(( _FAIL + 1 ))
  fi
}

_assert_contains() {
  local desc="$1"
  local haystack="$2"
  local needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  [PASS] $desc"
    _PASS=$(( _PASS + 1 ))
  else
    echo "  [FAIL] $desc" >&2
    echo "         expected to contain: '$needle'" >&2
    echo "         actual: '$haystack'" >&2
    _FAIL=$(( _FAIL + 1 ))
  fi
}

echo
echo "=== test_full_sync.sh (integration) ==="
echo "  Cache dir: $TEST_CACHE_DIR"
echo

# ---------------------------------------------------------------------------
# 测试 1：完整 sync 流程（mock 模式，使用 sample_tools.yaml）
# ---------------------------------------------------------------------------
echo "--- Test: Full sync with sample_tools.yaml (mock mode) ---"

output="$(
  DOTFILES_TEST_MODE=1 \
  DOTFILES_TOOLS_YAML="$SAMPLE_YAML" \
  DOTFILES_CACHE_DIR="$TEST_CACHE_DIR" \
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/sync.sh" 2>&1
)"
exit_code=$?

_assert_exit_code "Full sync exits 0" "0" "$exit_code"
_assert_contains "Full sync shows SYNC SUMMARY" "$output" "SYNC SUMMARY"

# ---------------------------------------------------------------------------
# 测试 2：--dry-run 完整流程
# ---------------------------------------------------------------------------
echo
echo "--- Test: Full sync --dry-run ---"

output="$(
  DOTFILES_TEST_MODE=1 \
  DOTFILES_TOOLS_YAML="$SAMPLE_YAML" \
  DOTFILES_CACHE_DIR="$TEST_CACHE_DIR" \
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/sync.sh" --dry-run 2>&1
)"
exit_code=$?

_assert_exit_code "--dry-run exits 0" "0" "$exit_code"
_assert_contains "--dry-run shows dry run info" "$output" "Dry run"

# ---------------------------------------------------------------------------
# 测试 3：缓存目录结构验证
# ---------------------------------------------------------------------------
echo
echo "--- Test: Cache directory structure ---"

# 确保缓存目录可以被创建
mkdir -p "$TEST_CACHE_DIR/scripts"
mkdir -p "$TEST_CACHE_DIR/binaries"

if [[ -d "$TEST_CACHE_DIR/scripts" ]]; then
  echo "  [PASS] Cache scripts/ directory exists"
  _PASS=$(( _PASS + 1 ))
else
  echo "  [FAIL] Cache scripts/ directory not created" >&2
  _FAIL=$(( _FAIL + 1 ))
fi

if [[ -d "$TEST_CACHE_DIR/binaries" ]]; then
  echo "  [PASS] Cache binaries/ directory exists"
  _PASS=$(( _PASS + 1 ))
else
  echo "  [FAIL] Cache binaries/ directory not created" >&2
  _FAIL=$(( _FAIL + 1 ))
fi

# ---------------------------------------------------------------------------
# 测试 4：cache status 命令
# ---------------------------------------------------------------------------
echo
echo "--- Test: cache status command ---"

output="$(
  DOTFILES_CACHE_DIR="$TEST_CACHE_DIR" \
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/cache.sh" status 2>&1
)"
exit_code=$?

_assert_exit_code "cache status exits 0" "0" "$exit_code"
_assert_contains "cache status shows cache dir" "$output" "$TEST_CACHE_DIR"

# ---------------------------------------------------------------------------
# 测试 5：cache clear 命令
# ---------------------------------------------------------------------------
echo
echo "--- Test: cache clear command ---"

# 创建一个假缓存文件
echo "fake cached content" > "$TEST_CACHE_DIR/scripts/test_cache_file"

output="$(
  DOTFILES_CACHE_DIR="$TEST_CACHE_DIR" \
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/cache.sh" clear 2>&1
)"
exit_code=$?

_assert_exit_code "cache clear exits 0" "0" "$exit_code"
_assert_contains "cache clear shows freed space" "$output" "Freed"

# ---------------------------------------------------------------------------
# 测试 6：bin/dotfiles 入口脚本 --help
# ---------------------------------------------------------------------------
echo
echo "--- Test: bin/dotfiles --help ---"

output="$(
  NO_COLOR=1 \
  bash "$REPO_ROOT/bin/dotfiles" --help 2>&1
)"
exit_code=$?

_assert_exit_code "dotfiles --help exits 0" "0" "$exit_code"
_assert_contains "dotfiles --help shows sync" "$output" "sync"
_assert_contains "dotfiles --help shows doctor" "$output" "doctor"
_assert_contains "dotfiles --help shows cache" "$output" "cache"

# ---------------------------------------------------------------------------
# 测试 7：未知子命令提示
# ---------------------------------------------------------------------------
echo
echo "--- Test: Unknown subcommand suggestion ---"

output="$(
  NO_COLOR=1 \
  bash "$REPO_ROOT/bin/dotfiles" syncc 2>&1
)" || true

_assert_contains "Unknown cmd shows error" "$output" "error:"
_assert_contains "Unknown cmd suggests similar" "$output" "Did you mean"

# ---------------------------------------------------------------------------
# 结果
# ---------------------------------------------------------------------------
echo
echo "  Results: $_PASS passed, $_FAIL failed"
echo

[[ "$_FAIL" -eq 0 ]]
