/// The SF Symbol of an iPhone's generation, from the device types in `CoreTypes.bundle`, as `MacSymbol` does for a Mac.
public enum IPhoneSymbol {
    /// A Dynamic Island iPhone also conforms to the home-button-less type, so the Dynamic Island type comes first.
    private static let symbols: [(typeIdentifier: String, symbol: String)] = [
        ("com.apple.dynamic-island-iphone", "iphone.gen3"),
        ("com.apple.homebuttonless-iphone", "iphone.gen2"),
        ("com.apple.iphone", "iphone.gen1"),
    ]

    /// `modelCode` is an iPhone's model identifier, such as "iPhone18,2". A model the system does not list gets the generic iPhone.
    public static func of(modelCode: String) -> String {
        DeviceModelSymbol.of(modelCode: modelCode, symbols: symbols, fallback: "iphone")
    }

    /// Core Audio reports only "iPhone Mic" as an iPhone microphone's model, so the model comes from the same iPhone's Continuity Camera device.
    /// On macOS 27 the camera's unique ID is the microphone's UID with its last digit 1 in place of 3.
    public static func modelCode(ofMicrophone uid: String, cameras: [(uid: String, modelCode: String)]) -> String? {
        guard uid.hasSuffix("3") else { return nil }
        return cameras.first { $0.uid == uid.dropLast() + "1" }?.modelCode
    }
}
