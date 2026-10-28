import CoreAudio

/// The SF Symbol the system Sound menu bar item shows for a device.
enum DeviceSymbol {
    static let speaker = "speaker.wave.2.fill"
    static let microphone = "mic.fill"

    /// Core Audio reports a Bluetooth device's model UID as "<product ID> <vendor ID>" in hex, such as "2027 4c".
    static func name(transportType: UInt32, modelUID: String?) -> String {
        guard transportType == kAudioDeviceTransportTypeBluetooth || transportType == kAudioDeviceTransportTypeBluetoothLE else {
            return speaker
        }
        let parts = modelUID?.split(separator: " ") ?? []
        guard parts.count == 2, parts[1].lowercased() == "4c", let productID = Int(parts[0], radix: 16) else {
            return "headphones"
        }
        return appleSymbols[productID] ?? "headphones"
    }

    /// Product IDs from https://theapplewiki.com/wiki/Bluetooth_PIDs; 0x2027 is the ID an AirPods Pro pair reports on macOS 27 and is not on that page yet.
    private static let appleSymbols: [Int: String] = [
        0x2002: "airpods", 0x200F: "airpods",
        0x2013: "airpods.gen3",
        0x201B: "airpods.gen4",
        0x200E: "airpods.pro", 0x2014: "airpods.pro", 0x2024: "airpods.pro", 0x2027: "airpods.pro",
        0x202B: "airpods.pro", 0x202C: "airpods.pro",
        0x200A: "airpods.max", 0x201F: "airpods.max", 0x202D: "airpods.max",
        0x200B: "beats.powerbeats.pro",
        0x2012: "beats.fitpro",
        0x2011: "beats.studiobuds", 0x2016: "beats.studiobuds",
        0x2006: "beats.headphones", 0x2009: "beats.headphones", 0x200C: "beats.headphones",
        0x2017: "beats.headphones", 0x2025: "beats.headphones",
    ]
}
