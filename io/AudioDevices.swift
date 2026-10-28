import CoreAudio
import Priority

enum AudioDevices {
    struct Reported {
        let id: AudioDeviceID
        let device: Device
        let symbolName: String
    }

    private static let system = AudioObjectID(kAudioObjectSystemObject)

    static func outputDevices() -> [Reported] {
        var address = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            let transport = transportType(id)
            guard hasOutputStreams(id), !isHidden(id), !excludedTransports.contains(transport),
                let uid = string(id, kAudioDevicePropertyDeviceUID),
                let name = string(id, kAudioObjectPropertyName)
            else { return nil }
            let symbolName = DeviceSymbol.name(transportType: transport, modelUID: string(id, kAudioDevicePropertyModelUID))
            return Reported(id: id, device: Device(uid: uid, name: name), symbolName: symbolName)
        }
    }

    static func defaultOutputID() -> AudioDeviceID? {
        var address = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &id) == noErr, id != kAudioObjectUnknown else {
            return nil
        }
        return id
    }

    static func setDefaultOutput(_ id: AudioDeviceID) {
        var address = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = id
        AudioObjectSetPropertyData(system, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
    }

    static func observe(onDevicesChange: @escaping @MainActor () -> Void, onDefaultChange: @escaping @MainActor () -> Void) {
        var devices = address(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(system, &devices, .main) { _, _ in
            MainActor.assumeIsolated { onDevicesChange() }
        }
        var defaultOutput = address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(system, &defaultOutput, .main) { _, _ in
            MainActor.assumeIsolated { onDefaultChange() }
        }
    }

    private static let excludedTransports: Set<UInt32> = [
        kAudioDeviceTransportTypeVirtual,
        kAudioDeviceTransportTypeAggregate,
        kAudioDeviceTransportTypeAutoAggregate,
        kAudioDeviceTransportTypeAirPlay,
    ]

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var address = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func isHidden(_ id: AudioDeviceID) -> Bool {
        uint32(id, kAudioDevicePropertyIsHidden) == 1
    }

    private static func transportType(_ id: AudioDeviceID) -> UInt32 {
        uint32(id, kAudioDevicePropertyTransportType) ?? 0
    }

    private static func uint32(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var address = address(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func string(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}
