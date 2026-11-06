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
        let batteryLevels: BatteryLevels?
        /// nil when the row has no ⌄: not connected AirPods with noise cancellation, or the setting stopped answering.
        let listening: AirPodsListeningMode.State?
        let isFoldedOpen: Bool
        var id: String { device.uid }
    }

    private(set) var rows: [Direction: [Row]] = [:]
    private(set) var canEndHandPick: [Direction: Bool] = [:]
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
    /// Read when a device or a power source changes, so opening the panel reads nothing.
    @ObservationIgnored private var batteryLevelsByName: [String: BatteryLevels] = [:]
    @ObservationIgnored private var listeningModesByAddress: [String: AirPodsListeningMode.State] = [:]
    /// False once the private setting is missing or a set does not read back within 4 s; the ⌄ stays hidden until the app restarts.
    @ObservationIgnored private var listeningModeAnswers = false
    /// Only the newest set of a pair is read back, so two quick clicks do not read each other's mode.
    @ObservationIgnored private var lastSetModeByAddress: [String: ListeningMode] = [:]
    @ObservationIgnored private var foldedOpenUIDs: Set<String> = []
    @ObservationIgnored private let symbolStore = DeviceSymbolStore()
    @ObservationIgnored private lazy var symbols = symbolStore.load()
    @ObservationIgnored private var volumeOutputID: AudioDeviceID?
    @ObservationIgnored private var stopVolumeObservation: (() -> Void)?

    func start() {
        listeningModeAnswers = AirPodsListeningMode.start()
        devicesChanged()
        AudioDevices.observe(
            onDevicesChange: { [weak self] in self?.devicesChanged() },
            onDefaultChange: { [weak self] in self?.defaultsChanged() }
        )
        AirPodsBattery.observe { [weak self] in
            guard let self else { return }
            batteryLevelsByName = AirPodsBattery.levels()
            updateRows()
        }
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
        updateRows()
    }

    func endHandPick(in direction: Direction) {
        switcher.endHandPick(in: direction)
        switchToChosenDevices()
        updateRows()
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

    /// The mode can change on the AirPods themselves, and macOS posts no notification for it.
    func panelWillOpen() {
        readListeningModes()
        updateRows()
    }

    func toggleListeningModes(of device: Device) {
        if !foldedOpenUIDs.insert(device.uid).inserted {
            foldedOpenUIDs.remove(device.uid)
        }
        updateRows()
    }

    func setListeningMode(_ mode: ListeningMode, of device: Device) {
        let address = AirPodsListeningMode.address(of: device)
        guard let state = listeningModesByAddress[address] else { return }
        guard AirPodsListeningMode.set(mode, address: address) else {
            stopListeningModes()
            return
        }
        listeningModesByAddress[address] = AirPodsListeningMode.State(supported: state.supported, current: mode)
        lastSetModeByAddress[address] = mode
        updateRows()
        // On macOS 27 the AirPods apply sets one at a time: after two sets 200 ms apart, the peer reports the first at 0.8 s and the second at 3 s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, listeningModeAnswers, lastSetModeByAddress[address] == mode else { return }
            lastSetModeByAddress[address] = nil
            readListeningModes()
            let current = listeningModesByAddress[address]?.current
            // A pair that disconnected within the second has no mode to read back.
            if current != mode && AirPodsListeningMode.isConnected(address: address) {
                panelLog.notice("listening mode set to \(mode.rawValue) reads back \(current.map { "\($0.rawValue)" } ?? "nothing")")
                stopListeningModes()
            } else {
                updateRows()
            }
        }
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
            panelLog.notice("devices \(String(describing: direction)): \(names)")
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
        batteryLevelsByName = AirPodsBattery.levels()
        readListeningModes()
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

    /// A pair with a set not yet read back shows the mode set, not the earlier mode the AirPods still report.
    private func readListeningModes() {
        listeningModesByAddress = listeningModeAnswers ? AirPodsListeningMode.states() : [:]
        for (address, mode) in lastSetModeByAddress {
            if let state = listeningModesByAddress[address] {
                listeningModesByAddress[address] = AirPodsListeningMode.State(supported: state.supported, current: mode)
            }
        }
    }

    private func stopListeningModes() {
        listeningModeAnswers = false
        listeningModesByAddress = [:]
        updateRows()
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
            canEndHandPick[direction] = list.canEndHandPick
            let defaultID = AudioDevices.defaultDeviceID(direction)
            let inUse = reported[direction]?.first { $0.id == defaultID }
            if direction == .output {
                inUseSymbolName = inUse.map { DeviceSymbol.menuBarName($0.symbolName) } ?? DeviceSymbol.speaker
                observeVolume(of: inUse?.id)
            }
            rows[direction] = list.devices.map { device in
                let isConnected = list.connectedUIDs.contains(device.uid)
                let isConnectedOutput = isConnected && direction == .output
                let listening = isConnectedOutput ? listeningModesByAddress[AirPodsListeningMode.address(of: device)] : nil
                return Row(
                    device: device,
                    isConnected: isConnected,
                    isInUse: device.uid == inUse?.device.uid,
                    canHide: list.canHide(device),
                    symbolName: symbols[device.uid] ?? DeviceSymbol.fallback(direction),
                    batteryLevels: isConnectedOutput ? batteryLevelsByName[device.name] : nil,
                    listening: listening,
                    isFoldedOpen: listening != nil && foldedOpenUIDs.contains(device.uid)
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
