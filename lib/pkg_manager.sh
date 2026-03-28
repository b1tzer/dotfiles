#!/usr/bin/env bash
# =============================================================================
# lib/pkg_manager.sh - 包管理器抽象层
# =============================================================================
# 提供跨平台的包管理函数：
#   pkg_manager_init              - 初始化包管理器（更新索引等）
#   pkg_is_installed <cmd>        - 检查命令是否已安装
#   pkg_install <pkg> <method>    - 安装包（apt/brew/cargo/pip 等）
#   pkg_run_script <url> <type> <binary> [args...]
#                                 - 下载并运行安装脚本（带本地缓存）
#
# 依赖：
#   - lib/detect_os.sh 已 source（OS_TYPE 变量已设置）
#   - lib/logging.sh 已 source（日志函数已可用）
#
# Mock 模式（单元测试）：
#   设置 DOTFILES_TEST_MODE=1 可将所有安装操作替换为 stub，不执行实际操作。
#
# 缓存：
#   DOTFILES_CACHE_DIR（默认 ~/.cache/dotfiles）
#   DOTFILES_CACHE_TTL_DAYS（默认 7 天）
# =============================================================================

# 防止重复 source
[[ -n "${_PKG_MANAGER_SH_LOADED:-}" ]] && return 0
_PKG_MANAGER_SH_LOADED=1

# ---------------------------------------------------------------------------
# 缓存配置
# ---------------------------------------------------------------------------
DOTFILES_CACHE_DIR="${DOTFILES_CACHE_DIR:-$HOME/.cache/dotfiles}"
DOTFILES_CACHE_TTL_DAYS="${DOTFILES_CACHE_TTL_DAYS:-7}"

# ---------------------------------------------------------------------------
# 内部工具函数
# ---------------------------------------------------------------------------

# 检查缓存文件是否有效（存在且未过期）
_pkg_cache_valid() {
  local cache_file="$1"
  [[ -f "$cache_file" ]] || return 1

  local ttl_seconds=$(( DOTFILES_CACHE_TTL_DAYS * 86400 ))
  local now
  now="$(date +%s)"
  local mtime
  # macOS 和 Linux 的 stat 语法不同
  if [[ "$(uname -s)" == "Darwin" ]]; then
    mtime="$(stat -f %m "$cache_file" 2>/dev/null || echo 0)"
  else
    mtime="$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)"
  fi

  (( now - mtime < ttl_seconds ))
}

# 将 URL 转换为缓存文件名（替换特殊字符）
_pkg_cache_filename() {
  local url="$1"
  local subdir="${2:-scripts}"
  local filename
  filename="$(echo "$url" | sed 's|https\?://||; s|[/:]|_|g')"
  echo "$DOTFILES_CACHE_DIR/$subdir/$filename"
}

# ---------------------------------------------------------------------------
# pkg_manager_init
# 初始化包管理器（更新软件包索引）
# ---------------------------------------------------------------------------
pkg_manager_init() {
  # Mock 模式：跳过
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    echo "[MOCK] would call: pkg_manager_init"
    return 0
  fi

  case "${OS_TYPE:-unknown}" in
    ubuntu)
      _info "Updating apt package index..."
      local _sudo=""
      [[ "$(id -u)" -ne 0 ]] && _sudo="sudo"
      $_sudo apt-get update -qq
      ;;
    macos)
      _info "Updating Homebrew..."
      brew update --quiet
      ;;
    *)
      _warn "pkg_manager_init: unsupported OS '$OS_TYPE', skipping"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# pkg_is_installed <cmd>
# 检查命令是否在 PATH 中可用
# 返回 0（已安装）或 1（未安装）
# ---------------------------------------------------------------------------
pkg_is_installed() {
  local cmd="$1"

  # Mock 模式：查询 MOCK_INSTALLED_TOOLS（逗号分隔）
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    local mock_tools="${MOCK_INSTALLED_TOOLS:-}"
    if [[ -n "$mock_tools" ]]; then
      # 检查 cmd 是否在逗号分隔列表中
      local IFS=','
      for t in $mock_tools; do
        [[ "$t" == "$cmd" ]] && return 0
      done
    fi
    return 1
  fi

  command -v "$cmd" &>/dev/null
}

# ---------------------------------------------------------------------------
# pkg_install <pkg> <method>
# 使用指定方法安装包
# method: apt | brew | cargo | pip | pip3 | npm | gem | go
# ---------------------------------------------------------------------------
pkg_install() {
  local pkg="$1"
  local method="${2:-}"

  # Mock 模式：记录调用，返回配置的退出码
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    echo "[MOCK] would call: pkg_install $pkg $method"
    MOCK_INSTALLED_LOG+=("$pkg")
    return "${MOCK_INSTALL_EXIT_CODE:-0}"
  fi

  case "$method" in
    apt)
      local _sudo=""
      [[ "$(id -u)" -ne 0 ]] && _sudo="sudo"
      $_sudo apt-get install -y "$pkg"
      ;;
    brew)
      brew install "$pkg"
      ;;
    cargo)
      cargo install "$pkg"
      ;;
    pip|pip3)
      pip3 install --user "$pkg"
      ;;
    npm)
      npm install -g "$pkg"
      ;;
    gem)
      gem install "$pkg"
      ;;
    go)
      go install "$pkg"
      ;;
    *)
      # 自动根据 OS_TYPE 选择包管理器
      case "${OS_TYPE:-unknown}" in
        ubuntu) pkg_install "$pkg" "apt" ;;
        macos)  pkg_install "$pkg" "brew" ;;
        *)
          _error "pkg_install: unknown method '$method' and unsupported OS '$OS_TYPE'"
          return 1
          ;;
      esac
      ;;
  esac
}

