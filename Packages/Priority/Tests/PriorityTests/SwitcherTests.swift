import Testing
import Priority

let studioMicrophone = Device(uid: "studio-microphone", name: "Studio Display Microphone")

func makeSwitcher() -> Switcher {
    Switcher(
        output: DeviceList(newDevices: .top, store: MemoryStore()),
        input: DeviceList(newDevices: .bottom, store: MemoryStore())
    )
}

/// AirPods Max on, MacBook Pro Microphone in use.
func startWearingAirPods(_ switcher: Switcher) {
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, airPodsMicrophone]],
        inUse: [.output: airPods, .input: microphone]
    )
}

// Recorded on macOS 27: `audioaccessoryd` moves the output to AirPods Max a second time, 4.7 s after they connect.
@Test func aDefaultChangeByAnotherProcessLeavesTheSpeakersChosen() {
    let switcher = makeSwitcher()
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, airPodsMicrophone]],
        inUse: [.output: speakers, .input: microphone]
    )
    switcher.devicesChanged(
        connected: [.output: [speakers], .input: [microphone]],
        inUse: [.output: speakers, .input: microphone]
    )
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, airPodsMicrophone]],
        inUse: [.output: speakers, .input: microphone]
    )
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, airPodsMicrophone]],
        inUse: [.output: airPods, .input: airPodsMicrophone]
    )
    #expect(switcher.chosenDevice(.output) == speakers)
    #expect(switcher.chosenDevice(.input) == microphone)
}

@Test func aPickInThePanelHoldsAfterADefaultChangeByAnotherProcess() {
    let switcher = makeSwitcher()
    startWearingAirPods(switcher)
    switcher.pick(speakers, in: .output)
    switcher.pick(airPodsMicrophone, in: .input)
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, airPodsMicrophone]],
        inUse: [.output: airPods, .input: microphone]
    )
    #expect(switcher.chosenDevice(.output) == speakers)
    #expect(switcher.chosenDevice(.input) == airPodsMicrophone)
}

// Recorded on macOS 27: AirPods Max taken off to the neck disconnect, and put back on connect again.
@Test func airPodsTakenOffAndPutBackOnKeepTheMicrophone() {
    let switcher = makeSwitcher()
    startWearingAirPods(switcher)
    switcher.devicesChanged(
        connected: [.output: [speakers], .input: [microphone]],
        inUse: [.output: speakers, .input: microphone]
    )
    #expect(switcher.chosenDevice(.output) == speakers)
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, airPodsMicrophone]],
        inUse: [.output: airPods, .input: airPodsMicrophone]
    )
    #expect(switcher.chosenDevice(.output) == airPods)
    #expect(switcher.chosenDevice(.input) == microphone)
}

@Test func aPickInThePanelCanEndOnlyInItsOwnList() {
    let switcher = makeSwitcher()
    startWearingAirPods(switcher)
    switcher.pick(speakers, in: .output)
    #expect(switcher.list(.output).canEndHandPick)
    #expect(!switcher.list(.input).canEndHandPick)
    switcher.endHandPick(in: .output)
    #expect(switcher.chosenDevice(.output) == airPods)
    #expect(!switcher.list(.output).canEndHandPick)
}

@Test func reorderThenAirPodsConnectingKeepsTheMicrophone() {
    let switcher = makeSwitcher()
    switcher.devicesChanged(
        connected: [.output: [speakers], .input: [microphone, iPhone, studioMicrophone]],
        inUse: [.output: speakers, .input: microphone]
    )
    switcher.reorder(studioMicrophone, to: 0, in: .input)
    #expect(switcher.chosenDevice(.input) == microphone)
    switcher.devicesChanged(
        connected: [.output: [speakers, airPods], .input: [microphone, iPhone, studioMicrophone, airPodsMicrophone]],
        inUse: [.output: airPods, .input: airPodsMicrophone]
    )
    #expect(switcher.chosenDevice(.output) == airPods)
    #expect(switcher.chosenDevice(.input) == microphone)
}
