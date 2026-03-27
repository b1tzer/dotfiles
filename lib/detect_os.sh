#!/usr/bin/env bash
# =============================================================================
# lib/detect_os.sh - Operating System Detection Module
# =============================================================================
# Exports:
#   OS_TYPE   - "ubuntu" | "macos" | "windows" | "unknown"
#   OS_ARCH   - "x86_64" | "arm64" | "unknown"
#   IS_WSL    - "true" | "false"
#   IS_ARM    - "true" | "false"
#
# Usage:
#   source "$(dirname "$0")/../lib/detect_os.sh"
#   echo "Running on: $OS_TYPE"
# =============================================================================

# Prevent double-sourcing
if [ -n "${_DETECT_OS_LOADED:-}" ]; then
  return 0
fi
_DETECT_OS_LOADED=1

# ---------------------------------------------------------------------------
# Detect architecture
# ---------------------------------------------------------------------------
_raw_arch="$(uname -m 2>/dev/null || echo 'unknown')"
case "$_raw_arch" in
  x86_64|amd64)   OS_ARCH="x86_64" ;;
  arm64|aarch64)  OS_ARCH="arm64"  ;;
  *)               OS_ARCH="unknown" ;;
esac

IS_ARM="false"
[ "$OS_ARCH" = "arm64" ] && IS_ARM="true"

# ---------------------------------------------------------------------------
# Detect WSL (Windows Subsystem for Linux)
# ---------------------------------------------------------------------------
IS_WSL="false"
if [ -f /proc/version ] && grep -qi "microsoft" /proc/version 2>/dev/null; then
  IS_WSL="true"
fi

# ---------------------------------------------------------------------------
# Detect OS type
# ---------------------------------------------------------------------------
_kernel="$(uname -s 2>/dev/null || echo 'unknown')"

case "$_kernel" in
  Darwin)
    OS_TYPE="macos"
    ;;
  Linux)
    # Check if running in WSL - still treat as ubuntu/linux for package management
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "${ID:-}" in
        ubuntu|debian)  OS_TYPE="ubuntu" ;;
        fedora|rhel|centos|rocky|almalinux) OS_TYPE="fedora" ;;
        arch|manjaro)   OS_TYPE="arch"   ;;
        *)              OS_TYPE="ubuntu" ;;  # Default to ubuntu-style for unknown Linux
      esac
    else
      OS_TYPE="ubuntu"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    OS_TYPE="windows"
    ;;
  *)
    OS_TYPE="unknown"
    ;;
esac

# ---------------------------------------------------------------------------
# Export and print summary (only when sourced directly for debugging)
# ---------------------------------------------------------------------------
export OS_TYPE OS_ARCH IS_WSL IS_ARM

# Helper: print OS info
detect_os_info() {
  echo "OS_TYPE : $OS_TYPE"
  echo "OS_ARCH : $OS_ARCH"
  echo "IS_WSL  : $IS_WSL"
  echo "IS_ARM  : $IS_ARM"
}

# Helper: assert OS is supported
detect_os_assert_supported() {
  if [ "$OS_TYPE" = "unknown" ]; then
    echo "[ERROR] Unsupported operating system: $(uname -s)" >&2
    return 1
  fi
  return 0
}

# Run info if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  detect_os_info
fi
