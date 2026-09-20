//
//  OnKeyDown.swift
//  Ice
//

import SwiftUI

extension View {
    /// Returns a view that performs the given action when
    /// the specified key is pressed.
    func onKeyDown(key: KeyCode, action: @escaping () -> Void) -> some View {
        localEventMonitor(mask: .keyDown) { event in
            // Let the native input method confirm or navigate its marked text.
            if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.hasMarkedText() {
                return event
            }
            if event.keyCode == key.rawValue {
                action()
                return nil
            }
            return event
        }
    }
}
