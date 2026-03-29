# 需求文档：dotfiles 项目精简重构

## 引言

本次重构的核心目标是：**每个文件都不可替代，内部功能高度内敛，消除一切冗余**。

通过对所有核心文件的逐行阅读，识别出以下结构性冗余：

| 问题 | 当前状态 | 目标状态 |
|------|---------|---------|
| `bootstrap.sh` 368行完整实现 | 与 `bin/dotfiles` 100% 功能重叠 | **删除**，仅保留 shim |
| `scripts/cache.sh` 193行独立脚本 | 功能极简（status/clear 两个命令） | **内联**到 `bin/dotfiles` |
| `sync.sh` 内嵌 ~150行 yq stub | 测试代码污染生产逻辑 | **提取**到 `tests/fixtures/` |
| 3个测试文件各自定义断言函数 | `_assert_eq/_assert_contains` 三份拷贝 | **提取**到 `tests/lib/assert.sh` |
| `doctor.sh` 用索引遍历 tools.yaml | 与 `sync.sh` 名称遍历方式不一致 | **统一**为名称遍历 |
| `dot_aliases.sh` 覆盖系统命令 | `alias find='fd'` 破坏构建工具 | **重命名**为非冲突别名 |
| `tools.yaml` 硬编码版本号 URL | `/releases/latest/download/procs-v0.14.9-...` 逻辑矛盾 | **修复** URL |
| `install.sh` 硬编码仓库地址 | `b1tzer/dotfiles` 写死，Fork 用户无法使用 | **还原**为占位符 |

**精简目标量化：**
- 删除 `bootstrap.sh`（368行 → 50行 shim）
- 删除 `scripts/cache.sh`（193行 → 0行，逻辑内联到 `bin/dotfiles`）
- `sync.sh` 减少约 150行（yq stub 提取）
- 测试文件减少约 60行（断言函数去重）

---

## 需求

### 需求 1：删除 bootstrap.sh 独立实现，替换为转发 shim

**用户故事：** 作为维护者，我希望只维护一套入口逻辑，以便消除 `bootstrap.sh` 与 `bin/dotfiles` 之间的参数不兼容和代码重复。

#### 验收标准

1. WHEN `bootstrap.sh` 被重写后 THEN 文件行数 SHALL 不超过 50 行（当前 368 行）
2. WHEN 用户执行 `bash bootstrap.sh` THEN 系统 SHALL 打印 DEPRECATED 警告并转发到 `bin/dotfiles sync`
3. WHEN 用户执行 `bash bootstrap.sh --tools-only` THEN 系统 SHALL 映射为 `bin/dotfiles sync --tools`
4. WHEN 用户执行 `bash bootstrap.sh --dotfiles-only` THEN 系统 SHALL 映射为 `bin/dotfiles sync --dotfiles`
5. WHEN 用户执行 `bash bootstrap.sh --pull` THEN 系统 SHALL 映射为 `bin/dotfiles update`
6. IF `bootstrap.sh` 中存在任何业务逻辑函数（`_step_*`、`_record_step` 等）THEN 这些函数 SHALL 被删除

---

### 需求 2：将 scripts/cache.sh 内联到 bin/dotfiles，删除独立文件

**用户故事：** 作为维护者，我希望 `cache` 子命令的逻辑直接内聚在 `bin/dotfiles` 中，以便消除一个仅有两个命令的独立脚本文件。

#### 验收标准

1. WHEN `_cmd_cache` 在 `bin/dotfiles` 中被调用 THEN 系统 SHALL 直接执行 status/clear 逻辑，而不是 `bash scripts/cache.sh`
2. WHEN `scripts/cache.sh` 被删除后 THEN `bin/dotfiles cache status` 和 `bin/dotfiles cache clear` SHALL 仍然正常工作
3. IF `scripts/cache.sh` 文件存在 THEN 这是一个错误状态，该文件 SHALL 被删除
4. WHEN `_cmd_cache` 内联后 THEN `bin/dotfiles` 的 `_cmd_cache` 函数 SHALL 包含原 `cache.sh` 中的 `_cmd_status` 和 `_cmd_clear` 逻辑

---

### 需求 3：将 yq stub 从 sync.sh 提取到 tests/fixtures/

**用户故事：** 作为维护者，我希望 `sync.sh` 只包含生产逻辑，以便测试代码不污染生产代码，且 `sync.sh` 的职责单一。

#### 验收标准

1. WHEN `sync.sh` 在非测试模式下运行 THEN 文件中 SHALL 不包含任何 awk/YAML stub 实现代码
2. WHEN `tests/fixtures/yq_stub.sh` 被创建 THEN 文件 SHALL 包含原 `_ensure_yq` 中的完整 stub 逻辑
3. WHEN `DOTFILES_TEST_MODE=1` 时 `_ensure_yq` 被调用 THEN 系统 SHALL 通过 `source "$REPO_ROOT/tests/fixtures/yq_stub.sh"` 加载 stub
4. WHEN yq stub 被提取后 THEN `sync.sh` 行数 SHALL 减少约 150 行（当前 535 行 → 约 385 行）
5. WHEN yq stub 被提取后 THEN 所有现有单元测试 SHALL 仍然通过（`dotfiles test` 退出码为 0）

---

### 需求 4：提取测试断言函数到 tests/lib/assert.sh

**用户故事：** 作为维护者，我希望断言函数只定义一次，以便修改断言逻辑时不需要同步修改三个文件。

#### 验收标准

