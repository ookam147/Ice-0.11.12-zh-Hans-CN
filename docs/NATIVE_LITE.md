# Ice 原生精简版

## 实现结果

本版本使用 AppKit / SwiftUI 原生窗口、搜索输入、单选列表、按钮、滑块和 SF Symbols。登录启动使用 macOS `SMAppService.mainApp`。

- 保留隐藏/展开、始终隐藏分区、自动收起、悬停/滚动/点击、快捷键、间距和应用菜单管理。
- 搜索按运行时窗口 ID + 所属 PID 区分项目；同一应用的多个图标独立选中。持久化 `MenuBarItemInfo` 格式保持不变。
- 已识别的系统模块显示中文；无法识别名称的 Control Center / SystemUIServer 项目隐藏。普通应用没有窗口标题时仍可按应用名搜索。
- 使用 `localizedStandardContains` 匹配，支持大小写、变音符和中文子串；不支持拼音或模糊纠错。
- 鼠标悬停时整行显示背景反馈，单击直接打开；键盘方向键只改变选择，回车或底部“打开所选项目”按钮执行打开，Escape 关闭。中文输入法仍在组合文字时不抢占这些按键。
- 项目消失后停止操作；临时显示和恢复原位也按窗口身份匹配，避免误操作同名图标。
- 永久移除截图预览、截图缓存和刷新任务、Ice Bar、菜单栏美化、壁纸/颜色采样和设置内图像拖拽排列。排列改用 Command + 拖动。
- 不请求屏幕录制权限；辅助功能权限仍然需要。
- 搜索面板延迟创建，关闭时释放内容和会话图标缓存。设置窗口隐藏时卸载设置视图子树。
- 移除 Ifrit、CompactSlider、LaunchAtLogin 三个依赖。保留 AXSwift（辅助功能封装）和 Sparkle（更新），保留原有必要的菜单栏底层调用。

## 兼容性

旧版分区位置、隐藏/自动收起设置、核心快捷键和图标配置继续使用。Ice Bar 和外观旧配置不再读取；旧 `EnableIceBar` 快捷键不再注册。没有批量删除用户的偏好设置。

设置导航原本只保存在内存，不持久化；启动仍从“通用”开始，外观页面已从导航删除。布局页面保留原生排列操作说明。

开发过程没有覆盖或重启 `/Applications/Ice.app`，没有修改用户的录屏、辅助功能或登录项授权。

## 已完成验证

- `Scripts/test-search.sh`：23 项回归检查通过，包括缺失标题、未知系统模块、普通应用保留、中文/大小写/变音符匹配、同进程不同窗口、窗口 ID 被其他 PID 复用、刷新和移除后的选择。
- `python3 Scripts/typecheck.py`：全部 Release Swift 源码类型检查通过，目标为 macOS 14、arm64。依赖为锁定的 AXSwift 0.3.2 和 Sparkle 2.6.4；Sparkle 下载校验 SHA-256。没有使用项目类型的替代实现或桩。
- 原生滑块、登录项控件单独类型检查通过；所有 Swift 文件语法解析通过。
- Xcode 工程 plist 校验、依赖移除检查和 `git diff --check` 通过。

类型检查环境：macOS 15.7.9，Apple Swift 6.2.3，Command Line Tools。SwiftUI 设计预览仅参与 Debug 构建。

**已补充完成命令行打包**：使用 Command Line Tools 的 `swiftc -O -whole-module-optimization` 完成真实 Release 编译和链接，将 AXSwift 静态链接并嵌入 Sparkle.framework。通过 `iconutil` 生成应用图标，普通 PNG 资源替代 `actool` 产物，并保留模板图像的主题适配信息。应用和嵌套组件使用本机 ad-hoc 签名，`codesign --verify --deep --strict` 通过。

**未完成**：实际应用启动及界面回归、多显示器/桌面切换、登录项注册回归、搜索/设置反复打开后的实际释放验证，以及精简版内存和 CPU 对比。构建成功不能证明实测内存降低或没有泄漏。测试包未经过 Developer ID 签名和 Apple 公证。

