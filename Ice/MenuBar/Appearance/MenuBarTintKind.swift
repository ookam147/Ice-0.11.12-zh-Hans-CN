//
//  MenuBarTintKind.swift
//  Ice
//

import SwiftUI

/// A type that specifies how the menu bar is tinted.
enum MenuBarTintKind: Int, CaseIterable, Codable, Identifiable {
    /// The menu bar is not tinted.
    case none = 0
    /// The menu bar is tinted with a solid color.
    case solid = 1
    /// The menu bar is tinted with a gradient.
    case gradient = 2

    var id: Int { rawValue }

    /// Localized string key representation.
    var localized: LocalizedStringKey {
        switch self {
        case .none: "无"
        case .solid: "纯色"
        case .gradient: "渐变"
        }
    }
}
