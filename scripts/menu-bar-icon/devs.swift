import CoreAudio
import AudioToolbox
import Foundation
func addr(_ s: AudioObjectPropertySelector, _ sc: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress { .init(mSelector: s, mScope: sc, mElement: 0) }
let sys = AudioObjectID(kAudioObjectSystemObject)
var a = addr(kAudioHardwarePropertyDefaultOutputDevice); var def = AudioDeviceID(0); var sz = UInt32(4)
AudioObjectGetPropertyData(sys, &a, 0, nil, &sz, &def)
a = addr(kAudioHardwarePropertyDevices); AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &sz)
var ids = [AudioDeviceID](repeating: 0, count: Int(sz)/4); AudioObjectGetPropertyData(sys, &a, 0, nil, &sz, &ids)
for id in ids {
  var n = addr(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput); var s2 = UInt32(0); AudioObjectGetPropertyDataSize(id, &n, 0, nil, &s2); if s2 == 0 { continue }
  var na = addr(kAudioObjectPropertyName); var cf: CFString = "" as CFString; var s3 = UInt32(MemoryLayout<CFString>.size); AudioObjectGetPropertyData(id, &na, 0, nil, &s3, &cf)
  var t = addr(kAudioDevicePropertyTransportType); var tt = UInt32(0); var s4 = UInt32(4); AudioObjectGetPropertyData(id, &t, 0, nil, &s4, &tt)
  var r = addr(kAudioDevicePropertyDeviceIsRunningSomewhere); var run = UInt32(0); s4 = 4; AudioObjectGetPropertyData(id, &r, 0, nil, &s4, &run)
  var v = addr(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput); var st: DarwinBoolean = false
  let hv = AudioObjectHasProperty(id, &v); if hv { AudioObjectIsPropertySettable(id, &v, &st) }
  var m = addr(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput); var mst: DarwinBoolean = false
  let hm = AudioObjectHasProperty(id, &m); if hm { AudioObjectIsPropertySettable(id, &m, &mst) }
  let tc = String(bytes: withUnsafeBytes(of: tt.bigEndian, Array.init), encoding: .ascii) ?? "?"
  print(id == def ? "*" : " ", cf, "transport", tc, "running", run, "vol", hv, st.boolValue, "mute", hm, mst.boolValue)
}
