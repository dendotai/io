import AudioToolbox
import CoreAudio
import Foundation

func propertyAddress(_ selector: AudioObjectPropertySelector,
                     _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress
{
    .init(
        mSelector: selector,
        mScope: scope,
        mElement: 0
    )
}

let systemObject = AudioObjectID(kAudioObjectSystemObject)
var address = propertyAddress(kAudioHardwarePropertyDefaultOutputDevice); var defaultOutputID =
    AudioDeviceID(0); var size = UInt32(4)
AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &defaultOutputID)
address = propertyAddress(kAudioHardwarePropertyDevices); AudioObjectGetPropertyDataSize(
    systemObject,
    &address,
    0,
    nil,
    &size
)
var ids = [AudioDeviceID](repeating: 0, count: Int(size) / 4); AudioObjectGetPropertyData(
    systemObject,
    &address,
    0,
    nil,
    &size,
    &ids
)
for id in ids {
    var streamsAddress = propertyAddress(kAudioDevicePropertyStreams,
                                         kAudioObjectPropertyScopeOutput); var streamsSize =
        UInt32(0); AudioObjectGetPropertyDataSize(
            id,
            &streamsAddress,
            0,
            nil,
            &streamsSize
        ); if streamsSize == 0
    {
        continue
    }
    var nameAddress = propertyAddress(kAudioObjectPropertyName); var deviceName: CFString =
        "" as CFString; var nameSize =
        UInt32(MemoryLayout<CFString>
            .size); AudioObjectGetPropertyData(
            id,
            &nameAddress,
            0,
            nil,
            &nameSize,
            &deviceName
        )
    var transportAddress = propertyAddress(kAudioDevicePropertyTransportType); var transportType =
        UInt32(0); var valueSize =
        UInt32(4); AudioObjectGetPropertyData(
            id,
            &transportAddress,
            0,
            nil,
            &valueSize,
            &transportType
        )
    var runningAddress = propertyAddress(kAudioDevicePropertyDeviceIsRunningSomewhere); var isRunning =
        UInt32(0); valueSize =
        4; AudioObjectGetPropertyData(
            id,
            &runningAddress,
            0,
            nil,
            &valueSize,
            &isRunning
        )
    var volumeAddress = propertyAddress(
        kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        kAudioObjectPropertyScopeOutput
    ); var volumeSettable: DarwinBoolean = false
    let hasVolume = AudioObjectHasProperty(id, &volumeAddress); if hasVolume {
        AudioObjectIsPropertySettable(id, &volumeAddress, &volumeSettable)
    }
    var muteAddress = propertyAddress(kAudioDevicePropertyMute,
                                      kAudioObjectPropertyScopeOutput); var muteSettable: DarwinBoolean = false
    let hasMute = AudioObjectHasProperty(id, &muteAddress); if hasMute {
        AudioObjectIsPropertySettable(id, &muteAddress, &muteSettable)
    }
    let transportCode = String(bytes: withUnsafeBytes(of: transportType.bigEndian, Array.init), encoding: .ascii) ?? "?"
    print(
        id == defaultOutputID ? "*" : " ",
        deviceName,
        "transport",
        transportCode,
        "running",
        isRunning,
        "vol",
        hasVolume,
        volumeSettable.boolValue,
        "mute",
        hasMute,
        muteSettable.boolValue
    )
}
