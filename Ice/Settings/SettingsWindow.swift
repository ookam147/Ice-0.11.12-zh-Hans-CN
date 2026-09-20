//
//  SettingsWindow.swift
//  Ice
//

import SwiftUI

struct SettingsWindow: Scene {
    @ObservedObject var appState: AppState

    var body: some Scene {
        Window(Constants.settingsWindowTitle, id: Constants.settingsWindowID) {
            SettingsWindowContent(navigationState: appState.navigationState)
                .readWindow { window in
                    guard let window else {
                        return
                    }
                    appState.assignSettingsWindow(window)
                }
                .frame(minWidth: 825, minHeight: 500)
        }
        .commandsRemoved()
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 625)
        .environmentObject(appState)
        .environmentObject(appState.navigationState)
    }
}

/// SwiftUI may retain the scene's window after close. Drop the expensive settings
/// subtree while hidden, keeping only this lightweight visibility observer.
private struct SettingsWindowContent: View {
    @ObservedObject var navigationState: AppNavigationState

    var body: some View {
        Group {
            if navigationState.isSettingsPresented {
                SettingsView()
            } else {
                Color.clear
            }
        }
    }
}
