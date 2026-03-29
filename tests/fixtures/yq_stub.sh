#!/usr/bin/env bash
# =============================================================================
# tests/fixtures/yq_stub.sh - 测试用 yq stub 安装器
# =============================================================================
# 在测试模式下安装一个基于 awk 的 yq stub，避免网络请求和外部依赖。
# 由 sync.sh 的 _ensure_yq 在 DOTFILES_TEST_MODE=1 时 source 调用。
#
# 用法：
#   source "$REPO_ROOT/tests/fixtures/yq_stub.sh"
# =============================================================================

if ! command -v yq &>/dev/null; then
  echo "[MOCK] _ensure_yq: installing yq stub for test mode"
  local stub_dir="${TMPDIR:-/tmp}/dotfiles_test_$$"
  mkdir -p "$stub_dir"

  cat > "$stub_dir/yq" <<'STUB'
#!/usr/bin/env bash
# Minimal yq stub for dotfiles test mode
# Supports the specific yq e queries used in sync.sh

expr="$2"
file="$3"

[[ -z "$file" || ! -f "$file" ]] && exit 0

# .tools[].name  →  list all tool names
if [[ "$expr" == ".tools[].name" ]]; then
  awk '/^  - name:/{print $3}' "$file"
  exit 0
fi

# .tools | length  →  count tools
if [[ "$expr" == ".tools | length" ]]; then
  awk '/^  - name:/{c++} END{print c+0}' "$file"
  exit 0
fi

# .tools[N].name  →  Nth tool name (0-indexed)
if [[ "$expr" =~ ^\.tools\[([0-9]+)\]\.name$ ]]; then
  idx="${BASH_REMATCH[1]}"
  awk -v idx="$idx" '/^  - name:/{c++; if(c-1==idx) print $3}' "$file"
  exit 0
fi

# .tools[] | select(.name == "X") | .FIELD // "DEFAULT"
# 使用纯 awk 解析 YAML 工具块
if [[ "$expr" =~ select\(\.name\ ==\ \"([^\"]+)\"\)\ \|\ \. ]]; then
  # 提取 tool_name
  tool_name="$(echo "$expr" | sed 's/.*select(\.name == "\([^"]*\)").*/\1/')"
  # 提取 field_path（去掉 // "default" 部分）
  field_expr="$(echo "$expr" | sed 's/.*select(\.name == "[^"]*") | \.\(.*\)/\1/')"
  # 提取 default 值（支持带引号和不带引号的默认值）
  default_val=""
  if [[ "$field_expr" == *' // '* ]]; then
    # 提取 // 后面的默认值（去掉引号）
    default_val="$(echo "$field_expr" | sed 's/.*\/\/ *"\([^"]*\)".*/\1/' | sed 's/.*\/\/ *\([^ ]*\)/\1/' | tr -d '"')"
    field_path="$(echo "$field_expr" | sed 's/ \/\/ .*//' | tr -d ' ')"
  else
    field_path="$(echo "$field_expr" | tr -d ' ')"
  fi

  # 用 awk 在 YAML 中找到工具块并提取字段
  # 策略：找到 "  - name: $tool_name" 行，然后在后续行中查找字段
  awk -v tool="$tool_name" -v field="$field_path" -v dflt="$default_val" '
  BEGIN { in_tool=0; found=0; result="" }
  /^  - name:/ {
    if ($3 == tool) { in_tool=1 }
    else if (in_tool) { in_tool=0 }
  }
  in_tool && !found {
    # 处理简单字段（如 deprecated: true）
    if (field !~ /\./) {
      if (match($0, "^[[:space:]]+" field ":")) {
        val = $0
        sub(/^[[:space:]]*[^:]+:[[:space:]]*/, "", val)
        gsub(/^["\x27]|["\x27]$/, "", val)
        if (val == "") val = dflt
        result = val
        found = 1
      }
    } else {
      # 处理嵌套字段（如 platforms.ubuntu.method）
      # 简化：直接搜索最后一个字段名
      n = split(field, parts, ".")
      last_field = parts[n]
      if (match($0, "^[[:space:]]+" last_field ":")) {
        val = $0
        sub(/^[[:space:]]*[^:]+:[[:space:]]*/, "", val)
        gsub(/^["\x27]|["\x27]$/, "", val)
        if (val == "") val = dflt
        result = val
        found = 1
      }
    }
  }
  END {
    if (found) print result
    else print dflt
  }
  ' "$file"
  exit 0
fi

# .tools[] | select(.name == "mise") | .runtimes | length
if [[ "$expr" =~ select\(\.name\ ==\ \"([^\"]+)\"\)\ \|\ \.runtimes\ \|\ length ]]; then
  echo "0"
  exit 0
fi

# .tools[] | select(.name == "mise") | .runtimes[N].field
if [[ "$expr" =~ select\(\.name\ ==\ \"([^\"]+)\"\)\ \|\ \.runtimes\[([0-9]+)\]\.([a-z_]+) ]]; then
  echo ""
  exit 0
fi

# Default: empty
echo ""
STUB

  chmod +x "$stub_dir/yq"
  export PATH="$stub_dir:$PATH"
  echo "[MOCK] _ensure_yq: yq stub installed at $stub_dir/yq"
fi
