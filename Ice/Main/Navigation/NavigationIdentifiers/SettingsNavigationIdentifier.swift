//
//  SettingsNavigationIdentifier.swift
//  Ice
//

/// An identifier used for navigation in the settings interface.
enum SettingsNavigationIdentifier: String, NavigationIdentifier {
    case general = "通用"
    case menuBarLayout = "菜单栏布局"
    case hotkeys = "快捷键"
    case advanced = "高级"
    case about = "关于"
}
