#!/usr/bin/env bash
# =============================================================================
# scripts/sync.sh - 核心同步引擎
# =============================================================================
# 读取 tools.yaml，在当前 OS 上安装/检查所有声明的工具。
#
# 本脚本通常由 dotfiles 入口脚本调用，也可直接运行。
#
# 用法（通过入口脚本）：
#   ./dotfiles sync                    # 安装所有工具
#   ./dotfiles sync --only git,jq      # 只处理指定工具
#   ./dotfiles sync --skip-runtimes    # 跳过 mise 运行时
#   ./dotfiles sync --force            # 强制重装已安装的工具
#   ./dotfiles sync --dry-run          # 预览，不实际安装
#   ./dotfiles sync --quiet / -q       # 只输出错误和摘要
#
# 直接运行：
#   bash scripts/sync.sh [flags]
#
# 退出码：
#   0 - 所有工具安装/跳过成功
#   1 - 一个或多个工具安装失败
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="${DOTFILES_LOG_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/sync.log}"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="/tmp/dotfiles-sync-$$.log"

# ---------------------------------------------------------------------------
# 加载 lib 模块（带缺失检测守卫）
# ---------------------------------------------------------------------------
_require_lib() {
  local lib_file="$REPO_ROOT/lib/$1"
  if [[ ! -f "$lib_file" ]]; then
    printf "  [✗]  error: required module 'lib/%s' not found. Is your repo complete?\n" "$1" >&2
    printf "         hint:  Run: git status  to check for missing files.\n" >&2
    exit 127
  fi
  # shellcheck source=/dev/null
  source "$lib_file"
}

_require_lib "logging.sh"
_require_lib "detect_os.sh"
_require_lib "pkg_manager.sh"

# ---------------------------------------------------------------------------
# 解析参数
# ---------------------------------------------------------------------------
DRY_RUN=false
ONLY_TOOLS=""        # 逗号分隔的工具名列表
SKIP_RUNTIMES=false
FORCE=false
QUIET=false
TOOLS_YAML="${DOTFILES_TOOLS_YAML:-$REPO_ROOT/tools.yaml}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)          DRY_RUN=true        ; shift ;;
    --only)             ONLY_TOOLS="$2"     ; shift 2 ;;
    --only=*)           ONLY_TOOLS="${1#--only=}" ; shift ;;
    --skip-runtimes)    SKIP_RUNTIMES=true  ; shift ;;
    --force|-f)         FORCE=true          ; shift ;;
    --quiet|-q)         QUIET=true          ; shift ;;
    # 兼容旧 flag（已废弃，保留向后兼容）
    --skip-mise-runtimes)
      SKIP_RUNTIMES=true
      _warn "Flag --skip-mise-runtimes is deprecated, use --skip-runtimes instead"
      shift ;;
    --tool)
      ONLY_TOOLS="$2"
      _warn "Flag --tool is deprecated, use --only instead"
      shift 2 ;;
    -h|--help)
      cat <<'EOF'
Usage: dotfiles sync [options]

Options:
  --only <tools>      Only process specified tools (comma-separated)
                      Example: --only git,ripgrep,jq
  --skip-runtimes     Skip mise-managed runtime installations (java/python/node/rust/cmake)
  --force, -f         Reinstall tools even if already installed
  --dry-run           Preview what would be installed, no actual changes
  --quiet, -q         Only output errors and final summary
  -h, --help          Show this help message

Examples:
  dotfiles sync                        # Sync all tools
  dotfiles sync --only git,ripgrep     # Only sync git and ripgrep
  dotfiles sync --skip-runtimes        # Skip heavy runtime installs
  dotfiles sync --dry-run              # Preview changes
  dotfiles sync --force                # Reinstall everything
EOF
      exit 0
      ;;
    *) _warn "Unknown argument: $1" ; shift ;;
  esac
done

# ---------------------------------------------------------------------------
# 日志包装（--quiet 模式下抑制 _info 和 _skip）
# ---------------------------------------------------------------------------
if [[ "$QUIET" == "true" ]]; then
  _info()  { :; }
  _skip()  { :; }
  _section() { :; }
fi

