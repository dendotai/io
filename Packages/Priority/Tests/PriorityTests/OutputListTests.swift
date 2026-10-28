import Testing
import Priority

final class MemoryStore: OutputListStore {
    var saved: [Device] = []
    func load() -> [Device] { saved }
    func save(_ devices: [Device]) { saved = devices }
}

let speakers = Device(uid: "speakers", name: "MacBook Pro Speakers")
let airPods = Device(uid: "airpods-1", name: "AirPods Pro D1")
let display = Device(uid: "display", name: "Studio Display")

@Test func newOutputGoesToTheTop() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    #expect(list.devices == [airPods, speakers])
}

@Test func disconnectedDeviceKeepsItsPlace() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.update(connected: [speakers])
    #expect(list.devices == [airPods, speakers])
}

@Test func chosenDeviceIsTheHighestConnected() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    #expect(list.chosenDevice == airPods)
    list.update(connected: [speakers])
    #expect(list.chosenDevice == speakers)
}

@Test func noConnectedDeviceChoosesNothing() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [])
    #expect(list.chosenDevice == nil)
}

@Test func handPickHoldsUntilTheNextConnect() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.pick(speakers)
    #expect(list.chosenDevice == speakers)
    #expect(list.update(connected: [speakers, airPods]) == false)
    #expect(list.chosenDevice == speakers)
    list.update(connected: [speakers, airPods, display])
    #expect(list.chosenDevice == display)
}

@Test func handPickEndsAtTheNextDisconnect() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, display])
    list.update(connected: [speakers, display, airPods])
    list.pick(speakers)
    list.update(connected: [speakers, display])
    #expect(list.chosenDevice == display)
}

@Test func handPickNeverMovesTheDevice() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.pick(speakers)
    #expect(list.devices == [airPods, speakers])
}

@Test func restartKeepsTheOrder() {
    let store = MemoryStore()
    let first = OutputList(store: store)
    first.update(connected: [speakers])
    first.update(connected: [speakers, airPods])
    first.update(connected: [speakers])

    let second = OutputList(store: store)
    #expect(second.devices == [airPods, speakers])
    second.update(connected: [speakers, airPods])
    #expect(second.devices == [airPods, speakers])
    #expect(second.chosenDevice == airPods)
}

@Test func reorderKeepsADisconnectedDeviceInItsPlace() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [display])
    list.update(connected: [display, speakers])
    list.update(connected: [display, speakers, airPods])
    list.update(connected: [display, speakers])
    #expect(list.devices == [airPods, speakers, display])
    list.reorder(display, to: 1)
    #expect(list.devices == [airPods, display, speakers])
}

@Test func reorderMovesADisconnectedDevice() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.update(connected: [speakers])
    list.reorder(airPods, to: 1)
    #expect(list.devices == [speakers, airPods])
}

@Test func reorderChangesTheChosenDevice() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.reorder(speakers, to: 0)
    #expect(list.chosenDevice == speakers)
}

@Test func reorderEndsTheHandPick() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, display])
    list.update(connected: [speakers, display, airPods])
    list.pick(speakers)
    list.reorder(display, to: 0)
    #expect(list.chosenDevice == display)
}

@Test func restartKeepsAReorder() {
    let store = MemoryStore()
    let first = OutputList(store: store)
    first.update(connected: [speakers])
    first.update(connected: [speakers, airPods])
    first.reorder(speakers, to: 0)
    #expect(OutputList(store: store).devices == [speakers, airPods])
}

@Test func renamedDeviceKeepsItsPlace() {
    let list = OutputList(store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    let renamed = Device(uid: airPods.uid, name: "Renamed AirPods")
    list.update(connected: [speakers, renamed])
    #expect(list.devices == [renamed, speakers])
}
