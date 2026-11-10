import AppKit
import SwiftUI

/// Builds the right-click menu each time it opens, because the login item can change in System Settings while io runs.
final class RightClickMenuDelegate: NSObject, NSMenuDelegate {
    private let updater: AppUpdater
    var didClose: (() -> Void)?

    init(updater: AppUpdater) {
        self.updater = updater
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        // An item with no action is drawn greyed out, takes no highlight, and ignores a click.
        menu.addItem(NSMenuItem(title: Self.versionTitle, action: nil, keyEquivalent: ""))
        if let updateTitle = updater.updateTitle {
            menu.addItem(item(updateTitle, #selector(installUpdate)))
        }
        menu.addItem(.separator())
        let openAtLogin = NSMenuItem()
        let row = NSHostingView(rootView: OpenAtLoginRow())
        row.setFrameSize(row.fittingSize)
        openAtLogin.view = row
        menu.addItem(openAtLogin)
        menu.addItem(item("Quit io", #selector(quit)))
    }

    func menuDidClose(_: NSMenu) {
        didClose?()
    }

    /// A Debug build shows no number, because only `scripts/build-app.sh` sets the release version and the project's own `MARKETING_VERSION` lags behind it.
    private static var versionTitle: String {
        #if DEBUG
            "Debug build"
        #else
            "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")"
        #endif
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
