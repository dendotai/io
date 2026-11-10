/// The SF Symbol of the menu bar icon, with the Sound icon's values from the Menu bar icon table in `docs/sound-menu.md`.
public struct MenuBarSymbol: Equatable, Sendable {
    public let name: String
    /// How many of the symbol's waves are filled; a symbol with no variable layers ignores it.
    public let variableValue: Double

    public init(name: String, variableValue: Double = 1) {
        self.name = name
        self.variableValue = variableValue
    }

    /// AirPods and Beats show the model's own symbol in every state.
    public static func isModelSymbol(_ symbolName: String) -> Bool {
        ["airpods", "beats"].contains(where: symbolName.hasPrefix)
    }

    /// `volume` is from 0 to 1, or nil for an output with no volume control, which has no state to show.
    public static func of(deviceSymbol: String, volume: Float?, isMuted: Bool) -> MenuBarSymbol {
        if isModelSymbol(deviceSymbol) {
            return MenuBarSymbol(name: deviceSymbol)
        }
        let hasHeadphones = deviceSymbol.hasPrefix("headphones")
        guard let volume else {
            return MenuBarSymbol(name: hasHeadphones ? deviceSymbol : "speaker.wave.3.fill")
        }
        let percent = Int((volume * 100).rounded())
        if isMuted || percent == 0 {
            return MenuBarSymbol(name: hasHeadphones ? "headphones.slash" : "speaker.slash.fill")
        }
        if hasHeadphones {
            return MenuBarSymbol(name: deviceSymbol)
        }
        let waveValue = switch percent {
        case ...33: 0.01
        case ...66: 0.34
        default: 1.0
        }
        return MenuBarSymbol(name: "speaker.wave.3.fill", variableValue: waveValue)
    }
}
