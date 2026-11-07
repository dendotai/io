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
            // `io -showUpdateVersion <version>` acts as if that update exists, in the rendered panel and in the running app.
            if let version = UserDefaults.standard.string(forKey: "showUpdateVersion") {
                updater.showUpdateWithoutChecking(version: version)
            }
            // `io -renderPanelTo <png>` writes the panel content at 2x for comparison with a Sound menu screenshot, without opening the menu or reading the user's screen.
            if let path = UserDefaults.standard.string(forKey: "renderPanelTo") {
                model.showDevicesWithoutSwitching()
                PanelSnapshot.write(PanelView(model: model, updater: updater), to: URL(fileURLWithPath: path))
                NSApp.terminate(nil)
                return
            }
        #endif
        panelLog.notice("launch \(Bundle.main.bundlePath) version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown") on \(ProcessInfo.processInfo.operatingSystemVersionString)")
        LoginItem.registerOnFirstLaunch()
        model.start()
        #if DEBUG
            // `io -pickOutput <name>` picks that output as a click in the panel does, because io sets back a change another process makes.
            if let name = UserDefaults.standard.string(forKey: "pickOutput") {
                model.pickOutput(named: name)
            }
        #endif
        updater.start()
        statusItem = StatusItemController(model: model, updater: updater)
    }
}
