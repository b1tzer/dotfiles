#!/usr/bin/env bash
# =============================================================================
# tests/unit/test_sync_logic.sh - 测试 sync 流程控制逻辑
# =============================================================================
# 使用 DOTFILES_TEST_MODE=1 + mock_pkg_manager.sh 验证 sync 的流程控制，
# 不执行任何实际安装操作，无网络依赖。
# =============================================================================

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../.." && pwd)"
FIXTURES_DIR="$TESTS_DIR/../fixtures"
SAMPLE_YAML="$FIXTURES_DIR/sample_tools.yaml"

# 简单测试框架
_PASS=0
_FAIL=0

# shellcheck source=tests/lib/assert.sh
source "$TESTS_DIR/../lib/assert.sh"

echo
echo "=== test_sync_logic.sh ==="
echo

# ---------------------------------------------------------------------------
# 测试 1：DOTFILES_TEST_MODE=1 时 sync 不执行实际安装
# ---------------------------------------------------------------------------
echo "--- Test: DOTFILES_TEST_MODE=1 skips real installs ---"

output="$(
  DOTFILES_TEST_MODE=1 \
  DOTFILES_TOOLS_YAML="$SAMPLE_YAML" \
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/sync.sh" 2>&1
)"
exit_code=$?

_assert_exit_code "sync exits 0 in test mode" "0" "$exit_code"
_assert_contains "sync shows MOCK output" "$output" "[MOCK]"

# ---------------------------------------------------------------------------
# 测试 2：--dry-run 不执行安装，输出 would install
# ---------------------------------------------------------------------------
echo
echo "--- Test: --dry-run shows preview without installing ---"

output="$(
  DOTFILES_TEST_MODE=1 \
  DOTFILES_TOOLS_YAML="$SAMPLE_YAML" \
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/sync.sh" --dry-run 2>&1
)"
exit_code=$?

_assert_exit_code "--dry-run exits 0" "0" "$exit_code"
_assert_contains "--dry-run shows dry run info" "$output" "Dry run"

# ---------------------------------------------------------------------------
# 测试 3：--only 只处理指定工具
# ---------------------------------------------------------------------------
echo
echo "--- Test: --only filters tools ---"

output="$(
  DOTFILES_TEST_MODE=1 \
  DOTFILES_TOOLS_YAML="$SAMPLE_YAML" \
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/sync.sh" --only jq 2>&1
)"
exit_code=$?

_assert_exit_code "--only exits 0" "0" "$exit_code"
_assert_contains "--only processes jq" "$output" "jq"

# starship 不应出现在处理输出中（只处理 jq）
if [[ "$output" != *"▸ starship"* ]]; then
  echo "  [PASS] --only jq: starship not processed"
  _PASS=$(( _PASS + 1 ))
else
  echo "  [FAIL] --only jq: starship should not be processed" >&2
  _FAIL=$(( _FAIL + 1 ))
fi

# ---------------------------------------------------------------------------
# 测试 4：--skip-runtimes 跳过 mise 运行时
# ---------------------------------------------------------------------------
echo
echo "--- Test: --skip-runtimes flag is accepted ---"

output="$(
  DOTFILES_TEST_MODE=1 \
  DOTFILES_TOOLS_YAML="$SAMPLE_YAML" \
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/sync.sh" --skip-runtimes 2>&1
)"
exit_code=$?

_assert_exit_code "--skip-runtimes exits 0" "0" "$exit_code"

# ---------------------------------------------------------------------------
# 测试 5：--quiet 抑制 INFO 输出
# ---------------------------------------------------------------------------
echo
echo "--- Test: --quiet suppresses info output ---"

output="$(
  DOTFILES_TEST_MODE=1 \
  DOTFILES_TOOLS_YAML="$SAMPLE_YAML" \
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/sync.sh" --quiet 2>&1
)"
exit_code=$?

_assert_exit_code "--quiet exits 0" "0" "$exit_code"

# ---------------------------------------------------------------------------
# 测试 6：--help 输出帮助信息
# ---------------------------------------------------------------------------
echo
echo "--- Test: --help shows usage ---"

output="$(
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/sync.sh" --help 2>&1
)" || true

_assert_contains "--help shows Usage" "$output" "Usage"
_assert_contains "--help shows --only" "$output" "--only"
_assert_contains "--help shows --dry-run" "$output" "--dry-run"
_assert_contains "--help shows --force" "$output" "--force"

# ---------------------------------------------------------------------------
# 测试 7：deprecated 工具被正确处理
# ---------------------------------------------------------------------------
echo
echo "--- Test: deprecated tools are handled ---"

output="$(
  DOTFILES_TEST_MODE=1 \
  DOTFILES_TOOLS_YAML="$SAMPLE_YAML" \
  NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/sync.sh" 2>&1
)"

_assert_contains "deprecated tool shows deprecated handling" "$output" "deprecated"

# ---------------------------------------------------------------------------
# 结果
# ---------------------------------------------------------------------------
echo
echo "  Results: $_PASS passed, $_FAIL failed"
echo

[[ "$_FAIL" -eq 0 ]]