# ---------------------------------------------------------------------------
# 文件日志
# ---------------------------------------------------------------------------
_log() {
  local level="$1"; shift
  local msg="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

# 包装日志函数，同时写文件日志
_ok_log()    { _ok "$*";    _log "OK"    "$*"; }
_skip_log()  { _skip "$*";  _log "SKIP"  "$*"; }
_warn_log()  { _warn "$*";  _log "WARN"  "$*"; }
_error_log() { _error "$*"; _log "ERROR" "$*"; }
_info_log()  { _info "$*";  _log "INFO"  "$*"; }

# ---------------------------------------------------------------------------
# 依赖检查：yq（YAML 解析器）
# ---------------------------------------------------------------------------
_ensure_yq() {
  # 测试模式：通过外部 stub 文件安装 yq（不发起网络请求，不依赖外部模块）
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    # shellcheck source=/dev/null
    source "$REPO_ROOT/tests/fixtures/yq_stub.sh"
    return 0
  fi

  # 已安装则直接返回
  if command -v yq &>/dev/null; then
    _info_log "yq already installed: $(command -v yq)"
    return 0
  fi

  _info_log "yq not found. Installing yq for YAML parsing..."
  case "$OS_TYPE" in
    ubuntu)
      local _sudo=""
      [[ "$(id -u)" -ne 0 ]] && _sudo="sudo"

      # 优先尝试 snap（离线/内网友好），再回退到 wget 下载
      if command -v snap &>/dev/null; then
        _info_log "Installing yq via snap..."
        $_sudo snap install yq
        # snap 安装后二进制在 /snap/bin，确保加入 PATH
        export PATH="/snap/bin:$PATH"
        if command -v yq &>/dev/null; then
          return 0
        fi
        _warn_log "snap install yq succeeded but yq not found in PATH, falling back to wget..."
      fi

      _info_log "Installing yq via wget (github releases)..."
      local yq_arch="amd64"
      [[ "$(uname -m)" == "aarch64" ]] && yq_arch="arm64"
      if ! $_sudo wget -qO /usr/local/bin/yq \
          "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${yq_arch}"; then
        _error_actionable \
          "Failed to download yq" \
          "Network may be unavailable or GitHub is unreachable" \
          "Install yq manually, then re-run: ./dotfiles sync" \
          "  Ubuntu:  sudo snap install yq" \
          "  Or:      sudo apt install yq  (Ubuntu 21.04+)" \
          "  Or:      https://github.com/mikefarah/yq/releases"
        exit 1
      fi
      $_sudo chmod +x /usr/local/bin/yq
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        _error_actionable \
          "yq is required but not installed" \
          "Homebrew is also not available" \
          "Install yq manually: brew install yq" \
          "Or download from: https://github.com/mikefarah/yq/releases"
        exit 1
      fi
      brew install yq
      ;;
    *)
      _error_actionable \
        "yq is required but not installed" \
        "Unsupported OS: $OS_TYPE" \
        "Install yq manually: https://github.com/mikefarah/yq"
      exit 1
      ;;
  esac

  # 安装后验证
  if ! command -v yq &>/dev/null; then
    _error_actionable \
      "yq installation appeared to succeed but 'yq' is still not in PATH" \
      "Try opening a new terminal and re-running" \
      "Or install yq manually: https://github.com/mikefarah/yq"
    exit 1
  fi
  _ok_log "yq installed successfully: $(command -v yq)"
}

# ---------------------------------------------------------------------------
# 摘要追踪
# ---------------------------------------------------------------------------
declare -a SUMMARY_OK=()
declare -a SUMMARY_SKIP=()
declare -a SUMMARY_FAIL=()
declare -a SUMMARY_DEPRECATED=()
declare -a SUMMARY_MANUAL=()

