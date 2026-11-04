import AppKit
import Priority
import SwiftUI

/// The panel is an `NSMenu` with one item per header, device row, separator, and footer, each hosting SwiftUI content (ADR 0001).
final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let model: AppModel
    private let updater: AppUpdater
    private let menu: NSMenu
    private let volumeSlider: NSMenuItem
    private let volumeSeparator: NSMenuItem
    private let headers: [Direction: NSMenuItem]
    private let separators: [Direction: NSMenuItem]
    private let airPodsSettings: NSMenuItem
    private let soundSettings: NSMenuItem
    private let footerSeparator: NSMenuItem
    private let footer: NSMenuItem
    private let updateAvailable: NSMenuItem
    private var deviceItems: [Direction: [String: NSMenuItem]] = [:]
    /// Each AirPods row's group while folded open, built when it first folds open and again if its supported modes change.
    private var listeningGroups: [String: (modes: [ListeningMode], item: NSMenuItem)] = [:]
    private var foldedOpenUIDs: Set<String> = []
    /// Each AirPods row's fold layer, built when the panel opens.
    private var foldAnimations: [String: FoldAnimation] = [:]
    private var foldAnimation: FoldAnimation?
    /// During a drag, one item holds the dragged row's whole section, so the row can slide over its neighbours (ADR 0001).
    private var drag: (direction: Direction, startY: CGFloat, timer: Timer, ticksSinceButtonUp: Int)?
    /// Built with the panel, so a drag starts without building a view.
    private let dragLayers: [Direction: (state: RowDrag, item: NSMenuItem)]
    private let openSubmenu = OpenSubmenu()
    private let panelDelegate: PanelDelegate

    init(model: AppModel, updater: AppUpdater) {
        self.model = model
        self.updater = updater
        volumeSlider = Self.item(VolumeSlider(model: model))
        volumeSeparator = Self.item(PanelSeparator(inset: Metrics.contentInset))
        headers = Dictionary(uniqueKeysWithValues: Direction.allCases.map { ($0, Self.item(SectionHeader(direction: $0))) })
        separators = Dictionary(uniqueKeysWithValues: Direction.allCases.map { ($0, Self.item(PanelSeparator(inset: $0.separatorInset))) })
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
        footerSeparator = Self.item(PanelSeparator(inset: Metrics.edgeInset))
        footer = Self.item(PanelFooter())
        updateAvailable = Self.item(MenuRow(title: "Update Available…") {
            menu.cancelTracking()
            updater.installUpdate()
        })
        var dragLayers: [Direction: (state: RowDrag, item: NSMenuItem)] = [:]
        for direction in Direction.allCases {
            let state = RowDrag(direction: direction)
            dragLayers[direction] = (state, Self.item(DragLayer(model: model, drag: state)))
        }
        self.dragLayers = dragLayers
        panelDelegate = PanelDelegate(model: model)
        menu.delegate = panelDelegate
        panelDelegate.willOpen = { [weak self] in self?.prepareFoldAnimations() }
        statusItem.menu = menu
        updateItems()
        updateIcon()
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
            (model.rows, model.airPodsName, updater.isUpdateAvailable)
        } onChange: { [weak self] in
            // Common modes, so the menu follows a connect while it is open.
            RunLoop.main.perform(inModes: [.common]) { self?.updateItems() }
        }

        startFoldAnimations(rows[.output] ?? [])

        var items: [NSMenuItem] = [volumeSlider, volumeSeparator]
        var names: [ObjectIdentifier: String] = [:]
        for direction in Direction.allCases {
            items.append(headers[direction]!)
            if drag?.direction == direction {
                items.append(dragLayers[direction]!.item)
                names[ObjectIdentifier(dragLayers[direction]!.item)] = "\(direction) drag layer"
                items.append(separators[direction]!)
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
                if foldAnimation?.uid != row.id, let idle = foldAnimations[row.id] {
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
            items.append(separators[direction]!)
        }
        if airPodsName != nil {
            items.append(airPodsSettings)
            names[ObjectIdentifier(airPodsSettings)] = "AirPods Settings"
        }
        items += [soundSettings, footerSeparator, footer]
        if isUpdateAvailable {
            items.append(updateAvailable)
            names[ObjectIdentifier(updateAvailable)] = "Update Available"
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
            panelLog.notice("items inserted: \(moved.joined(separator: ", "), privacy: .public); removed from the end: \(removedCount)")
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
            if moved != dragLayers[drag.direction]!.state.translation {
                dragLayers[drag.direction]!.state.translation = moved
            }
            return
        }
        let layer = dragLayers[direction]!
        layer.state.uid = device.uid
        layer.state.translation = translation
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
        panelLog.notice("drag start \(String(describing: direction), privacy: .public) \"\(device.name, privacy: .public)\"")
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
        let state = dragLayers[drag.direction]!.state
        let rows = model.rows[drag.direction] ?? []
        if let from = rows.firstIndex(where: { $0.id == state.uid }), let to = state.targetIndex(in: rows), to != from {
            model.reorder(rows[from].device, to: to, in: drag.direction)
        }
        state.uid = nil
        // The swapped-in row views are not in the menu's window yet, so take the window from the drag layer before it leaves.
        updateItemsUnderRestingPointer(in: dragLayers[drag.direction]!.item.view?.window)
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
        let symbolName = withObservationTracking {
            model.inUseSymbolName
        } onChange: { [weak self] in
            Task { @MainActor in self?.updateIcon() }
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "io")
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
}
