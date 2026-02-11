# Ice 国际化（i18n）- 中英文切换

## 任务概览

为 Ice 菜单栏管理器添加中文本地化支持，并实现中英文切换功能。

## 任务清单

- [/] 研究项目结构和所有 UI 文件
- [ ] 撰写实现计划
- [ ] 创建 `Localizable.xcstrings` 字符串目录（含 en 和 zh-Hans）
- [ ] 修改 SwiftUI 视图中的硬编码字符串为本地化键
- [ ] 修改 NSMenuItem 的 title 为 NSLocalizedString 调用
- [ ] 修改 Permission.swift 中的 title/details 为本地化字符串
- [ ] 修改 MenuBarSection.Name displayString 为本地化字符串
- [ ] 修改 SystemAppearance titleKey
- [ ] 更新 Xcode 项目配置（knownRegions 添加 zh-Hans）
- [ ] 添加语言切换功能（设置面板中的语言选择器）
- [ ] 验证变更
