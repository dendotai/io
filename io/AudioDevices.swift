import AudioToolbox
import CoreAudio
import IOKit.audio
import Priority

enum AudioDevices {
    struct Reported {
        let id: AudioDeviceID
        let device: Device
        let symbolName: String
    }

    private static let system = AudioObjectID(kAudioObjectSystemObject)

    static func devices(_ direction: Direction) -> [Reported] {
        var address = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            let transport = transportType(id)
            guard hasStreams(id, direction), !isHidden(id), !excludedTransports.contains(transport),
                let uid = string(id, kAudioDevicePropertyDeviceUID),
                let name = string(id, kAudioObjectPropertyName)
            else { return nil }
            let dataSource = uint32(id, kAudioDevicePropertyDataSource, scope: direction.streamScope)
            let isBuiltIn = transport == kAudioDeviceTransportTypeBuiltIn && dataSource.map(builtInDataSources.contains) == true
            let symbolName = DeviceSymbol.name(
                direction: direction, transportType: transport, isBuiltIn: isBuiltIn, name: name,
                modelUID: string(id, kAudioDevicePropertyModelUID))
            let device = Device(uid: uid, name: name, isBuiltIn: isBuiltIn)
            return Reported(id: id, device: device, symbolName: symbolName)
        }
    }

    static func defaultDeviceID(_ direction: Direction) -> AudioDeviceID? {
        var address = address(direction.defaultDeviceSelector)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &id) == noErr, id != kAudioObjectUnknown else {
            return nil
        }
        return id
    }

    static func setDefaultDevice(_ id: AudioDeviceID, _ direction: Direction) {
        var address = address(direction.defaultDeviceSelector)
        var id = id
        AudioObjectSetPropertyData(system, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
    }

    /// The volume the Sound menu slider shows, from 0 to 1, or nil for an output with no volume control.
    static func volume(_ id: AudioDeviceID) -> Float? {
        var address = volumeAddress
        guard AudioObjectHasProperty(id, &address) else { return nil }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(id, &address, &settable) == noErr, settable.boolValue else { return nil }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &volume) == noErr else { return nil }
        return volume
    }

    static func setVolume(_ volume: Float, _ id: AudioDeviceID) {
        var address = volumeAddress
        var volume = Float32(volume)
        AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume)
    }

    /// Returns the call that stops the observation, because the volume belongs to one device and the output in use changes.
    static func observeVolume(_ id: AudioDeviceID, onChange: @escaping @MainActor () -> Void) -> () -> Void {
        var address = volumeAddress
        let listener: AudioObjectPropertyListenerBlock = { _, _ in
            MainActor.assumeIsolated { onChange() }
        }
        AudioObjectAddPropertyListenerBlock(id, &address, .main, listener)
        return {
            var address = volumeAddress
            AudioObjectRemovePropertyListenerBlock(id, &address, .main, listener)
        }
    }

    /// The replacement for the `AudioHardwareService` volume calls, which the SDK marks as no longer supported.
    private static let volumeAddress = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioObjectPropertyScopeOutput)

    static func observe(onDevicesChange: @escaping @MainActor () -> Void, onDefaultChange: @escaping @MainActor () -> Void) {
        var devices = address(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(system, &devices, .main) { _, _ in
            MainActor.assumeIsolated { onDevicesChange() }
        }
        for direction in Direction.allCases {
            var defaultDevice = address(direction.defaultDeviceSelector)
            AudioObjectAddPropertyListenerBlock(system, &defaultDevice, .main) { _, _ in
                MainActor.assumeIsolated { onDefaultChange() }
            }
        }
    }

    private static let excludedTransports: Set<UInt32> = [
        kAudioDeviceTransportTypeVirtual,
        kAudioDeviceTransportTypeAggregate,
        kAudioDeviceTransportTypeAutoAggregate,
        kAudioDeviceTransportTypeAirPlay,
    ]

    /// The headphone jack's devices also report the built-in transport type; only the speakers and the microphone are always there.
    private static let builtInDataSources: Set<UInt32> = [
        UInt32(kIOAudioOutputPortSubTypeInternalSpeaker),
        UInt32(kIOAudioInputPortSubTypeInternalMicrophone),
    ]

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func hasStreams(_ id: AudioDeviceID, _ direction: Direction) -> Bool {
        var address = address(kAudioDevicePropertyStreams, scope: direction.streamScope)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func isHidden(_ id: AudioDeviceID) -> Bool {
        uint32(id, kAudioDevicePropertyIsHidden) == 1
    }

    private static func transportType(_ id: AudioDeviceID) -> UInt32 {
        uint32(id, kAudioDevicePropertyTransportType) ?? 0
    }

    private static func uint32(
        _ id: AudioDeviceID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> UInt32? {
        var address = address(selector, scope: scope)
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

extension Direction {
    fileprivate var streamScope: AudioObjectPropertyScope {
        self == .output ? kAudioObjectPropertyScopeOutput : kAudioObjectPropertyScopeInput
    }

    fileprivate var defaultDeviceSelector: AudioObjectPropertySelector {
        self == .output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice
    }
}
