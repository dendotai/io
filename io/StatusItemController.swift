import AppKit
import SwiftUI

/// The panel is a borderless window, not an `NSPopover` or `MenuBarExtra` (ADR 0001).
final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panel: PanelWindow
    private let model: AppModel
    private var clickMonitor: Any?
    private var keyMonitor: Any?

    init(model: AppModel) {
        self.model = model
        panel = PanelWindow(rootView: PanelView(model: model))

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(toggle)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon()
    }

    private func updateIcon() {
        let symbolName = withObservationTracking {
            model.inUseSymbolName
        } onChange: { [weak self] in
            Task { @MainActor in self?.updateIcon() }
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "io")
    }

    @objc private func toggle() {
        panel.isVisible ? close() : open()
    }

    private func open() {
        guard let button = statusItem.button, let barWindow = button.window, let screen = barWindow.screen else { return }
        let buttonFrame = barWindow.convertToScreen(button.convert(button.bounds, to: nil))
        panel.show(below: barWindow.frame.minY, alignedTo: buttonFrame.minX, on: screen.visibleFrame)
        button.highlight(true)

        // Clicks in other apps never reach this app, so only a global monitor sees them.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.close()
            return nil
        }
    }

    private func close() {
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        for monitor in [clickMonitor, keyMonitor].compactMap(\.self) {
            NSEvent.removeMonitor(monitor)
        }
        clickMonitor = nil
        keyMonitor = nil
    }
}

final class PanelWindow: NSPanel {
    private static let gapBelowMenuBar: CGFloat = 1
    private var top: CGFloat = 0

    init(rootView: some View) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let glass = NSGlassEffectView()
        glass.cornerRadius = 14
        let hosting = NSHostingView(rootView: rootView.onGeometryChange(for: CGSize.self, of: \.size) { [weak self] size in
            self?.resize(to: size)
        })
        glass.contentView = hosting
        contentView = glass
    }

    override var canBecomeKey: Bool { true }

    func show(below menuBarBottom: CGFloat, alignedTo left: CGFloat, on visibleFrame: NSRect) {
        top = menuBarBottom - Self.gapBelowMenuBar
        let size = (contentView as? NSGlassEffectView)?.contentView?.fittingSize ?? .zero
        let x = min(max(left, visibleFrame.minX), visibleFrame.maxX - size.width)
        setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)
        makeKeyAndOrderFront(nil)
    }

    /// Keeps the top edge under the menu bar when the content grows or shrinks.
    private func resize(to size: CGSize) {
        guard isVisible, size != frame.size else { return }
        setFrame(NSRect(x: frame.minX, y: top - size.height, width: size.width, height: size.height), display: true)
    }
}
