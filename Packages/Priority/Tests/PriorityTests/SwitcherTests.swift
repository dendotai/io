import Foundation
import Testing
import Priority

let studioMicrophone = Device(uid: "studio-microphone", name: "Studio Display Microphone")

func at(_ seconds: Double) -> Date {
    Date(timeIntervalSinceReferenceDate: seconds)
}

func makeSwitcher() -> Switcher {
    Switcher(
        output: DeviceList(newDevices: .top, store: MemoryStore()),
        input: DeviceList(newDevices: .bottom, store: MemoryStore())
    )
}

/// AirPods Max D on, MacBook Pro Microphone in use.
func startWearingAirPods(_ switcher: Switcher) {
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, airPodsMicrophone]],
        inUse: [.output: airPods, .input: microphone],
        at: at(0)
    )
}

// Recorded on macOS 27: a switch to MacBook Pro Speakers, then macOS moves the output back to AirPods Max D and takes their microphone.
@Test func macOSTakingTheAirPodsMicrophoneAfterAnOutputSwitchIsUndone() {
    let switcher = makeSwitcher()
    startWearingAirPods(switcher)
    switcher.pick(speakers, in: .output)
    switcher.defaultsChanged(inUse: [.output: speakers, .input: microphone], at: at(100))
    switcher.defaultsChanged(inUse: [.output: airPods, .input: microphone], at: at(100.074))
    switcher.defaultsChanged(inUse: [.output: airPods, .input: airPodsMicrophone], at: at(100.089))
    #expect(switcher.chosenDevice(.input) == microphone)
}

// Recorded on macOS 27: AirPods Max D taken off to the neck disconnect, and put back on connect again.
@Test func airPodsTakenOffAndPutBackOnKeepTheMicrophone() {
    let switcher = makeSwitcher()
    startWearingAirPods(switcher)
    switcher.devicesChanged(
        connected: [.output: [speakers], .input: [microphone]],
        inUse: [.output: speakers, .input: microphone],
        at: at(50.426)
    )
    #expect(switcher.chosenDevice(.output) == speakers)
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, airPodsMicrophone]],
        inUse: [.output: speakers, .input: microphone],
        at: at(54.895)
    )
    switcher.defaultsChanged(inUse: [.output: airPods, .input: airPodsMicrophone], at: at(54.922))
    #expect(switcher.chosenDevice(.output) == airPods)
    #expect(switcher.chosenDevice(.input) == microphone)
}

@Test func macOSSelectingANewMicrophoneAfterItConnectsIsUndone() {
    let switcher = makeSwitcher()
    startWearingAirPods(switcher)
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, airPodsMicrophone, iPhone]],
        inUse: [.output: airPods, .input: microphone],
        at: at(10)
    )
    switcher.defaultsChanged(inUse: [.output: airPods, .input: iPhone], at: at(10.02))
    #expect(switcher.chosenDevice(.input) == microphone)
}

@Test func soundMenuPickBecomesTheHandPick() {
    let switcher = makeSwitcher()
    switcher.devicesChanged(
        connected: [.output: [speakers], .input: [microphone, studioMicrophone]],
        inUse: [.output: speakers, .input: microphone],
        at: at(0)
    )
    switcher.defaultsChanged(inUse: [.output: speakers, .input: studioMicrophone], at: at(30))
    #expect(switcher.chosenDevice(.input) == studioMicrophone)
    switcher.devicesChanged(
        connected: [.output: [speakers], .input: [microphone, studioMicrophone, iPhone]],
        inUse: [.output: speakers, .input: studioMicrophone],
        at: at(40)
    )
    #expect(switcher.chosenDevice(.input) == studioMicrophone)
}

@Test func reorderThenAirPodsConnectingKeepsTheMicrophone() {
    let switcher = makeSwitcher()
    switcher.devicesChanged(
        connected: [.output: [speakers], .input: [microphone, iPhone, studioMicrophone]],
        inUse: [.output: speakers, .input: microphone],
        at: at(0)
    )
    switcher.reorder(studioMicrophone, to: 0, in: .input)
    #expect(switcher.chosenDevice(.input) == microphone)
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, iPhone, studioMicrophone, airPodsMicrophone]],
        inUse: [.output: speakers, .input: microphone],
        at: at(20)
    )
    switcher.defaultsChanged(inUse: [.output: airPods, .input: airPodsMicrophone], at: at(20.03))
    #expect(switcher.chosenDevice(.output) == airPods)
    #expect(switcher.chosenDevice(.input) == microphone)
}
