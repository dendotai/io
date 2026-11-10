/// What the menu bar icon shows. The Sound icon animates a new symbol for another output differently from a new symbol within one output, so the icon keeps the output it stands for.
public struct MenuBarIcon: Equatable, Sendable {
    public enum Change: Equatable, Sendable {
        case output
        case symbol
        /// Only the filled waves change, also between two outputs, as in the Sound icon.
        case volume
    }

    public let outputUID: String?
    public let symbol: MenuBarSymbol

    public init(outputUID: String?, symbol: MenuBarSymbol) {
        self.outputUID = outputUID
        self.symbol = symbol
    }

    /// nil when the icon stays as it is.
    public func change(from old: MenuBarIcon) -> Change? {
        if symbol == old.symbol {
            return nil
        }
        if symbol.name == old.symbol.name {
            return .volume
        }
        return outputUID == old.outputUID ? .symbol : .output
    }
}
