import IOKit.ps
import notify
import Priority

/// The battery levels of connected headphones, from the accessory power sources that `pmset -g accps` lists. A read takes about 0.1 ms on macOS 27 and needs no permission, where `IOBluetoothDevice` needs the Bluetooth permission.
enum AirPodsBattery {
    private typealias CopyPowerSourcesByType = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?

    /// Not in the SDK headers; IOKit exports it, and `pmset` calls it. Type 4 returns the accessories only, on macOS 27.
    private static let copyPowerSourcesByType = dlsym(
        UnsafeMutableRawPointer(bitPattern: -2),
        "IOPSCopyPowerSourcesByType"
    )
    .map { unsafeBitCast($0, to: CopyPowerSourcesByType.self) }
    private static let accessories: Int32 = 4

    static func levels() -> [String: BatteryLevels] {
        guard let blob = copyPowerSourcesByType?(accessories)?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return [:] }
        let sources = list
            .compactMap { IOPSGetPowerSourceDescription(blob, $0)?.takeUnretainedValue() as? [String: Any] }
        return BatteryLevels.byName(sources)
    }

    /// macOS posts the notification for every power source, the Mac's own battery included.
    static func observe(onChange: @escaping @MainActor () -> Void) {
        var token: Int32 = 0
        notify_register_dispatch(kIOPSNotifyAnyPowerSource, &token, .main) { _ in
            MainActor.assumeIsolated { onChange() }
        }
    }
}
