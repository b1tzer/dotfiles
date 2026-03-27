#!/usr/bin/env bash
# =============================================================================
# lib/pkg_manager.sh - Package Manager Adapter Module
# =============================================================================
# Depends on: lib/detect_os.sh (must be sourced first)
#
# Exports:
#   PKG_MANAGER  - "apt" | "brew" | "winget" | "choco" | "dnf" | "pacman"
#
# Public functions:
#   pkg_install <package>          - Install a package
#   pkg_is_installed <cmd>         - Check if a command/tool is installed
#   pkg_manager_init               - Initialize/update package manager
#   pkg_run_script <url> [args]    - Download and run an install script
# =============================================================================

# Prevent double-sourcing
if [ -n "${_PKG_MANAGER_LOADED:-}" ]; then
  return 0
fi
_PKG_MANAGER_LOADED=1

# Ensure OS detection has run
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/detect_os.sh
source "$SCRIPT_DIR/detect_os.sh"

# ---------------------------------------------------------------------------
# Determine package manager based on OS
# ---------------------------------------------------------------------------
case "$OS_TYPE" in
  macos)
    if command -v brew &>/dev/null; then
      PKG_MANAGER="brew"
    else
      PKG_MANAGER="brew_missing"
    fi
    ;;
  ubuntu)
    PKG_MANAGER="apt"
    ;;
  fedora)
    PKG_MANAGER="dnf"
    ;;
  arch)
    PKG_MANAGER="pacman"
    ;;
  windows)
    if command -v winget &>/dev/null; then
      PKG_MANAGER="winget"
    elif command -v choco &>/dev/null; then
      PKG_MANAGER="choco"
    else
      PKG_MANAGER="unknown"
    fi
    ;;
  *)
    PKG_MANAGER="unknown"
    ;;
esac

export PKG_MANAGER

# ---------------------------------------------------------------------------
# pkg_manager_init: Update package index / ensure pkg manager is ready
# ---------------------------------------------------------------------------
pkg_manager_init() {
  echo "[INFO] Initializing package manager: $PKG_MANAGER"
  case "$PKG_MANAGER" in
    apt)
      sudo apt-get update -qq
      ;;
    brew)
      brew update --quiet
      ;;
    brew_missing)
      echo "[INFO] Homebrew not found. Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      # Re-detect brew after install
      if [ "$OS_ARCH" = "arm64" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        eval "$(/usr/local/bin/brew shellenv)"
      fi
      PKG_MANAGER="brew"
      ;;
    dnf)
      sudo dnf check-update -q || true
      ;;
    pacman)
      sudo pacman -Sy --noconfirm
      ;;
    winget|choco)
      # No explicit update step needed
      ;;
    *)
      echo "[WARN] Unknown package manager. Manual installation may be required." >&2
      ;;
  esac
}

# ---------------------------------------------------------------------------
# pkg_is_installed <check_cmd>
# Returns 0 if installed, 1 if not
# check_cmd can be:
#   - a plain command name: "git", "docker"
#   - a shell expression starting with "[": "[ -d $HOME/.nvm ]"
# ---------------------------------------------------------------------------
pkg_is_installed() {
  local check_cmd="$1"
  if [[ "$check_cmd" == \[* ]]; then
    # Shell expression check
    eval "$check_cmd" 2>/dev/null
    return $?
  else
    command -v "$check_cmd" &>/dev/null
    return $?
  fi
}

# ---------------------------------------------------------------------------
# pkg_install <package> [method] [extra_args]
# Installs a package using the current PKG_MANAGER
# method: apt | brew | winget | choco | script | manual
# ---------------------------------------------------------------------------
pkg_install() {
  local package="$1"
  local method="${2:-$PKG_MANAGER}"
  local extra_args="${3:-}"

  case "$method" in
    apt)
      sudo apt-get install -y "$package" $extra_args
      ;;
    brew)
      # Support cask installs: package may start with "--cask"
      # shellcheck disable=SC2086
      brew install $package $extra_args
      ;;
    winget)
      winget install --id "$package" --silent --accept-package-agreements --accept-source-agreements $extra_args
      ;;
    choco)
      choco install "$package" -y $extra_args
      ;;
    dnf)
      sudo dnf install -y "$package" $extra_args
      ;;
    pacman)
      sudo pacman -S --noconfirm "$package" $extra_args
      ;;
    script)
      # package is a URL here; handled by pkg_run_script
      pkg_run_script "$package"
      ;;
    manual)
      echo "[SKIP] '$package' requires manual installation: $extra_args"
      return 2  # Special return code: manual skip
      ;;
    *)
      echo "[ERROR] Unknown install method: $method" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# pkg_run_script <url> [args...]
# Downloads and executes a remote install script
# ---------------------------------------------------------------------------
pkg_run_script() {
  local url="$1"
  shift
  local args=("$@")

  echo "[INFO] Running install script from: $url"

  if command -v curl &>/dev/null; then
    curl -fsSL "$url" | bash -s -- "${args[@]}"
  elif command -v wget &>/dev/null; then
    wget -qO- "$url" | bash -s -- "${args[@]}"
  else
    echo "[ERROR] Neither curl nor wget is available to download install script." >&2
    return 1
  fi
}

# Run info if executed directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "PKG_MANAGER: $PKG_MANAGER"
  echo "OS_TYPE    : $OS_TYPE"
fi
