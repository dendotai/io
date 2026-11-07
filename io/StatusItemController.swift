import AppKit
import Priority
import SwiftUI

/// The panel is an `NSMenu` with one item per header, device row, and separator, each hosting SwiftUI content (ADR 0001).
final class StatusItemController {
    /// The Sound icon's gaps to its neighbours, from Size, spacing, and animations in `docs/sound-menu.md`.
    private let statusItem = NSStatusBar.system.statusItem(withLength: 32)
    private let model: AppModel
    private let updater: AppUpdater
    private let menu: NSMenu
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
    private let openSubmenu = OpenSubmenu()
    private let panelDelegate: PanelDelegate
    private let rightClickMenu = NSMenu()
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
                dragLayer: DragLayerItem(rowDrag: rowDrag, item: Self.item(DragLayer(model: model, drag: rowDrag))))
        }
        outputSection = makeSection(.output)
        inputSection = makeSection(.input)
        let menu = NSMenu()
        self.menu = menu
        // A custom view item does not close the menu when clicked, and the Sound menu closes as System Settings opens.
        func closingMenu(_ action: @escaping () -> Void) -> () -> Void {
            {
                menu.cancelTracking()
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
        menu.delegate = panelDelegate
        panelDelegate.willOpen = { [weak self] in self?.prepareFoldAnimations() }
        statusItem.menu = menu
        dragTracker.didStart = { [weak self] in self?.updateItems() }
        dragTracker.didEnd = { [weak self] window in self?.updateItemsUnderRestingPointer(in: window) }
        rightClickMenu.delegate = rightClickMenuDelegate
        rightClickMenuDelegate.didClose = { [weak self] in self?.statusItem.menu = menu }
        watchRightClicks()
        updateItems()
        iconView = statusItem.button.map(MenuBarIconView.init)
        statusItem.button?.setAccessibilityLabel("io")
        updateIcon()
        #if DEBUG
            debugMark = statusItem.button.map(DebugMark.init)
        #endif
    }

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

        var items: [NSMenuItem] = [volumeSlider, volumeSeparator]
        var names: [ObjectIdentifier: String] = [:]
        for direction in Direction.allCases {
            let section = section(for: direction)
            items.append(section.header)
            if dragTracker.direction == direction {
                items.append(section.dragLayer.item)
                names[ObjectIdentifier(section.dragLayer.item)] = "\(direction) drag layer"
                items.append(section.separator)
                continue
            }
            var kept: [String: NSMenuItem] = [:]
            for row in rows[direction] ?? [] {
                let item = deviceItems[direction]?[row.id] ?? Self.item(DeviceRow(model: model, direction: direction, device: row.device, dragActions: dragActions, openSubmenu: openSubmenu))
                if !row.canHide {
                    item.submenu = nil
                } else if item.submenu == nil {
                    item.submenu = hideMenu(row.device, in: direction)
                }
                kept[row.id] = item
                names[ObjectIdentifier(item)] = "\(direction) \"\(row.device.name)\""
                items.append(item)
                if foldAnimation == nil, let idle = foldAnimations[row.id] {
                    names[ObjectIdentifier(idle.item)] = "idle fold"
                    items.append(idle.item)
                }
                if row.isFoldedOpen, foldAnimation?.uid != row.id, let modes = row.listening?.supported {
                    let group = listeningGroups[row.id].flatMap { $0.modes == modes ? $0 : nil } ?? ListeningModeGroupItem(modes: modes, item: Self.item(ListeningModeGroup(model: model, device: row.device, modes: modes)))
                    listeningGroups[row.id] = group
                    let groupItem = group.item
                    names[ObjectIdentifier(groupItem)] = "listening mode of \"\(row.device.name)\""
                    items.append(groupItem)
                }
            }
            deviceItems[direction] = kept
            items.append(section.separator)
        }
        if airPodsName != nil {
            items.append(airPodsSettings)
            names[ObjectIdentifier(airPodsSettings)] = "AirPods Settings"
        }
        items.append(soundSettings)
        if isUpdateAvailable {
            items += [updateSeparator, updateAvailableRow]
            names[ObjectIdentifier(updateAvailableRow)] = "Update"
        }
        if let foldAnimation, !dragTracker.isDragging, let rowItem = deviceItems[.output]?[foldAnimation.uid], let start = items.firstIndex(of: rowItem),
            let end = items.firstIndex(of: airPodsName != nil ? airPodsSettings : soundSettings)
        {
            items.replaceSubrange((start + 1)..<end, with: [foldAnimation.item])
            names[ObjectIdentifier(foldAnimation.item)] = "fold"
        }

        var moved: [String] = []
        for (index, item) in items.enumerated() where !menu.items.indices.contains(index) || menu.items[index] !== item {
            if item.menu != nil {
                menu.removeItem(item)
            }
            menu.insertItem(item, at: index)
            moved.append(names[ObjectIdentifier(item)] ?? "other")
        }
        let removedCount = menu.items.count - items.count
        while menu.items.count > items.count {
            menu.removeItem(at: items.count)
        }
        if !moved.isEmpty || removedCount > 0 {
            panelLog.notice("items inserted: \(moved.joined(separator: ", ")); removed from the end: \(removedCount)")
        }
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
            let animation = foldAnimations[row.id].flatMap { $0.modes == modes ? $0 : nil } ?? FoldAnimation(model: model, device: row.device, modes: modes)
            foldAnimations[row.id] = animation
            foldAnimation = animation
            animation.start(isOpening: row.isFoldedOpen) { [weak self, weak animation] in
                guard let self, foldAnimation === animation else { return }
                foldAnimation = nil
                updateItemsUnderRestingPointer(in: panelWindow)
                // The window can stay 1 pt taller than its items after a fold, until the menu measures itself again.
                _ = menu.size
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
        menu.items.first?.view?.window
    }

    private var dragActions: RowDragActions {
        RowDragActions(
            pressed: { [weak self] device, direction in self?.pressed(device, in: direction) },
            changed: { [weak self] device, direction, translation in
                guard let self else { return }
                dragTracker.changed(device, translation: translation, layer: section(for: direction).dragLayer)
            },
            released: { [weak self] in self?.released() }
        )
    }

    /// AppKit reopens a pressed row's submenu about 200 ms after the press, with no move, and the drag swap then closes it again, so the pressed row has no "Hide" until release.
    private func pressed(_ device: Device, in direction: Direction) {
        deviceItems[direction]?[device.uid]?.submenu = nil
    }

    /// A release that reaches the menu while a "›" row is under the pointer keeps "Hide" closed until the pointer moves, so a drag ends only after the menu has handled its release.
    private func released() {
        if dragTracker.isDragging {
            dragTracker.endAfterRelease()
            return
        }
        // After a click on a "›" row the menu opens "Hide" only once the pointer enters the row again, so the report passes over the row above first.
        updateItemsUnderRestingPointer(in: panelWindow, reentering: true)
    }

    /// The menu picks the item under the pointer, and opens its "Hide" submenu, only on a pointer move, and the pointer has not moved since the update.
    private func updateItemsUnderRestingPointer(in window: NSWindow?, reentering: Bool = false) {
        updateItems()
        RunLoop.main.perform(inModes: [.common]) {
            guard let window else { return }
            let location = window.convertPoint(fromScreen: NSEvent.mouseLocation)
            if reentering {
                Self.reportPointer(at: NSPoint(x: location.x, y: location.y + Metrics.deviceRowHeight), in: window)
            }
            Self.reportPointer(at: location, in: window)
        }
    }

    private static func reportPointer(at location: NSPoint, in window: NSWindow) {
        guard
            let event = NSEvent.mouseEvent(
                with: .mouseMoved, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 0, pressure: 0)
        else { return }
        NSApp.postEvent(event, atStart: false)
    }

    private func hideMenu(_ device: Device, in direction: Direction) -> NSMenu {
        let item = Self.item(HideRow { [weak self] in
            // The row leaves the menu with its submenu open, and AppKit may not report the close.
            self?.openSubmenu.uid = nil
            self?.model.hide(device, in: direction)
        })
        // Names the row for `openSubmenu`.
        item.representedObject = device.uid
        let submenu = NSMenu()
        submenu.delegate = openSubmenu
        submenu.addItem(item)
        return submenu
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

/// A section's items, built with the panel and kept while io runs; the drag layer is built here, so a drag starts without building a view.
private struct SectionItems {
    let header: NSMenuItem
    let separator: NSMenuItem
    let dragLayer: DragLayerItem
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

/// Builds the right-click menu each time it opens, because the login item can change in System Settings while io runs.
private final class RightClickMenuDelegate: NSObject, NSMenuDelegate {
    private let updater: AppUpdater
    var didClose: (() -> Void)?

    init(updater: AppUpdater) {
        self.updater = updater
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let updateTitle = updater.updateTitle {
            menu.addItem(item(updateTitle, #selector(installUpdate)))
            menu.addItem(.separator())
        }
        let openAtLogin = NSMenuItem()
        let row = NSHostingView(rootView: OpenAtLoginRow())
        row.setFrameSize(row.fittingSize)
        openAtLogin.view = row
        menu.addItem(openAtLogin)
        menu.addItem(item("Quit io", #selector(quit)))
    }

    func menuDidClose(_ menu: NSMenu) {
        didClose?()
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func installUpdate() {
        updater.installUpdate()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
