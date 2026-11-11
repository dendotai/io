import AppKit
import Priority
import SwiftUI

/// The panel is an `NSMenu` with one item per header, device row, and separator, each hosting SwiftUI content (ADR 0001).
final class StatusItemController {
    /// The Sound icon's gaps to its neighbours, from Size, spacing, and animations in `docs/sound-menu.md`.
    private let statusItem = NSStatusBar.system.statusItem(withLength: 32)
    private let model: AppModel
    private let updater: AppUpdater
    private let panel: NSMenu
    private let volumeSlider: NSMenuItem
    private let volumeSeparator: NSMenuItem
    private let outputSection: SectionItems
    private let inputSection: SectionItems
    private let airPodsSettings: NSMenuItem
    private let soundSettings: NSMenuItem
    private let updateSeparator: NSMenuItem
    private let updateAvailableRow: NSMenuItem
    private var deviceItems: [Direction: [String: NSMenuItem]] = [:]
    /// Each AirPods row's group while folded open, built when it first folds open and again if its supported modes change.
    private var listeningGroups: [String: ListeningModeGroupItem] = [:]
    private var foldedOpenUIDs: Set<String> = []
    /// Each AirPods row's fold layer, built when the panel opens.
    private var foldAnimations: [String: FoldAnimation] = [:]
    private var foldAnimation: FoldAnimation?
    /// During a drag, one item holds the dragged row's whole section, so the row can slide over its neighbours (ADR 0001).
    private let dragTracker: RowDragTracker
    // `NSMenu.delegate` is weak, so this field is the delegate's only owner.
    // swiftlint:disable:next weak_delegate
    private let panelDelegate: PanelDelegate
    private let rightClickMenu = NSMenu()
    // `NSMenu.delegate` is weak, so this field is the delegate's only owner.
    // swiftlint:disable:next weak_delegate
    private let rightClickMenuDelegate: RightClickMenuDelegate
    private var iconView: MenuBarIconView?
    #if DEBUG
        private var debugMark: DebugMark?
    #endif

    init(model: AppModel, updater: AppUpdater) {
        self.model = model
        self.updater = updater
        volumeSlider = Self.item(VolumeSlider(model: model))
        volumeSeparator = Self.item(PanelSeparator(inset: Metrics.contentInset))
        func makeSection(_ direction: Direction) -> SectionItems {
            let rowDrag = RowDrag(direction: direction)
            return SectionItems(
                header: Self.item(SectionHeader(model: model, direction: direction)),
                separator: Self.item(PanelSeparator(inset: direction.separatorInset)),
                dragLayer: DragLayerItem(rowDrag: rowDrag, item: Self.item(DragLayer(model: model, drag: rowDrag)))
            )
        }
        outputSection = makeSection(.output)
        inputSection = makeSection(.input)
        panel = NSMenu()
        // A custom view item does not close the menu when clicked, and the Sound menu closes as System Settings opens.
        let closingMenu = { [panel] (action: @escaping () -> Void) in
            {
                panel.cancelTracking()
                action()
            }
        }
        airPodsSettings = Self.item(AirPodsSettingsRow(model: model, action: closingMenu(model.openAirPodsSettings)))
        soundSettings = Self.item(MenuRow(title: "Sound Settings…", action: closingMenu(model.openSoundSettings)))
        updateSeparator = Self.item(PanelSeparator(inset: Metrics.edgeInset))
        updateAvailableRow = Self.item(UpdateRow(updater: updater, action: closingMenu(updater.installUpdate)))
        dragTracker = RowDragTracker(model: model)
        panelDelegate = PanelDelegate(model: model)
        rightClickMenuDelegate = RightClickMenuDelegate(updater: updater)
        panel.delegate = panelDelegate
        panelDelegate.willOpen = { [weak self] in self?.prepareFoldAnimations() }
        statusItem.menu = panel
        dragTracker.didStart = { [weak self] in self?.updateItems() }
        dragTracker.didEnd = { [weak self] window in self?.updateItemsUnderRestingPointer(in: window) }
        rightClickMenu.delegate = rightClickMenuDelegate
        rightClickMenuDelegate.didClose = { [weak self] in self?.statusItem.menu = self?.panel }
        watchRightClicks()
        updateItems()
        iconView = statusItem.button.map(MenuBarIconView.init)
        statusItem.button?.setAccessibilityLabel("io")
        updateIcon()
        #if DEBUG
            debugMark = statusItem.button.map(DebugMark.init)
        #endif
    }

    #if DEBUG
        func openPanel() {
            statusItem.button?.performClick(nil)
        }
    #endif

