import Foundation

public enum Direction: CaseIterable, Sendable {
    case output
    case input
}

/// The Output list and the Input list, and which default changes are the user's picks.
/// macOS can make a device the default as it connects, and takes the AirPods microphone as the input when the output moves to the AirPods.
/// Neither is the user's choice, so a default change right after a connect or disconnect, or an input change right after an output change, is not a pick.
/// Any later default change is a pick in the system Sound menu and becomes the hand pick.
public final class Switcher {
    /// How long after a connect, a disconnect, or an output change a default change still counts as macOS's own switch.
    public static let macOSSwitchWindow: TimeInterval = 2

    private let lists: [Direction: DeviceList]
    private var devicesChangedAt = Date.distantPast
    private var outputChangedAt = Date.distantPast
    private var outputInUse: Device?

    public init(output: DeviceList, input: DeviceList) {
        lists = [.output: output, .input: input]
    }

    public func list(_ direction: Direction) -> DeviceList {
        lists[direction]!
    }

    public func chosenDevice(_ direction: Direction) -> Device? {
        list(direction).chosenDevice
    }

    /// Takes every device macOS reports as connected now, and the defaults in use.
    public func devicesChanged(connected: [Direction: [Device]], inUse: [Direction: Device], at now: Date) {
        for direction in Direction.allCases {
            if list(direction).update(connected: connected[direction] ?? [], inUse: inUse[direction]) {
                devicesChangedAt = now
            }
        }
        if outputInUse == nil {
            outputInUse = inUse[.output]
        }
    }

    /// Takes the defaults in use after macOS reported a change to one of them.
    public func defaultsChanged(inUse: [Direction: Device], at now: Date) {
        if inUse[.output] != outputInUse {
            outputInUse = inUse[.output]
            outputChangedAt = now
        }
        for direction in Direction.allCases {
            guard let device = inUse[direction], device.uid != chosenDevice(direction)?.uid else { continue }
            let switchedAt = direction == .input ? max(devicesChangedAt, outputChangedAt) : devicesChangedAt
            if now.timeIntervalSince(switchedAt) >= Self.macOSSwitchWindow {
                list(direction).pick(device)
            }
        }
    }

    public func pick(_ device: Device, in direction: Direction) {
        list(direction).pick(device)
    }

    public func reorder(_ device: Device, to index: Int, in direction: Direction) {
        list(direction).reorder(device, to: index)
    }

    public func hide(_ device: Device, in direction: Direction) {
        list(direction).hide(device)
    }
}
