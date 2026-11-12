import Priority

extension AppModel {
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
        /// False for the AirPlay row, which is never lifted and which a dragged row never passes.
        var canReorder = true
        var id: String {
            device.uid
        }

        /// The AirPlay pick's row, in use at the top of the Output list until the pick ends.
        static func airPlay(_ device: Device, symbolName: String) -> Row {
            Row(
                device: device, isConnected: true, isInUse: true, canHide: false, symbolName: symbolName,
                batteryLevels: nil, listening: nil, isFoldedOpen: false, canReorder: false
            )
        }
    }
}
