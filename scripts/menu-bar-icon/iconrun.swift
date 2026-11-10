import AppKit
import ApplicationServices
import AudioToolbox
import CoreAudio

// iconrun <record path> <outdir> [dry|-] <io.app path>: opens the Sound menu by an Accessibility press, records the menu bar strip around io's icon and the Sound icon at 120 fps, changes the output through the Sound menu's rows and the volume and mute through Core Audio, then closes the panel and restores the volume and mute it read first. "dry" only opens the panel, records one second, lists its rows, and closes it.
let args = CommandLine.arguments
let dry = args.count > 3 && args[3] == "dry"

func attr<T>(_ e: AXUIElement, _ name: String) -> T? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v as? T : nil
}

func children(_ e: AXUIElement) -> [AXUIElement] {
    attr(e, kAXChildrenAttribute) ?? []
}

func label(_ e: AXUIElement) -> String {
    [
        attr(e, kAXTitleAttribute) as String?,
        attr(e, kAXDescriptionAttribute) as String?,
        attr(e, kAXValueAttribute) as String?,
    ]
    .compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " | ")
}

func text(_ e: AXUIElement, depth: Int = 0) -> String {
    depth > 8 ? "" : ([label(e)] + children(e).map { text($0, depth: depth + 1) }).filter { !$0.isEmpty }
        .joined(separator: " | ")
}

func buttons(_ e: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 30 else { return [] }
    let own: [AXUIElement] = (attr(e, kAXRoleAttribute) as String?) == kAXButtonRole ? [e] : []
    return own + children(e).flatMap { buttons($0, depth: depth + 1) }
}

func identifier(_ e: AXUIElement) -> String {
    attr(e, kAXIdentifierAttribute) ?? ""
}

func find(_ e: AXUIElement, depth: Int = 0, _ match: (AXUIElement) -> Bool) -> [AXUIElement] {
    guard depth < 30 else { return [] }
    return (match(e) ? [e] : []) + children(e).flatMap { find($0, depth: depth + 1, match) }
}

func element(_ bundle: String) -> AXUIElement {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first
    else { fatalError("\(bundle) is not running") }
    return AXUIElementCreateApplication(app.processIdentifier)
}

/// The Sound item's open menu shows the menu bar over a full-screen app; io's panel does not.
let agent = element("com.apple.MenuBarAgent")
guard let soundItem = find(agent, { identifier($0) == "com.apple.menuextra.sound" }).last
else { fatalError("no Sound item") }
let controlCenter = element("com.apple.controlcenter")
func rows() -> [AXUIElement] {
    find(controlCenter) { identifier($0).hasPrefix("sound-device-") }
}

func openPanel() {
    if !rows().isEmpty {
        return
    }
    AXUIElementPerformAction(soundItem, kAXPressAction as CFString)
    for _ in 0 ..< 20 where rows().isEmpty {
        usleep(100_000)
    }
    guard !rows().isEmpty else { fatalError("the Sound menu did not open") }
}

func press(_ name: String) {
    openPanel()
    guard let row = rows().first(where: { ((attr($0, kAXDescriptionAttribute) as String?) ?? "").hasPrefix(name) })
    else { fatalError("no row \(name)") }
    AXUIElementPerformAction(row, kAXPressAction as CFString)
    print("pressed \(name)"); fflush(stdout)
}

func closePanel() {
    if !rows().isEmpty {
        AXUIElementPerformAction(soundItem, kAXPressAction as CFString)
    }
}

/// Core Audio: the default output's main volume and mute.
func address(_ s: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    .init(
        mSelector: s,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
}

func output() -> AudioObjectID {
    var a = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var id = AudioObjectID(); var size = UInt32(4)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id); return id
}

func volume()
    -> Float32
{
    var a = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume); var v = Float32(0); var s =
        UInt32(4); AudioObjectGetPropertyData(
            output(),
            &a,
            0,
            nil,
            &s,
            &v
        ); return v
}

func setVolume(_ v: Float32) {
    var a = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume); var v = v; AudioObjectSetPropertyData(
        output(),
        &a,
        0,
        nil,
        4,
        &v
    ); print("volume \(v)"); fflush(stdout)
}

func muted()
    -> UInt32
{
    var a = address(kAudioDevicePropertyMute); var v = UInt32(0); var s = UInt32(4); AudioObjectGetPropertyData(
        output(),
        &a,
        0,
        nil,
        &s,
        &v
    ); return v
}

func setMuted(_ m: UInt32) {
    var a = address(kAudioDevicePropertyMute); var m = m; AudioObjectSetPropertyData(
        output(),
        &a,
        0,
        nil,
        4,
        &m
    ); print("mute \(m)"); fflush(stdout)
}

openPanel()
if dry {
    // One second of the bar with the menu open, so a frame of the active display's bar can be read.
    let recorder = Process()
    recorder.executableURL = URL(fileURLWithPath: args[1])
    recorder.arguments = ["2014", "0", "350", "33", "1", args[2]]
    recorder.environment = ["DISPLAY_ID": "2"]
    try recorder.run()
    recorder.waitUntilExit()
    for r in rows() {
        print(identifier(r), (attr(r, kAXDescriptionAttribute) as String?) ?? "")
    }
    closePanel()
    exit(0)
}

let startVolume = volume(), startMute = muted()
let recorder = Process()
recorder.executableURL = URL(fileURLWithPath: args[1])
recorder.arguments = ["2014", "0", "350", "33", "36", args[2]]
recorder.environment = ["DISPLAY_ID": "2"]
try recorder.run()

sleep(2)
let step: UInt32 = 2_000_000
func defaults(_ a: String...) {
    let p = try! Process.run(URL(fileURLWithPath: "/usr/bin/defaults"), arguments: a); p.waitUntilExit()
}

func pick(_ name: String) {
    defaults("write", "ai.den.io", "pickOutput", name); print("picked \(name)"); fflush(stdout)
}

pick("MacBook Pro Speakers"); usleep(step)
let speakersVolume = volume()
for v: Float32 in [0.2, 0.8, speakersVolume] {
    setVolume(v); usleep(step)
}

setMuted(1); usleep(step); setMuted(0); usleep(step)
pick("External Headphones"); usleep(step)
let headphonesMute = muted(); setMuted(1); usleep(step); setMuted(headphonesMute); usleep(step)
// The AirPods' output names, as `devs` lists them.
if let name = ProcessInfo.processInfo.environment["AIRPODS_PRO"] {
    pick(name); usleep(step)
}

pick("MacBook Pro Speakers"); usleep(step)
if let name = ProcessInfo.processInfo.environment["AIRPODS_MAX"] {
    pick(name); usleep(step)
}

defaults("delete", "ai.den.io", "pickOutput")
setVolume(startVolume); setMuted(startMute)
closePanel()
recorder.waitUntilExit()
