import UniformTypeIdentifiers

/// The SF Symbol for a device's model code, from the device types in `CoreTypes.bundle`, the system's list of device types.
enum DeviceModelSymbol {
    /// `symbols` is in order, because a model can conform to more than one listed type; a model the system does not list gets `fallback`.
    static func of(modelCode: String, symbols: [(typeIdentifier: String, symbol: String)], fallback: String) -> String {
        guard let model = UTType(
            tag: modelCode,
            tagClass: UTTagClass(rawValue: "com.apple.device-model-code"),
            conformingTo: nil
        ) else {
            return fallback
        }
        let match = symbols.first { entry in
            UTType(entry.typeIdentifier).map(model.conforms(to:)) == true
        }
        return match?.symbol ?? fallback
    }
}
