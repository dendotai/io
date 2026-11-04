/// The AirPods setting the Sound menu offers under "Listening Mode". The raw values are the ones the private Bluetooth peer setting `listeningMode` takes on macOS 27.
public enum ListeningMode: UInt8, Sendable {
    case off = 1
    case noiseCancellation = 2
    case transparency = 3
    case adaptive = 4

    /// macOS reports no flag for Adaptive, so it goes by product ID: AirPods Pro 2 (Lightning and USB-C), AirPods Pro 3, and AirPods 4 with Active Noise Cancellation, from https://theapplewiki.com/wiki/Bluetooth_PIDs.
    private static let adaptiveProductIDs: Set<UInt16> = [0x2014, 0x2024, 0x2027, 0x201B]

    /// The modes in the Sound menu's order; empty for a pair with no noise cancellation, which the Sound menu shows no listening mode for.
    public static func supported(productID: UInt16, isANCSupported: Bool) -> [ListeningMode] {
        guard isANCSupported else { return [] }
        return adaptiveProductIDs.contains(productID) ? [.off, .transparency, .adaptive, .noiseCancellation] : [.off, .transparency, .noiseCancellation]
    }
}
