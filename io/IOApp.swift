import SwiftUI

@main
struct IOApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let updater = AppUpdater()
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
            // `io -renderPanelTo <png>` writes the panel content at 2x for comparison with a Sound menu screenshot, without opening the menu or reading the user's screen.
            if let path = UserDefaults.standard.string(forKey: "renderPanelTo") {
                model.showDevicesWithoutSwitching()
                if let version = UserDefaults.standard.string(forKey: "renderUpdateVersion") {
                    updater.showUpdateWithoutChecking(version: version)
                }
                PanelSnapshot.write(PanelView(model: model, updater: updater), to: URL(fileURLWithPath: path))
                NSApp.terminate(nil)
                return
            }
        #endif
        LoginItem.registerOnFirstLaunch()
        model.start()
        updater.start()
        statusItem = StatusItemController(model: model, updater: updater)
    }
}