    /// The panel stays set as `statusItem.menu`, so a hover from another menu bar menu opens it (ADR 0001); a right-click swaps the menu just before the native click opens it. AppKit reports a Control-click here as a `rightMouseDown` too. If a later macOS stops this event, a right-click opens the panel (https://developer.apple.com/forums/thread/832823).
    private func watchRightClicks() {
        NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            if let self, event.window === statusItem.button?.window {
                statusItem.menu = rightClickMenu
            }
            return event
        }
    }

    private static func item(_ view: some View) -> NSMenuItem {
        let hosting = NSHostingView(rootView: view)
        hosting.setFrameSize(hosting.fittingSize)
        let item = NSMenuItem()
        item.view = hosting
        return item
    }

    /// Moves existing items instead of making new ones, so a row keeps its view.
    private func updateItems() {
        let (rows, airPodsName, isUpdateAvailable) = withObservationTracking {
            (model.rows, model.airPodsName, updater.availableVersion != nil)
        } onChange: { [weak self] in
            // Common modes, so the menu follows a connect while it is open.
            RunLoop.main.perform(inModes: [.common]) { self?.updateItems() }
        }

        startFoldAnimations(rows[.output] ?? [])

        var list = PanelItemList()
        list.append(volumeSlider)
        list.append(volumeSeparator)
        for direction in Direction.allCases {
            appendSection(direction, rows: rows[direction] ?? [], to: &list)
        }
        if airPodsName != nil {
            list.append(airPodsSettings, name: "AirPods Settings")
        }
        list.append(soundSettings)
        if isUpdateAvailable {
            list.append(updateSeparator)
            list.append(updateAvailableRow, name: "Update")
        }
        if let foldAnimation, !dragTracker.isDragging, let rowItem = deviceItems[.output]?[foldAnimation.uid],
           let start = list.items.firstIndex(of: rowItem),
           let end = list.items.firstIndex(of: airPodsName != nil ? airPodsSettings : soundSettings)
        {
            list.replace((start + 1) ..< end, with: foldAnimation.item, name: "fold")
        }
        show(list)
    }

    private func appendSection(_ direction: Direction, rows: [AppModel.Row], to list: inout PanelItemList) {
        let section = section(for: direction)
        list.append(section.header)
        if dragTracker.direction == direction {
            list.append(section.dragLayer.item, name: "\(direction) drag layer")
            list.append(section.separator)
            return
        }
        var kept: [String: NSMenuItem] = [:]
        for row in rows {
            let device = row.device
            let item = deviceItems[direction]?[row.id] ?? Self.item(DeviceRow(
                model: model,
                direction: direction,
                device: device,
                dragActions: dragActions,
                hide: { [weak self] in self?.hide(device, in: direction) }
            ))
            kept[row.id] = item
            list.append(item, name: "\(direction) \"\(row.device.name)\"")
            if foldAnimation == nil, let idle = foldAnimations[row.id] {
                list.append(idle.item, name: "idle fold")
            }
            if row.isFoldedOpen, foldAnimation?.uid != row.id, let modes = row.listening?.supported {
                let group = listeningGroups[row.id]
                    .flatMap { $0.modes == modes ? $0 : nil } ?? ListeningModeGroupItem(
                        modes: modes,
                        item: Self.item(ListeningModeGroup(model: model, device: row.device, modes: modes))
                    )
                listeningGroups[row.id] = group
                list.append(group.item, name: "listening mode of \"\(row.device.name)\"")
            }
        }
        deviceItems[direction] = kept
        list.append(section.separator)
    }

    /// Runs before the panel shows, because an item inserted into an open menu leaves the panel empty, on most first opens after launch, for over a second.
    private func prepareFoldAnimations() {
        for row in model.rows[.output] ?? [] {
            guard let modes = row.listening?.supported, foldAnimations[row.id]?.modes != modes else { continue }
            foldAnimations[row.id] = FoldAnimation(model: model, device: row.device, modes: modes)
        }
        updateItems()
    }

    /// A fold animates only while the panel shows and no drag runs; otherwise the row takes its end state at once.
    private func startFoldAnimations(_ rows: [AppModel.Row]) {
        for row in rows where row.isFoldedOpen != foldedOpenUIDs.contains(row.id) {
            if row.isFoldedOpen {
                foldedOpenUIDs.insert(row.id)
            } else {
                foldedOpenUIDs.remove(row.id)
            }
            let isPanelOpen = panelWindow?.isVisible == true
            guard isPanelOpen, !dragTracker.isDragging, let modes = row.listening?.supported else { continue }
            let animation = foldAnimations[row.id].flatMap { $0.modes == modes ? $0 : nil } ?? FoldAnimation(
                model: model,
                device: row.device,
                modes: modes
            )
            foldAnimations[row.id] = animation
            foldAnimation = animation
            animation.start(isOpening: row.isFoldedOpen) { [weak self, weak animation] in
                guard let self, foldAnimation === animation else { return }
                foldAnimation = nil
                updateItemsUnderRestingPointer(in: panelWindow)
                // The window can stay 1 pt taller than its items after a fold, until the menu measures itself again.
                _ = panel.size
            }
        }
    }

    private func section(for direction: Direction) -> SectionItems {
        switch direction {
        case .output: outputSection
        case .input: inputSection
        }
    }

    private var panelWindow: NSWindow? {
        panel.items.first?.view?.window
    }

    private var dragActions: RowDragActions {
        RowDragActions(
            changed: { [weak self] device, direction, translation in
                guard let self else { return }
                dragTracker.changed(device, translation: translation, layer: section(for: direction).dragLayer)
            },
            released: { [weak self] in
                guard let self, dragTracker.isDragging else { return }
                dragTracker.end()
            }
        )
    }

    /// The row below slides under the resting pointer, and shows its hover and its Hide button only once the menu sees a pointer move.
    private func hide(_ device: Device, in direction: Direction) {
        model.hide(device, in: direction)
        updateItemsUnderRestingPointer(in: panelWindow)
    }

    /// The menu picks the item under the pointer only on a pointer move, and the pointer has not moved since the update.
    private func updateItemsUnderRestingPointer(in window: NSWindow?) {
        updateItems()
        RunLoop.main.perform(inModes: [.common]) {
            guard let window else { return }
            Self.reportPointer(at: window.convertPoint(fromScreen: NSEvent.mouseLocation), in: window)
        }
    }

    private static func reportPointer(at location: NSPoint, in window: NSWindow) {
        guard
            let event = NSEvent.mouseEvent(
                with: .mouseMoved, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 0, pressure: 0
            )
        else { return }
        NSApp.postEvent(event, atStart: false)
    }

    private func updateIcon() {
        let icon = withObservationTracking {
            model.menuBarIcon
        } onChange: { [weak self] in
            Task { @MainActor in self?.updateIcon() }
        }
        iconView?.show(icon)
    }
}

