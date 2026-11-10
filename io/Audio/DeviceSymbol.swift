import AppKit
import CoreAudio
import Priority

/// The SF Symbol the system Sound menu shows for a device.
enum DeviceSymbol {
    static let speaker = "speaker.wave.2.fill"
    static let microphone = "mic.fill"
    private static let builtInDevice = MacSymbol.of(modelCode: modelCode())

    static func fallback(_ direction: Direction) -> String {
        direction == .output ? speaker : microphone
    }

    /// Core Audio reports a Bluetooth device's model UID as "<product ID> <vendor ID>" in hex, such as "2027 4c".
    /// The headphone jack's devices report the built-in transport too, so `isBuiltIn` tells the Mac's own speakers and microphone apart from them.
    static func name(direction: Direction, transportType: UInt32, isBuiltIn: Bool, name: String,
                     modelUID: String?) -> String
    {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            // The Sound menu shows a laptop for "External Microphone"; io shows the `headphones` of its "External Headphones" instead.
            return isBuiltIn ? builtInDevice : "headphones"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "display"
        case kAudioDeviceTransportTypeUSB, kAudioDeviceTransportTypeThunderbolt:
            // Studio Display reports USB, and only its name tells it from other USB audio.
            return name.localizedCaseInsensitiveContains("Display") ? "display" : fallback(direction)
        case kAudioDeviceTransportTypeContinuityCaptureWired, kAudioDeviceTransportTypeContinuityCaptureWireless:
            return "iphone"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            let parts = modelUID?.split(separator: " ") ?? []
            guard parts.count == 2, parts[1].lowercased() == "4c", let productID = Int(parts[0], radix: 16) else {
                return "headphones"
            }
            return appleSymbols[productID] ?? "headphones"
        default:
            return fallback(direction)
        }
    }

    private static func modelCode() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [UInt8](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        // `hw.model` is ASCII; an empty code gets the generic laptop, as an unknown model does.
        return String(bytes: model.dropLast(), encoding: .utf8) ?? ""
    }

    /// AirPods cases are named "<buds>.chargingcase.wireless.fill" and Beats cases "<buds>.chargingcase.fill"; buds with no case symbol of their own get the AirPods one.
    static func chargingCase(of symbolName: String) -> String {
        firstExisting([
            "\(symbolName).chargingcase.wireless.fill",
            "\(symbolName).chargingcase.fill",
        ]) ?? "airpods.chargingcase.wireless.fill"
    }

    /// One bud of a pair, such as "airpods.pro.gen3.left"; AirPods 3 name theirs in the singular, "airpod.gen3.left", and a pair with no bud symbols of its own gets the generic bud.
    static func bud(of symbolName: String, side: String) -> String {
        let singular = symbolName.replacingOccurrences(of: "airpods.", with: "airpod.")
        return firstExisting(["\(symbolName).\(side)", "\(singular).\(side)"]) ?? "airpod.\(side)"
    }

    private static func firstExisting(_ names: [String]) -> String? {
        names.first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }
    }

    static func isAirPods(_ symbolName: String) -> Bool {
        symbolName.hasPrefix("airpods")
    }

    /// Product IDs from https://theapplewiki.com/wiki/Bluetooth_PIDs; 0x2027 is the ID an AirPods Pro 3 pair reports on macOS 27 and is not on that page yet.
    private static let appleSymbols: [Int: String] = [
        0x2002: "airpods", 0x200F: "airpods",
        0x2013: "airpods.gen3",
        0x201B: "airpods.gen4",
        0x200E: "airpods.pro.gen1",
        0x2014: "airpods.pro", 0x2024: "airpods.pro", 0x202B: "airpods.pro", 0x202C: "airpods.pro",
        0x2027: "airpods.pro.gen3",
        0x200A: "airpods.max", 0x201F: "airpods.max", 0x202D: "airpods.max",
        0x200B: "beats.powerbeats.pro",
        0x2012: "beats.fitpro",
        0x2011: "beats.studiobuds", 0x2016: "beats.studiobuds",
        0x2006: "beats.headphones", 0x2009: "beats.headphones", 0x200C: "beats.headphones",
        0x2017: "beats.headphones", 0x2025: "beats.headphones",
    ]
}

/// Each device's symbol by UID, because macOS stops reporting a device's transport type and model once it disconnects.
struct DeviceSymbolStore {
    private let key = "deviceSymbols"

    func load() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    func save(_ symbols: [String: String]) {
        UserDefaults.standard.set(symbols, forKey: key)
    }
}
