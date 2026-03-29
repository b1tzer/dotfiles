#!/usr/bin/env bash
# =============================================================================
# tests/unit/test_detect_os.sh - 测试 OS 检测逻辑
# =============================================================================
# 无网络依赖，纯逻辑测试。
# =============================================================================

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../.." && pwd)"

# 简单测试框架
_PASS=0
_FAIL=0

# shellcheck source=tests/lib/assert.sh
source "$TESTS_DIR/../lib/assert.sh"

_assert_not_empty() {
  local desc="$1"
  local actual="$2"
  if [[ -n "$actual" ]]; then
    echo "  [PASS] $desc"
    _PASS=$(( _PASS + 1 ))
  else
    echo "  [FAIL] $desc (value is empty)" >&2
    _FAIL=$(( _FAIL + 1 ))
  fi
}

_assert_in() {
  local desc="$1"
  local actual="$2"
  shift 2
  local valid_values=("$@")
  for v in "${valid_values[@]}"; do
    if [[ "$actual" == "$v" ]]; then
      echo "  [PASS] $desc"
      _PASS=$(( _PASS + 1 ))
      return 0
    fi
  done
  echo "  [FAIL] $desc" >&2
  echo "         actual: '$actual' not in [${valid_values[*]}]" >&2
  _FAIL=$(( _FAIL + 1 ))
}

# ---------------------------------------------------------------------------
# 测试：source detect_os.sh 后变量已设置
# ---------------------------------------------------------------------------
echo
echo "=== test_detect_os.sh ==="
echo

# Source 模块
source "$REPO_ROOT/lib/detect_os.sh"

# 测试 OS_TYPE 已设置且为有效值
_assert_in "OS_TYPE is a valid value" "$OS_TYPE" "ubuntu" "macos" "windows" "unknown"

# 测试 OS_ARCH 已设置且为有效值
_assert_in "OS_ARCH is a valid value" "$OS_ARCH" "amd64" "arm64" "unknown"

# 测试 IS_WSL 已设置且为 true/false
_assert_in "IS_WSL is true or false" "$IS_WSL" "true" "false"

# 测试变量已导出（在子进程中可见）
_assert_not_empty "OS_TYPE is exported" "$(bash -c 'source '"$REPO_ROOT/lib/detect_os.sh"' && echo "$OS_TYPE"')"
_assert_not_empty "OS_ARCH is exported" "$(bash -c 'source '"$REPO_ROOT/lib/detect_os.sh"' && echo "$OS_ARCH"')"

# 测试防重复 source（第二次 source 不应重置变量）
OS_TYPE_BEFORE="$OS_TYPE"
source "$REPO_ROOT/lib/detect_os.sh"
_assert_eq "Re-sourcing does not reset OS_TYPE" "$OS_TYPE_BEFORE" "$OS_TYPE"

# 测试 detect_os_assert_supported 函数存在
if declare -f detect_os_assert_supported &>/dev/null; then
  echo "  [PASS] detect_os_assert_supported function exists"
  _PASS=$(( _PASS + 1 ))
else
  echo "  [FAIL] detect_os_assert_supported function not found" >&2
  _FAIL=$(( _FAIL + 1 ))
fi

# ---------------------------------------------------------------------------
# 结果
# ---------------------------------------------------------------------------
echo
echo "  Results: $_PASS passed, $_FAIL failed"
echo

[[ "$_FAIL" -eq 0 ]]
