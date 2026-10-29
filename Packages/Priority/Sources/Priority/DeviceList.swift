import Foundation

public struct Device: Codable, Equatable, Hashable, Sendable {
    /// The Core Audio device UID, which stays the same across reconnects.
    public let uid: String
    public var name: String
    /// Saved because macOS stops reporting a device's transport type once it disconnects.
    public var isBuiltIn: Bool

    public init(uid: String, name: String, isBuiltIn: Bool = false) {
        self.uid = uid
        self.name = name
        self.isBuiltIn = isBuiltIn
    }

    /// Lists saved before `isBuiltIn` existed lack the key; a device's next connect sets it.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(String.self, forKey: .uid)
        name = try container.decode(String.self, forKey: .name)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }
}

public protocol DeviceListStore {
    func load() -> [Device]
    func save(_ devices: [Device])
}

/// Where a device the list has never seen goes.
public enum NewDevicePlacement: Sendable {
    case top
    case bottom
}

/// The remembered devices of the Output list or the Input list in priority order, and the device the app uses.
public final class DeviceList {
    public private(set) var devices: [Device]
    public private(set) var connectedUIDs: Set<String> = []
    private var handPickUID: String?
    private let newDevicePlacement: NewDevicePlacement
    private let store: DeviceListStore

    public init(newDevices: NewDevicePlacement, store: DeviceListStore) {
        self.newDevicePlacement = newDevices
        self.store = store
        devices = store.load()
    }

    /// The hand pick while it holds, else the highest connected device.
    public var chosenDevice: Device? {
        if let handPickUID, let device = devices.first(where: { $0.uid == handPickUID }) {
            return device
        }
        return devices.first { connectedUIDs.contains($0.uid) }
    }

    /// Takes every device macOS reports as connected now. The hand pick ends when the picked device disconnects or a device above it connects.
    /// Returns true when a device connected or disconnected.
    /// When the list is empty, `inUse` goes first, so the first launch keeps the device macOS uses now.
    @discardableResult
    public func update(connected: [Device], inUse: Device? = nil) -> Bool {
        let wasEmpty = devices.isEmpty
        let uids = Set(connected.map(\.uid))
        let changed = uids != connectedUIDs
        let newlyConnectedUIDs = uids.subtracting(connectedUIDs)
        connectedUIDs = uids

        var newDevices: [Device] = []
        for device in connected {
            if let index = devices.firstIndex(where: { $0.uid == device.uid }) {
                devices[index].name = device.name
                devices[index].isBuiltIn = device.isBuiltIn
            } else {
                newDevices.append(device)
            }
        }
        switch newDevicePlacement {
        case .top: devices.insert(contentsOf: newDevices, at: 0)
        case .bottom: devices.append(contentsOf: newDevices)
        }
        if wasEmpty, let inUse, let index = devices.firstIndex(where: { $0.uid == inUse.uid }) {
            devices.insert(devices.remove(at: index), at: 0)
        }
        if let handPickUID, endsHandPick(handPickUID, newlyConnectedUIDs: newlyConnectedUIDs) {
            self.handPickUID = nil
        }
        store.save(devices)
        return changed
    }

    /// Places the device at `index` among every remembered device, connected or not.
    /// The device in use stays in use as the hand pick, so a reorder never switches devices.
    public func reorder(_ device: Device, to index: Int) {
        guard let from = devices.firstIndex(where: { $0.uid == device.uid }) else { return }
        let inUse = chosenDevice
        let moved = devices.remove(at: from)
        devices.insert(moved, at: min(max(index, 0), devices.count))
        if let inUse, inUse.uid != chosenDevice?.uid {
            handPickUID = inUse.uid
        }
        store.save(devices)
    }

    public func canHide(_ device: Device) -> Bool {
        guard let remembered = devices.first(where: { $0.uid == device.uid }) else { return false }
        return !remembered.isBuiltIn && !connectedUIDs.contains(device.uid)
    }

    /// Removes the device, so its next connect places it as a new device.
    public func hide(_ device: Device) {
        guard canHide(device) else { return }
        devices.removeAll { $0.uid == device.uid }
        store.save(devices)
    }

    private func endsHandPick(_ uid: String, newlyConnectedUIDs: Set<String>) -> Bool {
        guard connectedUIDs.contains(uid) else { return true }
        return devices.prefix { $0.uid != uid }.contains { newlyConnectedUIDs.contains($0.uid) }
    }

    public func pick(_ device: Device) {
        guard connectedUIDs.contains(device.uid) else { return }
        handPickUID = device.uid
    }
}

public struct UserDefaultsStore: DeviceListStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [Device] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Device].self, from: data)) ?? []
    }

    public func save(_ devices: [Device]) {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: key)
    }
}
