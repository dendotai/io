import Priority
import Testing

let airPlay = Device(uid: "context-1-Audio", name: "AirPlay")

@Test func anAirPlayPickIsChosenAndCanEnd() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers], airPlay: airPlay)
    #expect(list.airPlayPick == airPlay)
    #expect(list.chosenDevice == airPlay)
    #expect(list.canEndHandPick)
    #expect(list.devices == [speakers])
}

@Test func backToAutoEndsAnAirPlayPick() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.pick(speakers)
    list.update(connected: [speakers, airPods], airPlay: airPlay)
    list.endHandPick()
    #expect(list.airPlayPick == nil)
    #expect(list.chosenDevice == airPods)
}

@Test func aPanelPickEndsAnAirPlayPick() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers, airPods], airPlay: airPlay)
    list.pick(speakers)
    #expect(list.airPlayPick == nil)
    #expect(list.chosenDevice == speakers)
}

@Test func aPickOfTheAirPlayRowKeepsTheAirPlayPick() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers], airPlay: airPlay)
    list.pick(airPlay)
    #expect(list.chosenDevice == airPlay)
}

@Test func anAirPlayPickThatStopsLeavesTheHandPick() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers, airPods])
    list.pick(speakers)
    list.update(connected: [speakers, airPods], airPlay: airPlay)
    list.update(connected: [speakers, airPods])
    #expect(list.airPlayPick == nil)
    #expect(list.chosenDevice == speakers)
}

@Test func anAirPlayPickHoldsWhenADeviceConnects() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers], airPlay: airPlay)
    list.update(connected: [speakers, airPods], airPlay: airPlay)
    #expect(list.chosenDevice == airPlay)
    #expect(list.devices == [airPods, speakers])
}

@Test func aReorderDuringAnAirPlayPickStartsNoHandPick() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers, airPods], airPlay: airPlay)
    list.reorder(speakers, to: 0)
    list.update(connected: [speakers, airPods])
    #expect(list.chosenDevice == speakers)
    #expect(!list.canEndHandPick)
}