# ---------------------------------------------------------------------------
# pkg_run_script <url> <install_type> <binary> [extra_args...]
# 下载并运行安装脚本，支持本地缓存（7 天过期）
#
# install_type:
#   shell        - bash <(curl -fsSL <url>)
#   shell_args   - bash <(curl -fsSL <url>) <extra_args>
#   tarball      - 下载 .tar.gz 并解压 <binary> 到 ~/.local/bin/
#   zip          - 下载 .zip 并解压 <binary> 到 ~/.local/bin/
# ---------------------------------------------------------------------------
pkg_run_script() {
  local url="$1"
  local install_type="${2:-shell}"
  local binary="${3:-}"
  shift 3
  local extra_args=("$@")

  # Mock 模式：记录调用，返回配置的退出码
  if [[ "${DOTFILES_TEST_MODE:-0}" == "1" ]]; then
    echo "[MOCK] would call: pkg_run_script $url $install_type $binary"
    MOCK_SCRIPT_LOG+=("$url")
    return "${MOCK_SCRIPT_EXIT_CODE:-0}"
  fi

  # 确保缓存目录存在
  mkdir -p "$DOTFILES_CACHE_DIR/scripts"
  mkdir -p "$DOTFILES_CACHE_DIR/binaries"
  mkdir -p "$HOME/.local/bin"

  case "$install_type" in
    shell|shell_args)
      local cache_file
      cache_file="$(_pkg_cache_filename "$url" "scripts")"

      if _pkg_cache_valid "$cache_file"; then
        _info "[cache] hit: $(basename "$cache_file")"
      else
        _info "[cache] downloading: $url"
        if ! curl -fsSL "$url" -o "$cache_file" 2>&1; then
          # 区分 404 和网络超时
          local http_code
          http_code="$(curl -o /dev/null -s -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
          rm -f "$cache_file"
          if [[ "$http_code" == "404" ]]; then
            _error_actionable \
              "failed to download script: $url" \
              "HTTP 404 Not Found — the URL may be outdated" \
              "Check the project's release page for the latest install URL"
          else
            _error_actionable \
              "failed to download script: $url" \
              "Network error (HTTP $http_code) — possible connection timeout" \
              "Check your network connection, or retry with: ./dotfiles sync --only $binary"
          fi
          return 1
        fi
        _info "[cache] saved: $cache_file"
      fi

      bash "$cache_file" "${extra_args[@]}"
      ;;

    tarball)
      local cache_file
      cache_file="$(_pkg_cache_filename "$url" "binaries")"

      if _pkg_cache_valid "$cache_file"; then
        _info "[cache] hit: $(basename "$cache_file")"
      else
        _info "[cache] downloading: $url"
        if ! curl -fsSL "$url" -o "$cache_file" 2>&1; then
          local http_code
          http_code="$(curl -o /dev/null -s -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
          rm -f "$cache_file"
          if [[ "$http_code" == "404" ]]; then
            _error_actionable \
              "failed to download tarball: $url" \
              "HTTP 404 Not Found — the release may not exist for your architecture" \
              "Check the project's GitHub releases page"
          else
            _error_actionable \
              "failed to download tarball: $url" \
              "Network error (HTTP $http_code) — possible connection timeout" \
              "Check your network connection, or retry with: ./dotfiles sync --only $binary"
          fi
          return 1
        fi
        _info "[cache] saved: $cache_file"
      fi

      # 解压并安装 binary
      local tmp_dir
      tmp_dir="$(mktemp -d)"
      tar -xzf "$cache_file" -C "$tmp_dir"
      # 在解压目录中查找 binary
      local found_binary
      found_binary="$(find "$tmp_dir" -name "$binary" -type f | head -1)"
      if [[ -z "$found_binary" ]]; then
        _error_actionable \
          "binary '$binary' not found in tarball" \
          "The tarball structure may have changed" \
          "Check the project's release notes"
        rm -rf "$tmp_dir"
        return 1
      fi
      install -m 755 "$found_binary" "$HOME/.local/bin/$binary"
      rm -rf "$tmp_dir"
      _ok "Installed $binary to ~/.local/bin/"
      ;;

    zip)
      local cache_file
      cache_file="$(_pkg_cache_filename "$url" "binaries")"

      if _pkg_cache_valid "$cache_file"; then
        _info "[cache] hit: $(basename "$cache_file")"
      else
        _info "[cache] downloading: $url"
        if ! curl -fsSL "$url" -o "$cache_file" 2>&1; then
          local http_code
          http_code="$(curl -o /dev/null -s -w "%{http_code}" "$url" 2>/dev/null || echo 000)"
          rm -f "$cache_file"
          _error_actionable \
            "failed to download zip: $url" \
            "Network error (HTTP $http_code)" \
            "Check your network connection, or retry with: ./dotfiles sync --only $binary"
          return 1
        fi
        _info "[cache] saved: $cache_file"
      fi

      local tmp_dir
      tmp_dir="$(mktemp -d)"
      unzip -q "$cache_file" -d "$tmp_dir"
      local found_binary
      found_binary="$(find "$tmp_dir" -name "$binary" -type f | head -1)"
      if [[ -z "$found_binary" ]]; then
        _error_actionable \
          "binary '$binary' not found in zip" \
          "The zip structure may have changed" \
          "Check the project's release notes"
        rm -rf "$tmp_dir"
        return 1
      fi
      install -m 755 "$found_binary" "$HOME/.local/bin/$binary"
      rm -rf "$tmp_dir"
      _ok "Installed $binary to ~/.local/bin/"
      ;;

    *)
      _error "pkg_run_script: unknown install_type '$install_type'"
      return 1
      ;;
  esac
}
