# 实施计划：扩充工具清单与 alias 配置

- [ ] 1. 向 `tools.yaml` 补充 Git 增强工具
   - 新增 `lazygit`、`delta`、`git-lfs` 三个工具条目，配置 Ubuntu/macOS/Windows 三平台安装方式
   - 参考现有工具条目格式（brew/apt/winget/cargo）
   - _需求：1.1、1.2、1.3_

- [ ] 2. 向 `tools.yaml` 补充系统监控工具
   - 新增 `btop`、`dust`、`procs` 三个工具条目，配置三平台安装方式
   - _需求：2.1、2.2、2.3_

- [ ] 3. 向 `tools.yaml` 补充网络调试工具
   - 新增 `xh`、`dog`、`bandwhich` 三个工具条目，配置对应平台安装方式（dog 仅 Ubuntu/macOS）
   - _需求：3.1、3.2、3.3_

- [ ] 4. 向 `tools.yaml` 补充开发效率工具
   - 新增 `zoxide`、`atuin`、`tealdeer`、`navi`、`tokei`、`hyperfine` 六个工具条目，配置三平台安装方式
   - _需求：4.1、4.2、4.3、4.4、4.5、4.6_

- [ ] 5. 创建 `dot_aliases.sh` 文件
   - 5.1 创建文件骨架，包含文件头注释和安全 source 检测逻辑
   - 5.2 添加现代命令替代 alias（ls/ll/la/lt、cat、grep、find、du、top、ps），使用条件判断确保工具已安装才生效
   - 5.3 添加 zoxide 初始化（`z` 和 `zi`）
   - _需求：5.1、6.1～6.8_

- [ ] 6. 向 `dot_aliases.sh` 添加 Git 快捷 alias
   - 添加 `g`、`gs`、`ga`、`gc`、`gp`、`gl`、`gd`、`glog`、`lg` 等 alias
   - `gd` 使用条件判断：若 delta 已安装则通过 `git -c core.pager=delta diff`
   - _需求：7.1_

- [ ] 7. 向 `dot_aliases.sh` 添加目录导航与系统 alias
   - 添加 `..`/`...`/`....`/`~`/`dotfiles` 目录导航 alias
   - 添加 `reload`、`path`、`myip`、`ports`、`mkcd` 系统操作 alias/函数
   - _需求：8.1、8.2_

- [ ] 8. 修改 `dot_zshrc.tmpl`，自动 source alias 文件
   - 在文件末尾添加 `[[ -f ~/.aliases.sh ]] && source ~/.aliases.sh`
   - 确保 shell 启动时 `~/.aliases.sh` 不存在也不报错
   - _需求：5.2、5.3_

- [ ] 9. 更新 `README.md`
   - 在工具表格中新增 lazygit、delta、git-lfs、btop、dust、procs、xh、dog、bandwhich、zoxide、atuin、tealdeer、navi、tokei、hyperfine 等工具行
   - 新增"Alias 配置"章节，列出所有 alias 分类（现代命令替代、Git 快捷、目录导航、系统操作）及说明
   - _需求：9.1、9.2_