此前“没有完整 Xcode 因此无法交付 .app”的判断过于绝对；不可用的是 `xcodebuild` 标准工作流，本项目可以使用命令行工具完成本地测试打包。

验证日志和只读采样数据保存在 `build/validation/`，该目录由 Git 忽略。

## 完整构建与验收

无需完整 Xcode 的本机测试构建：

```sh
python3 Scripts/build-native.py
```

当前产物（Apple Silicon / arm64，最低 macOS 14）：

- 应用：`build/NativeLite-CLT/Ice Native Lite.app`
- 压缩包：`build/NativeLite-CLT/Ice-Native-Lite.zip`
- 编译日志：`build/NativeLite-CLT/compile.log`

脚本从源码构建，不依赖已安装 Ice 的二进制或资源。资源检查已验证 7 个原生图像可加载、模板元数据/应用图标/致谢文件存在，Sparkle 可由系统动态加载；ZIP 解压后签名校验通过。构建脚本仅输出到 `build/`，不会安装或启动应用。

测试前先退出原版，避免两个相同 bundle identifier 的实例同时管理菜单栏。临时签名与原版不同，首次打开可能需要重新授予辅助功能权限。自动更新仍沿用上游实现和源；测试精简版时不要安装上游更新，否则会回到上游版本。

在具有完整 Xcode 16 或更高版本、可用 macOS SDK 的环境中，从项目根目录执行：

```sh
Scripts/test-search.sh
xcodebuild -project Ice.xcodeproj -scheme Ice -configuration Release \
  -derivedDataPath build/NativeLite CODE_SIGNING_ALLOWED=NO build
```

构建产物位于 `build/NativeLite/Build/Products/Release/Ice.app`；该命令不签名，不覆盖已安装应用。分发前需要实际签名和启动验证，不能把类型检查日志当作构建产物。

界面回归：

1. 不授予录屏权限，确认无录屏请求，搜索中没有未知系统宿主项；可识别系统项目中文显示，第三方项目仍然可搜索。
2. 同一应用创建两个菜单栏图标，确认仅一行高亮；测试单击、双击、上下方向键、回车、Escape，以及中文输入法选词。
3. 搜索期间退出、重启目标应用，确认刷新后选择合法且不会点击旧窗口。隐藏项目打开后应恢复原分区、原位置，不影响同名项目。
4. 回归普通/始终隐藏分区、自动收起三种策略、悬停、滚动、快捷键、Command 拖动、全屏、桌面切换和多显示器。
5. 搜索连续打开/关闭 20 次，设置反复打开/关闭，确认没有残留键盘监听或持续内存增长；设置再次打开正常。
6. 登录启动开启、关闭、需要系统批准和注册失败时，确认界面反映系统状态；从旧配置启动时核心设置仍有效。

## 内存测量口径

原版和精简版必须使用相同 Release 配置、签名方式、权限、菜单栏项目、显示器和设置，分别运行，避免同时启动同一 bundle identifier 的两个实例。至少比较三次冷启动，并分别记录：

| 场景 | 原版 | 精简版 |
| --- | --- | --- |
| 启动后 30 秒 | 待测 | 待测 |
| 空闲 5 分钟 | 待测 | 待测 |
| 搜索开关 20 次后 | 待测 | 待测 |
| 设置开关后 | 待测 | 待测 |

提供只读采样工具，例如：

```sh
python3 Scripts/sample-memory.py <PID> --seconds 300 --interval 5 \
  --output build/validation/lite-idle.csv
```

CSV 记录时间、采样经过时间、进程运行时间、RSS（KiB）和 `ps` 报告的 CPU 百分比。RSS 不等同于活动监视器的“内存”；CPU 字段是 `ps` 的近期利用率，不是独立计算的每采样间隔利用率。输出文件若已存在则拒绝覆盖。

本次对当前已安装原版（PID 1157，已运行约 41.5 小时）做了 10 秒只读采样：6 个样本，RSS 中位数 64.09 MiB、峰值 64.16 MiB，记录在 `build/validation/original-warm-reference.csv`。该长期运行采样仅作为参考，不是冷启动基线；没有精简版数据时不计算节省比例。代码删除数量、依赖数量和缓存移除也不能直接换算成节省的 MB 数。
