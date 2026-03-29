#!/usr/bin/env bash
# =============================================================================
# tests/lib/assert.sh - 共享测试断言函数库
# =============================================================================
# 所有单元测试文件通过 source 引入此文件，避免重复定义断言函数。
# =============================================================================

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
    echo "         actual output: '$haystack'" >&2
    _FAIL=$(( _FAIL + 1 ))
  fi
}

_assert_not_contains() {
  local desc="$1"
  local haystack="$2"
  local needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  [PASS] $desc"
    _PASS=$(( _PASS + 1 ))
  else
    echo "  [FAIL] $desc" >&2
    echo "         expected NOT to contain: '$needle'" >&2
    echo "         actual output: '$haystack'" >&2
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
