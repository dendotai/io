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
    #if DEBUG
        private var debugPick: DebugPick?
    #endif

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
            debugPick = DebugPick(model: model)
        #endif
        updater.start()
        statusItem = StatusItemController(model: model, updater: updater)
    }
}

#if DEBUG
    /// `io -pickOutput <name>` at launch, or `defaults write ai.den.io pickOutput <name>` while io runs, picks that output as a click in the panel does, because io sets back a change another process makes. `defaults delete ai.den.io pickOutput` keeps the next launch from picking.
    final class DebugPick: NSObject {
        private static let key = "pickOutput"
        private let model: AppModel

        init(model: AppModel) {
            self.model = model
            super.init()
            // Only key-value observing reports a change another process makes.
            UserDefaults.standard.addObserver(self, forKeyPath: Self.key, options: [.initial], context: nil)
        }

        nonisolated override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            Task { @MainActor in
                if let name = UserDefaults.standard.string(forKey: Self.key) {
                    model.pickOutput(named: name)
                }
            }
        }
    }
#endif
