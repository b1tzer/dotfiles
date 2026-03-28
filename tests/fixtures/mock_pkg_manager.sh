#!/usr/bin/env bash
# =============================================================================
# tests/fixtures/mock_pkg_manager.sh - 通用 Mock 包管理器
# =============================================================================
# 供所有测试 source，覆盖 pkg_manager.sh 中的函数实现。
#
# 可配置变量：
#   MOCK_INSTALLED_TOOLS    逗号分隔的"已安装"工具列表（默认空）
#   MOCK_INSTALL_EXIT_CODE  pkg_install 返回的退出码（默认 0）
#   MOCK_SCRIPT_EXIT_CODE   pkg_run_script 返回的退出码（默认 0）
#
# 记录数组（测试后可检查）：
#   MOCK_INSTALLED_LOG      记录所有 pkg_install 调用的包名
#   MOCK_SCRIPT_LOG         记录所有 pkg_run_script 调用的 URL
#
# 用法：
#   source "$(dirname "$0")/../fixtures/mock_pkg_manager.sh"
# =============================================================================

# 可配置变量（测试脚本可覆盖）
MOCK_INSTALLED_TOOLS="${MOCK_INSTALLED_TOOLS:-}"
MOCK_INSTALL_EXIT_CODE="${MOCK_INSTALL_EXIT_CODE:-0}"
MOCK_SCRIPT_EXIT_CODE="${MOCK_SCRIPT_EXIT_CODE:-0}"

# 记录数组
declare -a MOCK_INSTALLED_LOG=()
declare -a MOCK_SCRIPT_LOG=()

# ---------------------------------------------------------------------------
# Mock 实现
# ---------------------------------------------------------------------------

# pkg_is_installed <cmd>
# 查询 MOCK_INSTALLED_TOOLS（逗号分隔），返回 0（已安装）或 1（未安装）
pkg_is_installed() {
  local cmd="$1"
  local mock_tools="${MOCK_INSTALLED_TOOLS:-}"

  if [[ -n "$mock_tools" ]]; then
    local IFS=','
    for t in $mock_tools; do
      [[ "$t" == "$cmd" ]] && return 0
    done
  fi
  return 1
}

# pkg_install <pkg> <method>
# 将 <pkg> 追加到 MOCK_INSTALLED_LOG，返回 MOCK_INSTALL_EXIT_CODE
pkg_install() {
  local pkg="$1"
  local method="${2:-}"
  echo "[MOCK] pkg_install: $pkg (method: $method)"
  MOCK_INSTALLED_LOG+=("$pkg")
  return "${MOCK_INSTALL_EXIT_CODE:-0}"
}

# pkg_run_script <url> <type> <binary> [args...]
# 将 URL 记录到 MOCK_SCRIPT_LOG，返回 MOCK_SCRIPT_EXIT_CODE
pkg_run_script() {
  local url="$1"
  local install_type="${2:-}"
  local binary="${3:-}"
  echo "[MOCK] pkg_run_script: $url (type: $install_type, binary: $binary)"
  MOCK_SCRIPT_LOG+=("$url")
  return "${MOCK_SCRIPT_EXIT_CODE:-0}"
}

# pkg_manager_init
# 无操作，返回 0
pkg_manager_init() {
  echo "[MOCK] pkg_manager_init: no-op"
  return 0
}

# ---------------------------------------------------------------------------
# 测试辅助函数
# ---------------------------------------------------------------------------

# 重置所有 mock 状态（在每个测试用例前调用）
mock_reset() {
  MOCK_INSTALLED_TOOLS=""
  MOCK_INSTALL_EXIT_CODE=0
  MOCK_SCRIPT_EXIT_CODE=0
  MOCK_INSTALLED_LOG=()
  MOCK_SCRIPT_LOG=()
}

# 断言：MOCK_INSTALLED_LOG 包含指定包名
assert_installed() {
  local pkg="$1"
  for logged in "${MOCK_INSTALLED_LOG[@]:-}"; do
    [[ "$logged" == "$pkg" ]] && return 0
  done
  echo "[ASSERT FAIL] Expected '$pkg' to be installed, but it was not." >&2
  echo "  MOCK_INSTALLED_LOG: ${MOCK_INSTALLED_LOG[*]:-<empty>}" >&2
  return 1
}

# 断言：MOCK_INSTALLED_LOG 不包含指定包名
assert_not_installed() {
  local pkg="$1"
  for logged in "${MOCK_INSTALLED_LOG[@]:-}"; do
    if [[ "$logged" == "$pkg" ]]; then
      echo "[ASSERT FAIL] Expected '$pkg' NOT to be installed, but it was." >&2
      return 1
    fi
  done
  return 0
}

# 断言：MOCK_SCRIPT_LOG 包含指定 URL
assert_script_called() {
  local url="$1"
  for logged in "${MOCK_SCRIPT_LOG[@]:-}"; do
    [[ "$logged" == "$url" ]] && return 0
  done
  echo "[ASSERT FAIL] Expected script '$url' to be called, but it was not." >&2
  echo "  MOCK_SCRIPT_LOG: ${MOCK_SCRIPT_LOG[*]:-<empty>}" >&2
  return 1
}
