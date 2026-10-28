import CoreAudio
import Observation
import Priority

@Observable
final class AppModel {
    struct Row: Identifiable {
        let device: Device
        let isConnected: Bool
        let isInUse: Bool
        var id: String { device.uid }
    }

    private(set) var rows: [Row] = []
    private(set) var inUseSymbolName = DeviceSymbol.speaker
    @ObservationIgnored private let outputList = OutputList(store: UserDefaultsStore())
    @ObservationIgnored private var reported: [AudioDevices.Reported] = []

    func start() {
        refresh(switching: true)
        AudioDevices.observe(
            onDevicesChange: { [weak self] in self?.refresh(switching: false) },
            onDefaultChange: { [weak self] in self?.updateRows() }
        )
    }

    func use(_ device: Device) {
        outputList.pick(device)
        switchToChosenDevice()
    }

    /// Switches only when a device connected or disconnected, or at launch, so a pick made in the system Sound menu stays.
    private func refresh(switching force: Bool) {
        reported = AudioDevices.outputDevices()
        let changed = outputList.update(connected: reported.map(\.device))
        if changed || force {
            switchToChosenDevice()
        }
        updateRows()
    }

    private func switchToChosenDevice() {
        guard let chosen = outputList.chosenDevice,
            let id = reported.first(where: { $0.device.uid == chosen.uid })?.id,
            id != AudioDevices.defaultOutputID()
        else { return }
        AudioDevices.setDefaultOutput(id)
    }

    private func updateRows() {
        let defaultID = AudioDevices.defaultOutputID()
        let inUse = reported.first { $0.id == defaultID }
        let inUseUID = inUse?.device.uid
        inUseSymbolName = inUse?.symbolName ?? DeviceSymbol.speaker
        rows = outputList.devices.map { device in
            Row(
                device: device,
                isConnected: outputList.connectedUIDs.contains(device.uid),
                isInUse: device.uid == inUseUID
            )
        }
    }
}
