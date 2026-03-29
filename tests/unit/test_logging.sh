#!/usr/bin/env bash
# =============================================================================
# tests/unit/test_logging.sh - 测试日志函数输出格式
# =============================================================================
# 无网络依赖，验证日志函数的输出格式和 NO_COLOR 行为。
# =============================================================================

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../.." && pwd)"

# 简单测试框架
_PASS=0
_FAIL=0

# shellcheck source=tests/lib/assert.sh
source "$TESTS_DIR/../lib/assert.sh"

echo
echo "=== test_logging.sh ==="
echo

# ---------------------------------------------------------------------------
# 测试 1：基本输出格式（NO_COLOR=1 模式，避免 ANSI 干扰）
# ---------------------------------------------------------------------------
echo "--- Test: Basic output format (NO_COLOR=1) ---"

output="$(NO_COLOR=1 bash -c "source '$REPO_ROOT/lib/logging.sh'; _info 'hello world'" 2>&1)"
_assert_contains "_info contains message" "$output" "hello world"
_assert_contains "_info contains [i]" "$output" "[i]"

output="$(NO_COLOR=1 bash -c "source '$REPO_ROOT/lib/logging.sh'; _ok 'success'" 2>&1)"
_assert_contains "_ok contains message" "$output" "success"
_assert_contains "_ok contains [✓]" "$output" "[✓]"

output="$(NO_COLOR=1 bash -c "source '$REPO_ROOT/lib/logging.sh'; _warn 'warning msg'" 2>&1)"
_assert_contains "_warn contains message" "$output" "warning msg"
_assert_contains "_warn contains [!]" "$output" "[!]"

output="$(NO_COLOR=1 bash -c "source '$REPO_ROOT/lib/logging.sh'; _error 'error msg'" 2>&1)"
_assert_contains "_error contains message" "$output" "error msg"
_assert_contains "_error contains [✗]" "$output" "[✗]"

output="$(NO_COLOR=1 bash -c "source '$REPO_ROOT/lib/logging.sh'; _skip 'skipped'" 2>&1)"
_assert_contains "_skip contains message" "$output" "skipped"
_assert_contains "_skip contains [⊘]" "$output" "[⊘]"

output="$(NO_COLOR=1 bash -c "source '$REPO_ROOT/lib/logging.sh'; _section 'My Section'" 2>&1)"
_assert_contains "_section contains title" "$output" "My Section"
_assert_contains "_section contains ━━━" "$output" "━━━"

# ---------------------------------------------------------------------------
# 测试 2：NO_COLOR=1 时不含 ANSI 转义序列
# ---------------------------------------------------------------------------
echo
echo "--- Test: NO_COLOR=1 disables ANSI codes ---"

output="$(NO_COLOR=1 bash -c "source '$REPO_ROOT/lib/logging.sh'; _info 'test'" 2>&1)"
_assert_not_contains "NO_COLOR=1: no ESC codes in _info" "$output" $'\033['

output="$(NO_COLOR=1 bash -c "source '$REPO_ROOT/lib/logging.sh'; _ok 'test'" 2>&1)"
_assert_not_contains "NO_COLOR=1: no ESC codes in _ok" "$output" $'\033['

output="$(NO_COLOR=1 bash -c "source '$REPO_ROOT/lib/logging.sh'; _error 'test'" 2>&1)"
_assert_not_contains "NO_COLOR=1: no ESC codes in _error" "$output" $'\033['

# ---------------------------------------------------------------------------
# 测试 3：_error_actionable 三段式输出
# ---------------------------------------------------------------------------
echo
echo "--- Test: _error_actionable three-part format ---"

output="$(NO_COLOR=1 bash -c "source '$REPO_ROOT/lib/logging.sh'; _error_actionable 'something failed' 'network timeout' 'retry with: ./bin/dotfiles sync'" 2>&1)"
_assert_contains "_error_actionable contains 'error:'" "$output" "error:"
_assert_contains "_error_actionable contains 'cause:'" "$output" "cause:"
_assert_contains "_error_actionable contains 'hint:'" "$output" "hint:"
_assert_contains "_error_actionable contains what" "$output" "something failed"
_assert_contains "_error_actionable contains cause" "$output" "network timeout"
_assert_contains "_error_actionable contains hint" "$output" "retry with:"

# ---------------------------------------------------------------------------
# 测试 4：防重复 source
# ---------------------------------------------------------------------------
echo
echo "--- Test: Guard against double-sourcing ---"

output="$(NO_COLOR=1 bash -c "
  source '$REPO_ROOT/lib/logging.sh'
  source '$REPO_ROOT/lib/logging.sh'
  _info 'only once'
" 2>&1)"
# 应该只输出一次（防重复 source 守卫生效）
count="$(echo "$output" | grep -c "only once" || true)"
if [[ "$count" -eq 1 ]]; then
  echo "  [PASS] Double-source guard works (output appears once)"
  _PASS=$(( _PASS + 1 ))
else
  echo "  [FAIL] Double-source guard: expected 1 occurrence, got $count" >&2
  _FAIL=$(( _FAIL + 1 ))
fi

# ---------------------------------------------------------------------------
# 结果
# ---------------------------------------------------------------------------
echo
echo "  Results: $_PASS passed, $_FAIL failed"
echo

[[ "$_FAIL" -eq 0 ]]
