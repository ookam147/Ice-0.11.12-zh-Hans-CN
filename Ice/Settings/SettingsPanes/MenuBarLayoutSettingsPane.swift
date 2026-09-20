//
//  MenuBarLayoutSettingsPane.swift
//  Ice
//

import SwiftUI

struct MenuBarLayoutSettingsPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("排列菜单栏项目", systemImage: "menubar.rectangle")
                .font(.title2)
            Text("按住 Command（⌘）并拖动菜单栏中的图标，即可调整位置。")
            Text("先展开隐藏分区，再将图标拖到分隔符的另一侧，即可调整所属分区。部分系统图标的位置由 macOS 管理。")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
