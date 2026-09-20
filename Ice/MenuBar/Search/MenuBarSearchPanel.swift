//
//  MenuBarSearchPanel.swift
//  Ice
//

import Combine
import SwiftUI

/// A panel that contains the menu bar search interface.
final class MenuBarSearchPanel: NSPanel {
    /// The default screen to show the panel on.
    static var defaultScreen: NSScreen? {
        NSScreen.screenWithMouse ?? NSScreen.main
    }

    /// The shared app state.
    private weak var appState: AppState?

    private var refreshTask: Task<Void, Never>?

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// Monitor for mouse down events.
    private lazy var mouseDownMonitor = UniversalEventMonitor(
        mask: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    ) { [weak self, weak appState] event in
        guard
            let self,
            let appState,
            event.window !== self
        else {
            return event
        }
        if !appState.itemManager.isMovingItem {
            close()
        }
        return event
    }

    /// Monitor for key down events.
    private lazy var keyDownMonitor = UniversalEventMonitor(
        mask: [.keyDown]
    ) { [weak self] event in
        if let editor = self?.firstResponder as? NSTextView, editor.hasMarkedText() {
            return event
        }
        if KeyCode(rawValue: Int(event.keyCode)) == .escape {
            self?.close()
            return nil
        }
        return event
    }

    /// Overridden to always be `true`.
    override var canBecomeKey: Bool { true }

    /// Creates a menu bar search panel with the given app state.
    init(appState: AppState?) {
        super.init(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )
        self.appState = appState
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = false
        self.animationBehavior = .none
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle, .moveToActiveSpace]
        configureCancellables()
    }

    /// Configures the internal observers for the panel.
    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        NSApp.publisher(for: \.effectiveAppearance)
            .sink { [weak self] effectiveAppearance in
                self?.appearance = effectiveAppearance
            }
            .store(in: &c)

        // Close the panel when the active space changes, or when the screen parameters change.
        Publishers.Merge(
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification),
            NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
        )
        .sink { [weak self] _ in
            self?.close()
        }
        .store(in: &c)

        cancellables = c
    }

    /// Shows the search panel on the given screen.
    func show(on screen: NSScreen) async {
        guard let appState else {
            return
        }

        let hostingView = NSHostingView(rootView: MenuBarSearchContentView(
            itemManager: appState.itemManager,
            closePanel: { [weak self] in self?.close() }
        ))
        hostingView.setFrameSize(hostingView.intrinsicContentSize)
        setFrame(hostingView.frame, display: true)

        contentView = hostingView

        // Calculate the top left position.
        let topLeft = CGPoint(
            x: screen.frame.midX - frame.width / 2,
            y: screen.frame.midY + (frame.height / 2) + (screen.frame.height / 8)
        )

        cascadeTopLeft(from: topLeft)
        makeKeyAndOrderFront(nil)

        mouseDownMonitor.start()
        keyDownMonitor.start()
        // Refresh without delaying presentation. Closing the panel cancels this work.
        refreshTask = Task { [weak appState] in
            guard let appState else { return }
            await appState.itemManager.cacheItemsIfNeeded()
        }
    }

    /// Toggles the panel's visibility.
    func toggle() async {
        if isVisible {
            close()
        } else if let screen = MenuBarSearchPanel.defaultScreen {
            await show(on: screen)
        }
    }

    /// Dismisses the search panel.
    override func close() {
        refreshTask?.cancel()
        refreshTask = nil
        super.close()
        contentView = nil
        mouseDownMonitor.stop()
        keyDownMonitor.stop()
    }
}

/// The entire search session (including its icon cache) lives in the hosting view.
private struct MenuBarSearchContentView: View {
    private struct Row: Identifiable {
        let item: MenuBarItem
        let title: String
        let section: MenuBarSection.Name
        var id: MenuBarSearchIdentity { item.searchIdentity }
    }

    @ObservedObject var itemManager: MenuBarItemManager
    @State private var searchText = ""
    @State private var rows = [Row]()
    @State private var selection: MenuBarSearchIdentity?
    @State private var hoveredRow: MenuBarSearchIdentity?
    @State private var icons = [pid_t: NSImage]()
    @FocusState private var searchFieldIsFocused: Bool

