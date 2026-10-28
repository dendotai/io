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
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
            // `io -renderPanelTo <png>` writes the panel content at 2x for comparison with a Sound menu screenshot, without opening the menu or reading the user's screen.
            if let path = UserDefaults.standard.string(forKey: "renderPanelTo") {
                model.showDevicesWithoutSwitching()
                PanelSnapshot.write(PanelView(model: model), to: URL(fileURLWithPath: path))
                NSApp.terminate(nil)
                return
            }
        #endif
        LoginItem.registerOnFirstLaunch()
        model.start()
        statusItem = StatusItemController(model: model)
    }
}