1. WHEN `tests/lib/assert.sh` 被创建 THEN 文件 SHALL 包含 `_assert_eq`、`_assert_contains`、`_assert_not_contains`、`_assert_exit_code` 函数
2. WHEN 三个测试文件（`test_logging.sh`、`test_detect_os.sh`、`test_sync_logic.sh`）被修改后 THEN 各文件中的断言函数定义 SHALL 被删除，替换为 `source "$TESTS_DIR/../lib/assert.sh"`
3. IF 断言函数在任意测试文件中仍有重复定义 THEN 这是一个错误状态
4. WHEN 共享断言库引入后 THEN 所有现有测试 SHALL 仍然通过

---

### 需求 5：统一 doctor.sh 与 sync.sh 的 tools.yaml 遍历方式

**用户故事：** 作为维护者，我希望两个脚本使用相同的遍历模式，以便代码风格一致，且 `doctor.sh` 的 yq 调用次数同步减少。

#### 验收标准

1. WHEN `doctor.sh` 的 `_check_tools` 被重写后 THEN 遍历方式 SHALL 使用名称遍历（`yq e '.tools[].name'`），而非索引遍历（`while i < tool_count`）
2. WHEN `_check_tools` 处理单个工具时 THEN yq 调用次数 SHALL 不超过 3 次（当前约 5 次/工具）
3. WHEN 遍历方式统一后 THEN `doctor.sh` 的行为 SHALL 与当前版本完全一致（相同输入产生相同输出）

---

### 需求 6：修复 dot_aliases.sh 中的系统命令覆盖

**用户故事：** 作为使用该 dotfiles 的开发者，我希望现代工具别名不覆盖系统命令，以便 cmake/make 等构建工具不因 alias 而失败。

#### 验收标准

1. WHEN `dot_aliases.sh` 被 source 后 THEN `find` 命令 SHALL 仍然指向系统原生 `find`
2. WHEN `dot_aliases.sh` 被 source 后 THEN `grep` 命令 SHALL 仍然指向系统原生 `grep`
3. WHEN `fd` 已安装 THEN 系统 SHALL 提供 `ff` 别名作为快捷方式（而非覆盖 `find`）
4. WHEN `rg` 已安装 THEN 系统 SHALL 提供 `rgrep` 别名作为快捷方式（而非覆盖 `grep`）
5. IF `dot_aliases.sh` 中存在 `alias find=` 或 `alias grep=` THEN 这是一个错误状态，SHALL 被修复

---

### 需求 7：修复 tools.yaml 中硬编码版本号的矛盾 URL

**用户故事：** 作为维护者，我希望工具安装 URL 在新版本发布后仍然有效，以便用户不会因 404 而安装失败。

#### 验收标准

1. WHEN `tools.yaml` 中的工具使用 `script` 安装方式 THEN URL SHALL 不同时包含 `/releases/latest/download/` 前缀和具体版本号
2. WHEN `procs` 的安装 URL 被修复后 THEN URL SHALL 不包含 `v0.14.9` 等具体版本号
3. WHEN `bandwhich` 的安装 URL 被修复后 THEN URL SHALL 不包含 `v0.23.1` 等具体版本号
4. WHEN `dog` 的安装 URL 被修复后 THEN URL SHALL 不包含 `v0.1.0` 等具体版本号
5. IF 工具确实需要固定版本 THEN `tools.yaml` SHALL 使用独立的 `version` 字段，安装脚本动态构建 URL

---

### 需求 8：修复 install.sh 中的硬编码仓库地址

**用户故事：** 作为 Fork 了该仓库的开发者，我希望 `install.sh` 中的仓库地址能自动指向我自己的仓库，以便无需手动修改脚本。

#### 验收标准

1. WHEN `install.sh` 在仓库中被检出 THEN 文件中 SHALL 包含 `__DOTFILES_REPO__` 占位符，而非硬编码的 `b1tzer/dotfiles` URL
2. WHEN `release.yml` 执行占位符替换后 THEN CI SHALL 验证替换成功（`grep` 检查占位符已消失）
3. IF 占位符替换失败 THEN CI SHALL 以非零退出码失败，而非静默通过

---

## 精简效果预估

| 文件 | 当前行数 | 目标行数 | 变化 |
|------|---------|---------|------|
| `bootstrap.sh` | 368 | ~50 | **-318行** |
| `scripts/cache.sh` | 193 | 0（删除） | **-193行** |
| `scripts/sync.sh` | 535 | ~385 | **-150行** |
| `tests/unit/test_logging.sh` | 138 | ~110 | -28行 |
| `tests/unit/test_detect_os.sh` | ~100 | ~75 | -25行 |
| `tests/unit/test_sync_logic.sh` | ~180 | ~155 | -25行 |
| `tests/lib/assert.sh` | 0 | ~40 | +40行（新增） |
| `tests/fixtures/yq_stub.sh` | 0 | ~150 | +150行（提取） |
| **净减少** | | | **约 -549行，-1个文件** |

## 优先级

| 优先级 | 需求 | 理由 |
|--------|------|------|
| 🔴 P0 | 需求 6：修复 alias 覆盖 | 影响所有用户日常使用，破坏构建工具 |
| 🔴 P0 | 需求 7：修复硬编码版本 URL | 工具安装静默 404，直接影响核心功能 |
| 🟠 P1 | 需求 1：bootstrap.sh 精简为 shim | 消除 318 行冗余代码，最大单次收益 |
| 🟠 P1 | 需求 2：cache.sh 内联删除 | 消除不必要的独立文件，减少项目文件数 |
| 🟡 P2 | 需求 3：提取 yq stub | sync.sh 职责单一，生产代码更清晰 |
| 🟡 P2 | 需求 4：提取断言共享库 | DRY 原则，测试代码可维护性 |
| 🟢 P3 | 需求 5：统一遍历方式 | 代码一致性，doctor.sh 性能小幅提升 |
| 🟢 P3 | 需求 8：修复占位符 | Fork 用户体验，影响面较小 |
