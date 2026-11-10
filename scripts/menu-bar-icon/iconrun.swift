import AppKit
import ApplicationServices
import AudioToolbox
import CoreAudio

// iconrun <record path> <outdir> [dry|-] <io.app path>: opens the Sound menu by an Accessibility press, records the menu bar strip around io's icon and the Sound icon at 120 fps, changes the output through the Sound menu's rows and the volume and mute through Core Audio, then closes the panel and restores the volume and mute it read first. "dry" only opens the panel, records one second, lists its rows, and closes it.
let args = CommandLine.arguments
let dry = args.count > 3 && args[3] == "dry"

func attr<T>(_ uiElement: AXUIElement, _ name: String) -> T? {
    var attributeValue: CFTypeRef?
    return AXUIElementCopyAttributeValue(uiElement, name as CFString, &attributeValue) == .success ?
        attributeValue as? T : nil
}

func children(_ uiElement: AXUIElement) -> [AXUIElement] {
    attr(uiElement, kAXChildrenAttribute) ?? []
}

func identifier(_ uiElement: AXUIElement) -> String {
    attr(uiElement, kAXIdentifierAttribute) ?? ""
}

func find(_ uiElement: AXUIElement, depth: Int, _ match: (AXUIElement) -> Bool) -> [AXUIElement] {
    guard depth < 30 else { return [] }
    return (match(uiElement) ? [uiElement] : []) + children(uiElement).flatMap { find($0, depth: depth + 1, match) }
}

func element(_ bundle: String) -> AXUIElement {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first
    else { fatalError("\(bundle) is not running") }
    return AXUIElementCreateApplication(app.processIdentifier)
}

/// The Sound item's open menu shows the menu bar over a full-screen app; io's panel does not.
let agent = element("com.apple.MenuBarAgent")
guard let soundItem = find(agent, depth: 0, { identifier($0) == "com.apple.menuextra.sound" }).last
else { fatalError("no Sound item") }
let controlCenter = element("com.apple.controlcenter")
func rows() -> [AXUIElement] {
    find(controlCenter, depth: 0) { identifier($0).hasPrefix("sound-device-") }
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
func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    .init(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
}

func output() -> AudioObjectID {
    var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var id = AudioObjectID(); var size = UInt32(4)
    AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &defaultOutputAddress,
        0,
        nil,
        &size,
        &id
    ); return id
}

func volume()
    -> Float32
{
    var volumeAddress = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume); var mainVolume =
        Float32(0); var size =
        UInt32(4); AudioObjectGetPropertyData(
            output(),
            &volumeAddress,
            0,
            nil,
            &size,
            &mainVolume
        ); return mainVolume
}

func setVolume(_ newVolume: Float32) {
    var volumeAddress = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume); var newVolume =
        newVolume; AudioObjectSetPropertyData(
            output(),
            &volumeAddress,
            0,
            nil,
            4,
            &newVolume
        ); print("volume \(newVolume)"); fflush(stdout)
}

func muted()
    -> UInt32
{
    var muteAddress = address(kAudioDevicePropertyMute); var mute = UInt32(0); var size =
        UInt32(4); AudioObjectGetPropertyData(
            output(),
            &muteAddress,
            0,
            nil,
            &size,
            &mute
        ); return mute
}

func setMuted(_ mute: UInt32) {
    var muteAddress = address(kAudioDevicePropertyMute); var mute = mute; AudioObjectSetPropertyData(
        output(),
        &muteAddress,
        0,
        nil,
        4,
        &mute
    ); print("mute \(mute)"); fflush(stdout)
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
    for row in rows() {
        print(identifier(row), (attr(row, kAXDescriptionAttribute) as String?) ?? "")
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
func defaults(_ arguments: String...) {
    do {
        try Process.run(URL(fileURLWithPath: "/usr/bin/defaults"), arguments: arguments).waitUntilExit()
    } catch {
        fatalError("cannot run defaults \(arguments): \(error)")
    }
}

func pick(_ name: String) {
    defaults("write", "ai.den.io", "pickOutput", name); print("picked \(name)"); fflush(stdout)
}

pick("MacBook Pro Speakers"); usleep(step)
let speakersVolume = volume()
for targetVolume: Float32 in [0.2, 0.8, speakersVolume] {
    setVolume(targetVolume); usleep(step)
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
