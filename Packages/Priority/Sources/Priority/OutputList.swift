import Foundation

public struct Device: Codable, Equatable, Hashable, Sendable {
    /// The Core Audio device UID, which stays the same across reconnects.
    public let uid: String
    public var name: String

    public init(uid: String, name: String) {
        self.uid = uid
        self.name = name
    }
}

public protocol OutputListStore {
    func load() -> [Device]
    func save(_ devices: [Device])
}

/// The remembered output devices in priority order, and the device the app uses.
public final class OutputList {
    public private(set) var devices: [Device]
    public private(set) var connectedUIDs: Set<String> = []
    private var handPickUID: String?
    private let store: OutputListStore

    public init(store: OutputListStore) {
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

    /// Takes every device macOS reports as connected now. A change in the connected set ends the hand pick.
    /// Returns true when a device connected or disconnected.
    @discardableResult
    public func update(connected: [Device]) -> Bool {
        let uids = Set(connected.map(\.uid))
        let changed = uids != connectedUIDs
        if changed {
            handPickUID = nil
        }
        connectedUIDs = uids

        var newDevices: [Device] = []
        for device in connected {
            if let index = devices.firstIndex(where: { $0.uid == device.uid }) {
                devices[index].name = device.name
            } else {
                newDevices.append(device)
            }
        }
        devices.insert(contentsOf: newDevices, at: 0)
        store.save(devices)
        return changed
    }

    /// Places the device at `index` among every remembered device, connected or not, and ends the hand pick.
    public func reorder(_ device: Device, to index: Int) {
        guard let from = devices.firstIndex(where: { $0.uid == device.uid }) else { return }
        let moved = devices.remove(at: from)
        devices.insert(moved, at: min(max(index, 0), devices.count))
        handPickUID = nil
        store.save(devices)
    }

    public func pick(_ device: Device) {
        guard connectedUIDs.contains(device.uid) else { return }
        handPickUID = device.uid
    }
}

public struct UserDefaultsStore: OutputListStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "outputList") {
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
