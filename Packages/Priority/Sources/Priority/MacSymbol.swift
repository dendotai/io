/// The SF Symbol of a Mac, from the symbol names in `CoreTypes.bundle`, the system's list of device types; `docs/sound-menu.md` has the built-in device glyph read on one Mac, `macbook.gen2`.
public enum MacSymbol {
    /// A notched MacBook Pro also conforms to the notchless type through `com.apple.macbookpro`, so the notched type comes first.
    private static let symbols: [(typeIdentifier: String, symbol: String)] = [
        ("com.apple.mac.notched-laptop", "macbook.gen2"),
        ("com.apple.mac.notchless-laptop", "macbook.gen1"),
        ("com.apple.macmini", "macmini.gen2"),
        ("com.apple.macstudio", "macstudio"),
        ("com.apple.imac", "desktopcomputer"),
        ("com.apple.macpro", "macpro.gen3"),
    ]

    /// `modelCode` is the `hw.model` value, such as "MacBookPro18,1". A model the system does not list has no known type, so it gets the generic laptop.
    public static func of(modelCode: String) -> String {
        DeviceModelSymbol.of(modelCode: modelCode, symbols: symbols, fallback: "laptopcomputer")
    }
}
