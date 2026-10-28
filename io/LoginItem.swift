import Foundation
import ServiceManagement

enum LoginItem {
    private static let registeredKey = "didRegisterLoginItem"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// A failed registration is retried at the next launch.
    static func registerOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: registeredKey), setEnabled(true) else { return }
        UserDefaults.standard.set(true, forKey: registeredKey)
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("io: login item change failed: \(error)")
            return false
        }
    }
}
