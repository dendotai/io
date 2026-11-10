public enum Direction: CaseIterable, Sendable {
    case output
    case input
}

/// A hand pick comes only from the panel, so a default change by another process never changes the chosen device.
public final class Switcher {
    private let output: DeviceList
    private let input: DeviceList

    public init(output: DeviceList, input: DeviceList) {
        self.output = output
        self.input = input
    }

    public func list(_ direction: Direction) -> DeviceList {
        switch direction {
        case .output: output
        case .input: input
        }
    }

    public func chosenDevice(_ direction: Direction) -> Device? {
        list(direction).chosenDevice
    }

    /// Takes every device macOS reports as connected now, and the defaults in use.
    public func devicesChanged(connected: [Direction: [Device]], inUse: [Direction: Device]) {
        for direction in Direction.allCases {
            list(direction).update(connected: connected[direction] ?? [], inUse: inUse[direction])
        }
    }

    public func pick(_ device: Device, in direction: Direction) {
        list(direction).pick(device)
    }

    public func endHandPick(in direction: Direction) {
        list(direction).endHandPick()
    }

    public func reorder(_ device: Device, to index: Int, in direction: Direction) {
        list(direction).reorder(device, to: index)
    }

    public func hide(_ device: Device, in direction: Direction) {
        list(direction).hide(device)
    }
}
