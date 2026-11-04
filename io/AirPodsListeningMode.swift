import AppKit
import IOBluetooth
import Priority

/// The listening mode of connected AirPods, through the private Bluetooth peer setting: `classicPeer` of the pair's `IOBluetoothDevice` and its `listeningMode`, tested on macOS 27.0.1. The peer answers only while a `CBClassicManager` is alive.
enum AirPodsListeningMode {
    struct State {
        let supported: [ListeningMode]
        let current: ListeningMode?
    }

    private typealias InitManager = @convention(c) (AnyObject, Selector, DispatchQueue?, NSDictionary?) -> AnyObject?

    private static var manager: AnyObject?

    /// Makes macOS ask for the Bluetooth permission on the first launch. Returns false when the private class is gone.
    static func start() -> Bool {
        let initSelector = NSSelectorFromString("initWithQueue:options:")
        guard manager == nil, let managerClass = NSClassFromString("CBClassicManager") as? NSObject.Type,
            managerClass.instancesRespond(to: initSelector),
            let alloc = managerClass.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject
        else { return manager != nil }
        let initialize = unsafeBitCast(alloc.method(for: initSelector), to: InitManager.self)
        manager = initialize(alloc, initSelector, .main, nil)
        return manager != nil
    }

    /// Keyed by `address(of:)`. A pair with no peer or no supported mode is left out.
    static func states() -> [String: State] {
        var states: [String: State] = [:]
        for device in IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [] where device.isConnected() {
            guard let address = device.addressString, let peer = peer(of: device),
                let isANCSupported = number(device, "isANCSupported")?.boolValue,
                let productID = number(peer, "productID")?.uint16Value,
                let rawMode = number(peer, "listeningMode")?.uint8Value
            else { continue }
            let supported = ListeningMode.supported(productID: productID, isANCSupported: isANCSupported)
            guard !supported.isEmpty else { continue }
            states[address.uppercased()] = State(supported: supported, current: ListeningMode(rawValue: rawMode))
        }
        return states
    }

    /// A Bluetooth device's Core Audio UID is its address and a direction, such as "BC-80-4E-E9-C0-AA:output"; `IOBluetoothDevice` reports the address in lower case.
    static func address(of device: Device) -> String {
        String(device.uid.prefix { $0 != ":" })
    }

    static func isConnected(address: String) -> Bool {
        IOBluetoothDevice(addressString: address)?.isConnected() == true
    }

    /// Returns false when the pair or its peer is gone; the caller reads the mode back to learn whether the AirPods took it.
    static func set(_ mode: ListeningMode, address: String) -> Bool {
        guard let device = IOBluetoothDevice(addressString: address), let peer = peer(of: device),
            peer.responds(to: NSSelectorFromString("setListeningMode:"))
        else { return false }
        peer.setValue(NSNumber(value: mode.rawValue), forKey: "listeningMode")
        return true
    }

    private static func peer(of device: IOBluetoothDevice) -> NSObject? {
        let selector = NSSelectorFromString("classicPeer")
        guard device.responds(to: selector) else { return nil }
        return device.perform(selector)?.takeUnretainedValue() as? NSObject
    }

    /// Key-value coding boxes the scalar getters; it raises for a missing key, so the selector is checked first.
    private static func number(_ object: NSObject, _ key: String) -> NSNumber? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        return object.value(forKey: key) as? NSNumber
    }
}

/// The glyphs the Sound menu shows beside each mode on macOS 27: three images of the private HeadphoneCommonUIKit framework, and a private SF Symbol for Adaptive. A missing one shows no glyph.
enum ListeningModeIcon {
    /// Drawn in black; the row draws them as templates in its grey.
    static let images: [ListeningMode: NSImage] = {
        var images: [ListeningMode: NSImage] = [:]
        let bundle = Bundle(path: "/System/Library/PrivateFrameworks/HeadphoneCommonUIKit.framework")
        for (mode, name) in [(ListeningMode.off, "Off"), (.transparency, "Transparency"), (.noiseCancellation, "Noise Cancellation")] {
            images[mode] = bundle?.image(forResource: name)
        }
        let privateSymbol = NSSelectorFromString("imageWithPrivateSystemSymbolName:")
        if NSImage.responds(to: privateSymbol) {
            images[.adaptive] = NSImage.perform(privateSymbol, with: "person.and.sparkles.fill")?.takeUnretainedValue() as? NSImage
        }
        return images
    }()
}
