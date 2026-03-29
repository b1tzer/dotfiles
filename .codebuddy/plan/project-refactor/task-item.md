# 实施计划：dotfiles 项目精简重构

- [ ] 1. 修复 dot_aliases.sh 中的系统命令覆盖别名
   - 将 `alias find='fd'` 改为 `alias ff='fd'`
   - 将 `alias grep='rg'` 改为 `alias rgrep='rg'`
   - 确保 `find`、`grep` 仍指向系统原生命令
   - _需求：6.1、6.2、6.3、6.4、6.5_

- [ ] 2. 修复 tools.yaml 中硬编码版本号的矛盾 URL
   - 修复 `procs` 安装 URL，移除 `v0.14.9` 版本号
   - 修复 `bandwhich` 安装 URL，移除 `v0.23.1` 版本号
   - 修复 `dog` 安装 URL，移除 `v0.1.0` 版本号
   - _需求：7.1、7.2、7.3、7.4_

- [ ] 3. 将 bootstrap.sh 重写为转发 shim
   - 删除所有 `_step_*`、`_record_step` 等业务逻辑函数
   - 实现参数映射：`--tools-only` → `sync --tools`，`--dotfiles-only` → `sync --dotfiles`，`--pull` → `update`
   - 保留 DEPRECATED 警告提示，文件行数控制在 50 行以内
   - _需求：1.1、1.2、1.3、1.4、1.5、1.6_

- [ ] 4. 将 scripts/cache.sh 逻辑内联到 bin/dotfiles 并删除文件
   - 读取 `cache.sh` 中 `_cmd_status` 和 `_cmd_clear` 的完整逻辑
   - 将逻辑直接写入 `bin/dotfiles` 的 `_cmd_cache` 函数中，移除对 `bash scripts/cache.sh` 的调用
   - 删除 `scripts/cache.sh` 文件
   - 验证 `bin/dotfiles cache status` 和 `bin/dotfiles cache clear` 仍正常工作
   - _需求：2.1、2.2、2.3、2.4_

- [ ] 5. 创建 tests/lib/assert.sh 并消除测试断言函数重复
   - 新建 `tests/lib/assert.sh`，包含 `_assert_eq`、`_assert_contains`、`_assert_not_contains`、`_assert_exit_code`
   - 删除 `test_logging.sh`、`test_detect_os.sh`、`test_sync_logic.sh` 中的重复断言函数定义
   - 在三个测试文件中添加 `source "$TESTS_DIR/../lib/assert.sh"`
   - _需求：4.1、4.2、4.3、4.4_

- [ ] 6. 将 yq stub 从 sync.sh 提取到 tests/fixtures/yq_stub.sh
   - 新建 `tests/fixtures/yq_stub.sh`，包含原 `_ensure_yq` 中的完整 awk stub 实现
   - 修改 `sync.sh` 的 `_ensure_yq` 函数：测试模式下 `source` 外部 stub 文件，非测试模式下不含任何 stub 代码
   - 验证 `sync.sh` 行数减少约 150 行，且所有测试仍通过
   - _需求：3.1、3.2、3.3、3.4、3.5_

- [ ] 7. 统一 doctor.sh 与 sync.sh 的 tools.yaml 遍历方式
   - 将 `doctor.sh` 的 `_check_tools` 改为名称遍历（`yq e '.tools[].name'`），移除索引遍历逻辑
   - 确保每个工具的 yq 调用次数不超过 3 次
   - 验证 `doctor.sh` 输出行为与修改前一致
   - _需求：5.1、5.2、5.3_

- [ ] 8. 修复 install.sh 中的硬编码仓库地址及 CI 验证
   - 将 `install.sh` 中的 `https://github.com/b1tzer/dotfiles` 替换回 `__DOTFILES_REPO__` 占位符
   - 在 `release.yml` 的占位符替换步骤后添加 `grep` 验证，替换失败时以非零退出码终止
   - _需求：8.1、8.2、8.3_
