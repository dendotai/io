import AudioToolbox
import CoreAudio
import Foundation

func addr(_ selector: AudioObjectPropertySelector,
          _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress
{
    .init(
        mSelector: selector,
        mScope: scope,
        mElement: 0
    )
}

let sys = AudioObjectID(kAudioObjectSystemObject)
var address = addr(kAudioHardwarePropertyDefaultOutputDevice); var def = AudioDeviceID(0); var size = UInt32(4)
AudioObjectGetPropertyData(sys, &address, 0, nil, &size, &def)
address = addr(kAudioHardwarePropertyDevices); AudioObjectGetPropertyDataSize(sys, &address, 0, nil, &size)
var ids = [AudioDeviceID](repeating: 0, count: Int(size) / 4); AudioObjectGetPropertyData(
    sys,
    &address,
    0,
    nil,
    &size,
    &ids
)
for id in ids {
    var streamsAddress = addr(kAudioDevicePropertyStreams,
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
    var nameAddress = addr(kAudioObjectPropertyName); var deviceName: CFString = "" as CFString; var nameSize =
        UInt32(MemoryLayout<CFString>
            .size); AudioObjectGetPropertyData(
            id,
            &nameAddress,
            0,
            nil,
            &nameSize,
            &deviceName
        )
    var transportAddress = addr(kAudioDevicePropertyTransportType); var transportType = UInt32(0); var valueSize =
        UInt32(4); AudioObjectGetPropertyData(
            id,
            &transportAddress,
            0,
            nil,
            &valueSize,
            &transportType
        )
    var runningAddress = addr(kAudioDevicePropertyDeviceIsRunningSomewhere); var run = UInt32(0); valueSize =
        4; AudioObjectGetPropertyData(
            id,
            &runningAddress,
            0,
            nil,
            &valueSize,
            &run
        )
    var volumeAddress = addr(
        kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        kAudioObjectPropertyScopeOutput
    ); var volumeSettable: DarwinBoolean = false
    let hasVolume = AudioObjectHasProperty(id, &volumeAddress); if hasVolume {
        AudioObjectIsPropertySettable(id, &volumeAddress, &volumeSettable)
    }
    var muteAddress = addr(kAudioDevicePropertyMute,
                           kAudioObjectPropertyScopeOutput); var muteSettable: DarwinBoolean = false
    let hasMute = AudioObjectHasProperty(id, &muteAddress); if hasMute {
        AudioObjectIsPropertySettable(id, &muteAddress, &muteSettable)
    }
    let transportCode = String(bytes: withUnsafeBytes(of: transportType.bigEndian, Array.init), encoding: .ascii) ?? "?"
    print(
        id == def ? "*" : " ",
        deviceName,
        "transport",
        transportCode,
        "running",
        run,
        "vol",
        hasVolume,
        volumeSettable.boolValue,
        "mute",
        hasMute,
        muteSettable.boolValue
    )
}