# ---------------------------------------------------------------------------
# 处理单个工具条目
# ---------------------------------------------------------------------------
_process_tool() {
  local name="$1"
  local description check_cmd deprecated replaced_by migration_note
  local platform_method platform_install platform_script
  local platform_script_args platform_install_type platform_binary

  # 从 YAML 读取字段
  description="$(yq e ".tools[] | select(.name == \"$name\") | .description // \"\"" "$TOOLS_YAML")"
  check_cmd="$(yq e ".tools[] | select(.name == \"$name\") | .check_cmd // \"$name\"" "$TOOLS_YAML")"
  deprecated="$(yq e ".tools[] | select(.name == \"$name\") | .deprecated // false" "$TOOLS_YAML")"
  replaced_by="$(yq e ".tools[] | select(.name == \"$name\") | .replaced_by // \"\"" "$TOOLS_YAML")"
  migration_note="$(yq e ".tools[] | select(.name == \"$name\") | .migration_note // \"\"" "$TOOLS_YAML")"

  # 读取平台特定字段
  platform_method="$(yq e ".tools[] | select(.name == \"$name\") | .platforms.$OS_TYPE.method // \"\"" "$TOOLS_YAML")"
  platform_install="$(yq e ".tools[] | select(.name == \"$name\") | .platforms.$OS_TYPE.install // \"\"" "$TOOLS_YAML")"
  platform_script="$(yq e ".tools[] | select(.name == \"$name\") | .platforms.$OS_TYPE.script // \"\"" "$TOOLS_YAML")"
  platform_script_args="$(yq e ".tools[] | select(.name == \"$name\") | .platforms.$OS_TYPE.script_args // \"\"" "$TOOLS_YAML")"
  platform_install_type="$(yq e ".tools[] | select(.name == \"$name\") | .platforms.$OS_TYPE.install_type // \"\"" "$TOOLS_YAML")"
  platform_binary="$(yq e ".tools[] | select(.name == \"$name\") | .platforms.$OS_TYPE.binary // \"$name\"" "$TOOLS_YAML")"

  _info_log "▸ $name$([ -n "$description" ] && echo " ($description)")"

  # --- 处理废弃工具 ---
  if [[ "$deprecated" == "true" ]]; then
    if pkg_is_installed "$check_cmd"; then
      _warn_log "$name is DEPRECATED.$([ -n "$replaced_by" ] && echo " Replaced by: $replaced_by.")"
      [[ -n "$migration_note" ]] && _warn_log "Migration: $migration_note"
      SUMMARY_DEPRECATED+=("$name → ${replaced_by:-no replacement}")

      # 自动安装替代工具（如果未安装）
      if [[ -n "$replaced_by" ]]; then
        local replacement_check_cmd
        replacement_check_cmd="$(yq e ".tools[] | select(.name == \"$replaced_by\") | .check_cmd // \"$replaced_by\"" "$TOOLS_YAML" 2>/dev/null || echo "$replaced_by")"

        if ! pkg_is_installed "$replacement_check_cmd"; then
          if [[ "$DRY_RUN" == "true" ]]; then
            _info_log "[DRY-RUN] Would auto-install replacement: $replaced_by"
          else
            _info_log "Auto-installing replacement tool: $replaced_by"
            _process_tool "$replaced_by" || true  # non-fatal: replacement install
          fi
        else
          _info_log "Replacement tool '$replaced_by' is already installed."
        fi
      fi
    else
      _skip_log "$name (deprecated, not installed — skipping)"
    fi
    return 0
  fi

  # --- 检查平台支持 ---
  if [[ -z "$platform_method" ]]; then
    _skip_log "$name (not supported on $OS_TYPE)"
    SUMMARY_SKIP+=("$name (unsupported on $OS_TYPE)")
    return 0
  fi

  # --- 检查是否已安装（--force 时跳过此检查）---
  if [[ "$FORCE" == "false" ]] && pkg_is_installed "$check_cmd"; then
    _skip_log "$name (already installed)"
    SUMMARY_SKIP+=("$name")
    # mise 已安装时仍检查并补装 runtimes
    if [[ "$name" == "mise" && "$DRY_RUN" == "false" && "$SKIP_RUNTIMES" == "false" ]]; then
      _install_mise_runtimes
    fi
    return 0
  fi

  # --- Dry run：仅报告 ---
  if [[ "$DRY_RUN" == "true" ]]; then
    _info_log "[DRY-RUN] Would install: $name via $platform_method"
    SUMMARY_SKIP+=("$name (would install)")
    return 0
  fi

  # --- 安装 ---
  _info_log "Installing $name via $platform_method..."
  local rc=0

  case "$platform_method" in
    script)
      pkg_run_script "$platform_script" "$platform_install_type" "$platform_binary" $platform_script_args || rc=$?
      ;;
    manual)
      _skip_log "$name requires manual installation: $platform_install"
      SUMMARY_MANUAL+=("$name: $platform_install")
      return 0
      ;;
    *)
      pkg_install "$platform_install" "$platform_method" || rc=$?
      ;;
  esac

  if [[ "$rc" -eq 0 ]]; then
    _ok_log "$name installed successfully"
    SUMMARY_OK+=("$name")

    # 安装后：mise runtimes
    if [[ "$name" == "mise" && "$SKIP_RUNTIMES" == "false" ]]; then
      _install_mise_runtimes
    fi
  else
    _error_actionable \
      "failed to install $name" \
      "Installation exited with code $rc" \
      "Retry with: ./dotfiles sync --only $name"
    _log "ERROR" "$name installation FAILED (exit code: $rc)"
    SUMMARY_FAIL+=("$name")
  fi
}

