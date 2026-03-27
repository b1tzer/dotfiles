#!/usr/bin/env bash
# =============================================================================
# lib/secret_check.sh - Sensitive Information Scanner
# =============================================================================
# Scans files for patterns that look like hardcoded secrets.
# Used by the Git pre-commit hook.
#
# Usage:
#   source lib/secret_check.sh
#   secret_check_files file1 file2 ...   # Returns 0=clean, 1=found secrets
#
#   Or run directly to scan staged files:
#   ./lib/secret_check.sh
# =============================================================================

# Prevent double-sourcing
if [ -n "${_SECRET_CHECK_LOADED:-}" ]; then
  return 0
fi
_SECRET_CHECK_LOADED=1

# ---------------------------------------------------------------------------
# Patterns that indicate potential secrets
# Format: "pattern|description"
# ---------------------------------------------------------------------------
SECRET_PATTERNS=(
  # Generic key=value patterns
  "password\s*=\s*['\"]?[^'\"\s]{6,}|Hardcoded password"
  "passwd\s*=\s*['\"]?[^'\"\s]{6,}|Hardcoded passwd"
  "secret\s*=\s*['\"]?[^'\"\s]{6,}|Hardcoded secret"
  "api_key\s*=\s*['\"]?[^'\"\s]{6,}|Hardcoded API key"
  "apikey\s*=\s*['\"]?[^'\"\s]{6,}|Hardcoded API key"
  "token\s*=\s*['\"]?[^'\"\s]{6,}|Hardcoded token"
  "auth_token\s*=\s*['\"]?[^'\"\s]{6,}|Hardcoded auth token"
  "access_token\s*=\s*['\"]?[^'\"\s]{6,}|Hardcoded access token"
  "private_key\s*=\s*['\"]?[^'\"\s]{6,}|Hardcoded private key"

  # Well-known token formats
  "ghp_[A-Za-z0-9]{36}|GitHub Personal Access Token"
  "github_pat_[A-Za-z0-9_]{82}|GitHub Fine-grained PAT"
  "ghs_[A-Za-z0-9]{36}|GitHub App token"
  "sk-[A-Za-z0-9]{48}|OpenAI API key"
  "AKIA[0-9A-Z]{16}|AWS Access Key ID"
  "npm_[A-Za-z0-9]{36}|NPM token"
  "xox[baprs]-[A-Za-z0-9-]{10,}|Slack token"
  "-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----|PEM private key block"

  # Connection strings
  "mongodb(\+srv)?://[^:]+:[^@]+@|MongoDB connection string with credentials"
  "postgres(ql)?://[^:]+:[^@]+@|PostgreSQL connection string with credentials"
  "mysql://[^:]+:[^@]+@|MySQL connection string with credentials"
  "redis://:?[^@]+@|Redis connection string with credentials"
)

# Files/patterns to always skip (false positive reduction)
SECRET_SKIP_PATTERNS=(
  "secrets.template.env"   # Template file is intentionally placeholder
  "*.md"                   # Documentation
  "secret_check.sh"        # This file itself
  "CHANGE_ME"              # Explicit placeholder value
)

# ---------------------------------------------------------------------------
# _is_skip_file <filepath>
# Returns 0 if the file should be skipped
# ---------------------------------------------------------------------------
_is_skip_file() {
  local filepath="$1"
  local basename
  basename="$(basename "$filepath")"

  for pattern in "${SECRET_SKIP_PATTERNS[@]}"; do
    # Simple glob match on basename
    # shellcheck disable=SC2254
    case "$basename" in
      $pattern) return 0 ;;
    esac
    # Also check if pattern appears in full path
    [[ "$filepath" == *"$pattern"* ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# secret_check_files <file1> [file2] ...
# Scans given files for secret patterns.
# Returns 0 if clean, 1 if secrets found.
# ---------------------------------------------------------------------------
secret_check_files() {
  local files=("$@")
  local found=0
  local findings=()

  for file in "${files[@]}"; do
    # Skip non-existent or binary files
    [ -f "$file" ] || continue
    file "$file" 2>/dev/null | grep -q "text" || continue

    # Skip whitelisted files
    _is_skip_file "$file" && continue

    local line_num=0
    while IFS= read -r line; do
      line_num=$((line_num + 1))

      # Skip comment lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      # Skip lines with explicit placeholder
      [[ "$line" =~ CHANGE_ME ]] && continue

      for pattern_entry in "${SECRET_PATTERNS[@]}"; do
        local pattern="${pattern_entry%%|*}"
        local description="${pattern_entry##*|}"

        if echo "$line" | grep -qiE "$pattern" 2>/dev/null; then
          findings+=("  ⚠  $file:$line_num - $description")
          found=1
          break
        fi
      done
    done < "$file"
  done

  if [ "$found" -eq 1 ]; then
    echo
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║         ⚠  POTENTIAL SECRETS DETECTED  ⚠            ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo
    for finding in "${findings[@]}"; do
      echo "$finding"
    done
    echo
    echo "  If these are false positives, you can:"
    echo "  1. Add the value as a placeholder (CHANGE_ME)"
    echo "  2. Move the value to secrets.local.env (gitignored)"
    echo "  3. Add the file to SECRET_SKIP_PATTERNS in lib/secret_check.sh"
    echo
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# secret_check_staged
# Scans all staged files (for use in pre-commit hook)
# ---------------------------------------------------------------------------
secret_check_staged() {
  local staged_files
  staged_files="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)"

  if [ -z "$staged_files" ]; then
    return 0
  fi

  local files_array=()
  while IFS= read -r f; do
    [ -n "$f" ] && files_array+=("$f")
  done <<< "$staged_files"

  secret_check_files "${files_array[@]}"
}

# Run directly if not sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$SCRIPT_DIR/.." || exit 1

  if [ $# -gt 0 ]; then
    secret_check_files "$@"
  else
    echo "[INFO] Scanning staged files..."
    secret_check_staged
  fi
fi
