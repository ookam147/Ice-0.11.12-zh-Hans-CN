//
//  MenuBarSearchPolicy.swift
//  Ice
//

import Foundation

/// A runtime identity, deliberately separate from the persisted MenuBarItemInfo.
struct MenuBarSearchIdentity: Hashable {
    let windowID: UInt32
    let ownerPID: Int32
}

/// Search rules that do not require screen recording or accessibility queries.
enum MenuBarSearchPolicy {
    static func displayName(namespace: String?, title: String?, applicationName: String) -> String? {
        switch namespace {
        case "com.apple.controlcenter":
            return controlCenterNames[title ?? ""]
        case "com.apple.systemuiserver":
            return systemUIServerNames[title ?? ""]
        case "com.apple.Passwords.MenuBarExtra":
            return "密码"
        case "com.apple.TextInputMenuAgent":
            return "输入法"
        default:
            return applicationName
        }
    }

    static func matches(_ name: String, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || name.localizedStandardContains(query)
    }

    static func selection(
        keeping current: MenuBarSearchIdentity?,
        available: [MenuBarSearchIdentity]
    ) -> MenuBarSearchIdentity? {
        if let current, available.contains(current) {
            return current
        }
        return available.first
    }

    private static let controlCenterNames = [
        "AccessibilityShortcuts": "辅助功能快捷键",
        "AudioVideoModule": "音频与视频",
        "Battery": "电池",
        "BentoBox": "控制中心",
        "Bluetooth": "蓝牙",
        "Clock": "时钟",
        "Display": "显示器",
        "Displays": "显示器",
        "FaceTime": "FaceTime",
        "FocusModes": "专注模式",
        "KeyboardBrightness": "键盘亮度",
        "MusicRecognition": "音乐识别",
        "NowPlaying": "正在播放",
        "ScreenMirroring": "屏幕镜像",
        "Sound": "声音",
        "StageManager": "台前调度",
        "UserSwitcher": "快速用户切换",
        "Volume": "声音",
        "WiFi": "Wi-Fi",
    ]

    private static let systemUIServerNames = [
        "Siri": "Siri",
        "TimeMachine.TMMenuExtraHost": "时间机器",
        "TimeMachineMenuExtra.TMMenuExtraHost": "时间机器",
    ]
}
