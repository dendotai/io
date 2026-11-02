import AppKit
import CoreAudio
import Observation
import Priority

@Observable
final class AppModel {
    struct Row: Identifiable {
        let device: Device
        let isConnected: Bool
        let isInUse: Bool
        let canHide: Bool
        let symbolName: String
        var id: String { device.uid }
    }

    private(set) var rows: [Direction: [Row]] = [:]
    private(set) var inUseSymbolName = DeviceSymbol.speaker
    /// The volume of the output in use, or nil when it has no volume control.
    private(set) var volume: Float?
    /// The connected AirPods that "<name> Settings…" names, the pair in use first.
    private(set) var airPodsName: String?
    @ObservationIgnored private let switcher = Switcher(
        output: DeviceList(newDevices: .top, store: UserDefaultsStore(key: "outputList")),
        input: DeviceList(newDevices: .bottom, store: UserDefaultsStore(key: "inputList"))
    )
    @ObservationIgnored private var reported: [Direction: [AudioDevices.Reported]] = [:]
    @ObservationIgnored private let symbolStore = DeviceSymbolStore()
    @ObservationIgnored private lazy var symbols = symbolStore.load()
    @ObservationIgnored private var volumeOutputID: AudioDeviceID?
    @ObservationIgnored private var stopVolumeObservation: (() -> Void)?

    func start() {
        devicesChanged()
        AudioDevices.observe(
            onDevicesChange: { [weak self] in self?.devicesChanged() },
            onDefaultChange: { [weak self] in self?.defaultsChanged() }
        )
    }

    #if DEBUG
        func showDevicesWithoutSwitching() {
            readDevices()
            updateRows()
        }
    #endif

    func use(_ device: Device, in direction: Direction) {
        switcher.pick(device, in: direction)
        switchToChosenDevices()
    }

    func reorder(_ device: Device, to index: Int, in direction: Direction) {
        switcher.reorder(device, to: index, in: direction)
        switchToChosenDevices()
        updateRows()
    }

    func hide(_ device: Device, in direction: Direction) {
        switcher.hide(device, in: direction)
        updateRows()
    }

    func setVolume(_ volume: Float) {
        guard let volumeOutputID else { return }
        AudioDevices.setVolume(volume, volumeOutputID)
    }

    func openSoundSettings() {
        openSettings("com.apple.Sound-Settings.extension")
    }

    /// The URL takes no device, so the page opens on the AirPods System Settings picks.
    func openAirPodsSettings() {
        openSettings("com.apple.HeadphoneSettings")
    }

    private func openSettings(_ extensionID: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:\(extensionID)")!)
    }

    private func devicesChanged() {
        readDevices()
        for direction in Direction.allCases {
            let names = (reported[direction] ?? []).map(\.device.name).joined(separator: ", ")
            panelLog.notice("devices \(String(describing: direction), privacy: .public): \(names, privacy: .public)")
        }
        switchToChosenDevices()
        updateRows()
    }

    /// Reads the devices first, because Core Audio does not order the default and device-list notifications.
    private func defaultsChanged() {
        readDevices()
        switcher.defaultsChanged(inUse: inUse(), at: .now)
        switchToChosenDevices()
        updateRows()
    }

    private func readDevices() {
        for direction in Direction.allCases {
            reported[direction] = AudioDevices.devices(direction)
        }
        var symbols = self.symbols
        for device in reported.values.joined() {
            symbols[device.device.uid] = device.symbolName
        }
        if symbols != self.symbols {
            self.symbols = symbols
            symbolStore.save(symbols)
        }
        switcher.devicesChanged(
            connected: reported.mapValues { $0.map(\.device) },
            inUse: inUse(),
            at: .now
        )
    }

    private func inUse() -> [Direction: Device] {
        var inUse: [Direction: Device] = [:]
        for direction in Direction.allCases {
            let defaultID = AudioDevices.defaultDeviceID(direction)
            inUse[direction] = reported[direction]?.first { $0.id == defaultID }?.device
        }
        return inUse
    }

    private func switchToChosenDevices() {
        for direction in Direction.allCases {
            guard let chosen = switcher.chosenDevice(direction),
                let id = reported[direction]?.first(where: { $0.device.uid == chosen.uid })?.id,
                id != AudioDevices.defaultDeviceID(direction)
            else { continue }
            AudioDevices.setDefaultDevice(id, direction)
        }
    }

    private func updateRows() {
        for direction in Direction.allCases {
            let list = switcher.list(direction)
            let defaultID = AudioDevices.defaultDeviceID(direction)
            let inUse = reported[direction]?.first { $0.id == defaultID }
            if direction == .output {
                inUseSymbolName = inUse.map { DeviceSymbol.menuBarName($0.symbolName) } ?? DeviceSymbol.speaker
                observeVolume(of: inUse?.id)
            }
            rows[direction] = list.devices.map { device in
                Row(
                    device: device,
                    isConnected: list.connectedUIDs.contains(device.uid),
                    isInUse: device.uid == inUse?.device.uid,
                    canHide: list.canHide(device),
                    symbolName: symbols[device.uid] ?? DeviceSymbol.fallback(direction)
                )
            }
        }
        let connectedAirPods = (rows[.output] ?? []).filter { $0.isConnected && DeviceSymbol.isAirPods($0.symbolName) }
        airPodsName = (connectedAirPods.first(where: \.isInUse) ?? connectedAirPods.first)?.device.name
    }

    private func observeVolume(of outputID: AudioDeviceID?) {
        guard outputID != volumeOutputID else { return }
        stopVolumeObservation?()
        stopVolumeObservation = nil
        volumeOutputID = outputID
        if let outputID {
            stopVolumeObservation = AudioDevices.observeVolume(outputID) { [weak self] in
                guard let self, let volumeOutputID = self.volumeOutputID else { return }
                volume = AudioDevices.volume(volumeOutputID)
            }
        }
        volume = outputID.flatMap(AudioDevices.volume)
    }
}