    let closePanel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextField("搜索菜单栏项目…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .padding()
                .focused($searchFieldIsFocused)

            Divider()

            ScrollViewReader { proxy in
                List(selection: $selection) {
                    ForEach(MenuBarSection.Name.allCases, id: \.self) { section in
                        let sectionRows = rows.filter { $0.section == section }
                        if !sectionRows.isEmpty {
                            Section(section.displayString) {
                                ForEach(sectionRows) { row in
                                    HStack(spacing: 10) {
                                        if let icon = icons[row.item.ownerPID] {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                        } else {
                                            Image(systemName: "app")
                                                .frame(width: 24, height: 24)
                                        }
                                        Text(row.title)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .background {
                                        if hoveredRow == row.id {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .fill(
                                                    selection == row.id
                                                        ? Color.white.opacity(0.14)
                                                        : Color.accentColor.opacity(0.13)
                                                )
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onHover { isHovering in
                                        if isHovering {
                                            hoveredRow = row.id
                                        } else if hoveredRow == row.id {
                                            hoveredRow = nil
                                        }
                                    }
                                    .onTapGesture {
                                        selection = row.id
                                        performSelection(row.id)
                                    }
                                    .padding(.vertical, 4)
                                    .tag(row.id)
                                    .id(row.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selection) {
                    if let selection {
                        proxy.scrollTo(selection)
                    }
                }
                .overlay {
                    if rows.isEmpty {
                        ContentUnavailableView(
                            "没有匹配的菜单栏项目",
                            systemImage: "magnifyingglass",
                            description: Text("无法识别名称的系统项目不会显示在搜索中。")
                        )
                    }
                }
            }

            Divider()

            HStack {
                Button {
                    closePanel()
                    itemManager.appState?.appDelegate?.openSettingsWindow()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
                Spacer()
                Button("打开所选项目") {
                    guard let selection else { return }
                    performSelection(selection)
                }
                    .disabled(selection == nil)
            }
            .padding(10)
        }
        .frame(width: 600, height: 400)
        .onAppear {
            updateRows()
            searchFieldIsFocused = true
        }
        .onChange(of: searchText) { updateRows() }
        .onChange(of: itemManager.itemCache) { updateRows() }
        .onReceive(itemManager.appState?.settingsManager.advancedSettingsManager.objectWillChange.eraseToAnyPublisher()
            ?? Empty<Void, Never>().eraseToAnyPublisher()) { _ in
            // Settings publishers send before the property changes.
            DispatchQueue.main.async { updateRows() }
        }
        .onKeyDown(key: .downArrow) { moveSelection(by: 1) }
        .onKeyDown(key: .upArrow) { moveSelection(by: -1) }
        .onKeyDown(key: .return) {
            guard let selection else { return }
            performSelection(selection)
        }
    }

    private func updateRows() {
        var seen = Set<MenuBarSearchIdentity>()
        var newRows = [Row]()
        for section in MenuBarSection.Name.allCases {
            guard itemManager.appState?.menuBarManager.section(withName: section)?.isEnabled == true else {
                continue
            }
            for item in itemManager.itemCache.managedItems(for: section).reversed() {
                guard
                    let title = item.searchDisplayName,
                    MenuBarSearchPolicy.matches(title, query: searchText),
                    seen.insert(item.searchIdentity).inserted
                else {
                    continue
                }
                newRows.append(Row(item: item, title: title, section: section))
            }
        }
        var newIcons = [pid_t: NSImage]()
        for row in newRows where newIcons[row.item.ownerPID] == nil {
            newIcons[row.item.ownerPID] = icons[row.item.ownerPID] ?? row.item.owningApplication?.icon
        }
        icons = newIcons
        rows = newRows
        if let hoveredRow, !newRows.contains(where: { $0.id == hoveredRow }) {
            self.hoveredRow = nil
        }
        selection = MenuBarSearchPolicy.selection(keeping: selection, available: newRows.map(\.id))
    }

    private func moveSelection(by offset: Int) {
        guard !rows.isEmpty else { return }
        let index = selection.flatMap { id in rows.firstIndex { $0.id == id } }
        let nextIndex = index.map { min(max($0 + offset, 0), rows.count - 1) } ?? 0
        selection = rows[nextIndex].id
    }

    private func performSelection(_ selection: MenuBarSearchIdentity) {
        guard rows.contains(where: { $0.id == selection }) else { return }
        closePanel()
        Task { @MainActor [weak itemManager] in
            // A row action runs at the end of the user's mouse-up event. Give AppKit
            // enough time to dismiss the nonactivating panel before synthesizing a
            // second click for another process's menu bar item.
            try? await Task.sleep(for: .milliseconds(120))
            guard
                let itemManager,
                let item = MenuBarItem(windowID: selection.windowID),
                item.searchIdentity == selection,
                item.searchDisplayName != nil,
                item.isCurrentlyInMenuBar
            else {
                return
            }
            itemManager.tempShowItem(item, clickWhenFinished: true, mouseButton: .left)
        }
    }
}
