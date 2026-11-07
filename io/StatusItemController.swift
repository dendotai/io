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
    private let sections: PerDirection<SectionItems>
    private let airPodsSettings: NSMenuItem
    private let soundSettings: NSMenuItem
    private let updateSeparator: NSMenuItem
    private let updateAvailableRow: NSMenuItem
    private var deviceItems: [Direction: [String: NSMenuItem]] = [:]
    /// Each AirPods row's group while folded open, built when it first folds open and again if its supported modes change.
    private var listeningGroups: [String: (modes: [ListeningMode], item: NSMenuItem)] = [:]
    private var foldedOpenUIDs: Set<String> = []
    /// Each AirPods row's fold layer, built when the panel opens.
    private var foldAnimations: [String: FoldAnimation] = [:]
    private var foldAnimation: FoldAnimation?
    /// During a drag, one item holds the dragged row's whole section, so the row can slide over its neighbours (ADR 0001).
    private var drag: (direction: Direction, startY: CGFloat, timer: Timer, ticksSinceButtonUp: Int)?
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
        sections = PerDirection { direction in
            let drag = RowDrag(direction: direction)
            return SectionItems(
                header: Self.item(SectionHeader(model: model, direction: direction)),
                separator: Self.item(PanelSeparator(inset: direction.separatorInset)),
                dragLayer: DragLayerItem(drag: drag, item: Self.item(DragLayer(model: model, drag: drag))))
        }
        // A custom view item does not close the menu when clicked, and the Sound menu closes as System Settings opens.
        let menu = NSMenu()
        self.menu = menu
        airPodsSettings = Self.item(AirPodsSettingsRow(model: model) {
            menu.cancelTracking()
            model.openAirPodsSettings()
        })
        soundSettings = Self.item(MenuRow(title: "Sound Settings…") {
            menu.cancelTracking()
            model.openSoundSettings()
        })
        updateSeparator = Self.item(PanelSeparator(inset: Metrics.edgeInset))
        updateAvailableRow = Self.item(UpdateRow(updater: updater) {
            menu.cancelTracking()
            updater.installUpdate()
        })
        panelDelegate = PanelDelegate(model: model)
        rightClickMenuDelegate = RightClickMenuDelegate(updater: updater)
        menu.delegate = panelDelegate
        panelDelegate.willOpen = { [weak self] in self?.prepareFoldAnimations() }
        statusItem.menu = menu
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
            let section = sections[direction]
            items.append(section.header)
            if drag?.direction == direction {
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
                    if listeningGroups[row.id]?.modes != modes {
                        listeningGroups[row.id] = (modes, Self.item(ListeningModeGroup(model: model, device: row.device, modes: modes)))
                    }
                    let groupItem = listeningGroups[row.id]!.item
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
        if let foldAnimation, drag == nil, let rowItem = deviceItems[.output]?[foldAnimation.uid], let start = items.firstIndex(of: rowItem),
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
            let isPanelOpen = menu.items.first?.view?.window?.isVisible == true
            guard isPanelOpen, drag == nil, let modes = row.listening?.supported else { continue }
            let animation = foldAnimations[row.id].flatMap { $0.modes == modes ? $0 : nil } ?? FoldAnimation(model: model, device: row.device, modes: modes)
            foldAnimations[row.id] = animation
            foldAnimation = animation
            animation.start(isOpening: row.isFoldedOpen) { [weak self, weak animation] in
                guard let self, foldAnimation === animation else { return }
                foldAnimation = nil
                updateItemsUnderRestingPointer(in: menu.items.first?.view?.window)
                // The window can stay 1 pt taller than its items after a fold, until the menu measures itself again.
                _ = menu.size
            }
        }
    }

    private var dragActions: RowDragActions {
        RowDragActions(
            pressed: { [weak self] device, direction in self?.pressed(device, in: direction) },
            changed: { [weak self] device, direction, translation in self?.dragChanged(device, in: direction, translation: translation) },
            released: { [weak self] in self?.released() }
        )
    }

    /// AppKit reopens a pressed row's submenu about 200 ms after the press, with no move, and the drag swap then closes it again, so the pressed row has no "Hide" until release.
    private func pressed(_ device: Device, in direction: Direction) {
        deviceItems[direction]?[device.uid]?.submenu = nil
    }

    /// A release that reaches the menu while a "›" row is under the pointer keeps "Hide" closed until the pointer moves, so a drag ends only after the menu has handled its release.
    private func released() {
        if drag != nil {
            RunLoop.main.perform(inModes: [.common]) { [weak self] in self?.endDrag() }
            return
        }
        // After a click on a "›" row the menu opens "Hide" only once the pointer enters the row again, so the report passes over the row above first.
        updateItemsUnderRestingPointer(in: menu.items.first?.view?.window, reentering: true)
    }

    /// The row that started the drag leaves the menu at the swap, so its drag events keep coming but report a wrong distance: each one reads the pointer instead, and a timer ends the drag if the release never reaches the row.
    private func dragChanged(_ device: Device, in direction: Direction, translation: CGFloat) {
        let pointerY = NSEvent.mouseLocation.y
        if let drag {
            let moved = drag.startY - pointerY
            let state = sections[drag.direction].dragLayer.drag
            if moved != state.translation {
                state.translation = moved
            }
            return
        }
        let layer = sections[direction].dragLayer
        layer.drag.uid = device.uid
        layer.drag.translation = translation
        // The section may have gained or lost rows since the panel was built.
        if let view = layer.item.view {
            view.setFrameSize(view.fittingSize)
        }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            self?.watchRelease()
        }
        RunLoop.main.add(timer, forMode: .common)
        // The first event's translation is still right, and holds the move made before the drag began.
        drag = (direction, pointerY + translation, timer, 0)
        panelLog.notice("drag start \(String(describing: direction)) \"\(device.name)\"")
        updateItems()
    }

    /// The release reaches the row within about 50 ms after the button goes up, so 200 ms leaves room.
    private func watchRelease() {
        guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
        drag?.ticksSinceButtonUp += 1
        if let drag, drag.ticksSinceButtonUp > 12 {
            endDrag()
        }
    }

    private func endDrag() {
        guard let drag else { return }
        drag.timer.invalidate()
        self.drag = nil
        panelLog.notice("drag end")
        let layer = sections[drag.direction].dragLayer
        let state = layer.drag
        if let move = state.move(in: model.rows[drag.direction] ?? []) {
            model.reorder(move.device, to: move.to, in: drag.direction)
        }
        state.uid = nil
        // The swapped-in row views are not in the menu's window yet, so take the window from the drag layer before it leaves.
        updateItemsUnderRestingPointer(in: layer.item.view?.window)
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

/// A section's drag layer: the drag state its view draws, and the item that holds the view.
struct DragLayerItem {
    let drag: RowDrag
    let item: NSMenuItem
}

/// One value for each direction, so a lookup needs no unwrap.
struct PerDirection<Value> {
    private let output: Value
    private let input: Value

    init(_ make: (Direction) -> Value) {
        output = make(.output)
        input = make(.input)
    }

    subscript(direction: Direction) -> Value {
        switch direction {
        case .output: output
        case .input: input
        }
    }
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