# ---------------------------------------------------------------------------
# 安装 mise 管理的运行时
# ---------------------------------------------------------------------------
_install_mise_runtimes() {
  # Mock 模式：跳过所有 mise install 调用
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    local runtime_count
    runtime_count="$(yq e '.tools[] | select(.name == "mise") | .runtimes | length' "$TOOLS_YAML" 2>/dev/null || echo 0)"
    local i=0
    while [[ "$i" -lt "$runtime_count" ]]; do
      local rt_name rt_version
      rt_name="$(yq e ".tools[] | select(.name == \"mise\") | .runtimes[$i].name" "$TOOLS_YAML")"
      rt_version="$(yq e ".tools[] | select(.name == \"mise\") | .runtimes[$i].version" "$TOOLS_YAML")"
      echo "[MOCK] would install runtime: ${rt_name}@${rt_version}"
      i=$(( i + 1 ))
    done
    return 0
  fi

  local runtime_count
  runtime_count="$(yq e '.tools[] | select(.name == "mise") | .runtimes | length' "$TOOLS_YAML" 2>/dev/null || echo 0)"

  [[ "$runtime_count" -eq 0 ]] && return 0

  _info_log "Installing mise runtimes ($runtime_count declared)..."

  # 确保 mise 在 PATH 中
  export PATH="$HOME/.local/bin:$PATH"

  local i=0
  while [[ "$i" -lt "$runtime_count" ]]; do
    local rt_name rt_version
    rt_name="$(yq e ".tools[] | select(.name == \"mise\") | .runtimes[$i].name" "$TOOLS_YAML")"
    rt_version="$(yq e ".tools[] | select(.name == \"mise\") | .runtimes[$i].version" "$TOOLS_YAML")"

    if [[ -z "$rt_name" || "$rt_name" == "null" ]]; then
      i=$(( i + 1 ))
      continue
    fi

    local rt_spec="${rt_name}@${rt_version}"
    _info_log "  mise: installing $rt_spec ..."

    if mise install "$rt_name@$rt_version" 2>&1 | tee -a "$LOG_FILE"; then
      _ok_log "  mise runtime installed: $rt_spec"
    else
      _warn_log "  mise runtime FAILED: $rt_spec (non-fatal)"  # non-fatal: user can install later
    fi

    i=$(( i + 1 ))
  done
}

# ---------------------------------------------------------------------------
# 打印最终摘要
# ---------------------------------------------------------------------------
_print_summary() {
  echo
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║                   SYNC SUMMARY                      ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo
  echo "  ✓  Installed  : ${#SUMMARY_OK[@]}"
  for t in "${SUMMARY_OK[@]:-}"; do [[ -n "$t" ]] && echo "       - $t"; done

  echo "  ⊘  Skipped    : ${#SUMMARY_SKIP[@]}"
  for t in "${SUMMARY_SKIP[@]:-}"; do [[ -n "$t" ]] && echo "       - $t"; done

  if [[ "${#SUMMARY_FAIL[@]}" -gt 0 ]]; then
    echo "  ✗  Failed     : ${#SUMMARY_FAIL[@]}"
    for t in "${SUMMARY_FAIL[@]}"; do echo "       - $t"; done
  fi

  if [[ "${#SUMMARY_DEPRECATED[@]}" -gt 0 ]]; then
    echo "  ⚠  Deprecated : ${#SUMMARY_DEPRECATED[@]}"
    for t in "${SUMMARY_DEPRECATED[@]}"; do echo "       - $t"; done
  fi

  if [[ "${#SUMMARY_MANUAL[@]}" -gt 0 ]]; then
    echo "  ✎  Manual     : ${#SUMMARY_MANUAL[@]}"
    for t in "${SUMMARY_MANUAL[@]}"; do echo "       - $t"; done
  fi

  echo
  echo "  Log file: $LOG_FILE"
  echo

  # 有失败则返回非零
  [[ "${#SUMMARY_FAIL[@]}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  _banner "dotfiles sync  •  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "  OS      : $OS_TYPE ($OS_ARCH)"
  echo "  WSL     : $IS_WSL"
  echo "  Dry run : $DRY_RUN"
  echo "  Force   : $FORCE"
  echo "  Config  : $TOOLS_YAML"
  [[ -n "$ONLY_TOOLS" ]] && echo "  Only    : $ONLY_TOOLS"

  # 确保 yq 可用
  _ensure_yq

  # 初始化包管理器（更新索引）
  if [[ "$DRY_RUN" == "false" ]]; then
    _section "Initializing package manager"
    pkg_manager_init
  fi

  # 获取工具名列表
  local tool_names
  if [[ -n "$ONLY_TOOLS" ]]; then
    # 将逗号分隔转换为换行分隔
    tool_names="$(echo "$ONLY_TOOLS" | tr ',' '\n')"
  else
    tool_names="$(yq e '.tools[].name' "$TOOLS_YAML")"
  fi

  _section "Processing tools"

  # 逐工具处理；单个工具失败不阻断其他工具
  while IFS= read -r tool_name; do
    [[ -z "$tool_name" ]] && continue
    _process_tool "$tool_name" || {
      _error_log "Unexpected error processing tool: $tool_name"
      SUMMARY_FAIL+=("$tool_name (unexpected error)")
    }
  done <<< "$tool_names"

  _print_summary
}

main "$@"