private extension StatusItemController {
    /// Inserts only the items not yet at their place, and logs them by name.
    func show(_ list: PanelItemList) {
        let items = list.items
        var moved: [String] = []
        for (index, item) in items.enumerated()
            where !panel.items.indices.contains(index) || panel.items[index] !== item
        {
            if item.menu != nil {
                panel.removeItem(item)
            }
            panel.insertItem(item, at: index)
            moved.append(list.names[ObjectIdentifier(item)] ?? "other")
        }
        let removedCount = panel.items.count - items.count
        while panel.items.count > items.count {
            panel.removeItem(at: items.count)
        }
        foldAnimation?.layOut()
        if !moved.isEmpty || removedCount > 0 {
            panelLog.notice("items inserted: \(moved.joined(separator: ", ")); removed from the end: \(removedCount)")
        }
    }
}

/// A section's items, built with the panel and kept while io runs; the drag layer is built here, so a drag starts without building a view.
private struct SectionItems {
    let header: NSMenuItem
    let separator: NSMenuItem
    let dragLayer: DragLayerItem
}

/// The panel's items in order, with the name the log gives each one.
private struct PanelItemList {
    private(set) var items: [NSMenuItem] = []
    private(set) var names: [ObjectIdentifier: String] = [:]

    mutating func append(_ item: NSMenuItem) {
        items.append(item)
    }

    mutating func append(_ item: NSMenuItem, name: String) {
        items.append(item)
        names[ObjectIdentifier(item)] = name
    }

    mutating func replace(_ range: Range<Int>, with item: NSMenuItem, name: String) {
        items.replaceSubrange(range, with: [item])
        names[ObjectIdentifier(item)] = name
    }
}

private struct ListeningModeGroupItem {
    let modes: [ListeningMode]
    let item: NSMenuItem
}

/// Reads what can change while the panel is closed, before it shows.
private final class PanelDelegate: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let log = MenuLog()
    var willOpen: (() -> Void)?

    init(model: AppModel) {
        self.model = model
    }

    func menuWillOpen(_ menu: NSMenu) {
        log.menuWillOpen(menu)
        model.panelWillOpen()
        willOpen?()
    }

    func menuDidClose(_ menu: NSMenu) {
        log.menuDidClose(menu)
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        log.menu(menu, willHighlight: item)
    }
}
