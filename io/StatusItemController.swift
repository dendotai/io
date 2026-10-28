import AppKit
import SwiftUI

/// The panel is an `NSMenu` whose one item hosts the SwiftUI content (ADR 0001).
final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let model: AppModel

    init(model: AppModel) {
        self.model = model

        let item = NSMenuItem()
        let hosting = NSHostingView(rootView: AnyView(EmptyView()))
        hosting.rootView = AnyView(
            PanelView(model: model).onGeometryChange(for: CGSize.self, of: \.size) { [weak hosting] size in
                hosting?.setFrameSize(size)
            }
        )
        hosting.setFrameSize(hosting.fittingSize)
        item.view = hosting

        let menu = NSMenu()
        menu.addItem(item)
        statusItem.menu = menu
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
}
