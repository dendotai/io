import Foundation
import Testing
import Priority

final class MemoryStore: DeviceListStore {
    var saved: [Device] = []
    func load() -> [Device] { saved }
    func save(_ devices: [Device]) { saved = devices }
}

let speakers = Device(uid: "speakers", name: "MacBook Pro Speakers")
let airPods = Device(uid: "airpods-1", name: "AirPods Pro D1")
let display = Device(uid: "display", name: "Studio Display")

@Test func newOutputGoesToTheTop() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    #expect(list.devices == [airPods, speakers])
}

@Test func disconnectedDeviceKeepsItsPlace() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.update(connected: [speakers])
    #expect(list.devices == [airPods, speakers])
}

@Test func chosenDeviceIsTheHighestConnected() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    #expect(list.chosenDevice == airPods)
    list.update(connected: [speakers])
    #expect(list.chosenDevice == speakers)
}

@Test func noConnectedDeviceChoosesNothing() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [])
    #expect(list.chosenDevice == nil)
}

@Test func handPickHoldsWhileNothingChanges() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.pick(speakers)
    #expect(list.chosenDevice == speakers)
    #expect(list.update(connected: [speakers, airPods]) == false)
    #expect(list.chosenDevice == speakers)
}

@Test func higherDeviceConnectingEndsTheHandPick() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, display])
    list.update(connected: [speakers, display, airPods])
    list.update(connected: [speakers, display])
    #expect(list.devices == [airPods, display, speakers])
    list.pick(speakers)
    list.update(connected: [speakers, display, airPods])
    #expect(list.chosenDevice == airPods)
}

@Test func lowerDeviceConnectingKeepsTheHandPick() {
    let list = DeviceList(newDevices: .bottom, store: MemoryStore())
    list.update(connected: [microphone])
    list.update(connected: [microphone, airPodsMicrophone])
    list.pick(airPodsMicrophone)
    list.update(connected: [microphone, airPodsMicrophone, iPhone])
    #expect(list.chosenDevice == airPodsMicrophone)
}

@Test func pickedDeviceDisconnectingEndsTheHandPick() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.pick(speakers)
    list.update(connected: [airPods])
    list.update(connected: [speakers, airPods])
    #expect(list.chosenDevice == airPods)
}

@Test func higherDeviceDisconnectingKeepsTheHandPick() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, display])
    list.update(connected: [speakers, display, airPods])
    list.pick(speakers)
    list.update(connected: [speakers, display])
    #expect(list.chosenDevice == speakers)
}

@Test func lowerDeviceDisconnectingKeepsTheHandPick() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, display])
    list.update(connected: [speakers, display, airPods])
    list.pick(display)
    list.update(connected: [display, airPods])
    #expect(list.chosenDevice == display)
}

@Test func pickingTheTopDeviceFollowsThePriority() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.pick(airPods)
    #expect(list.chosenDevice == airPods)
    list.update(connected: [speakers])
    #expect(list.chosenDevice == speakers)
}

@Test func handPickNeverMovesTheDevice() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.pick(speakers)
    #expect(list.devices == [airPods, speakers])
}

@Test func restartKeepsTheOrder() {
    let store = MemoryStore()
    let first = DeviceList(newDevices: .top, store: store)
    first.update(connected: [speakers])
    first.update(connected: [speakers, airPods])
    first.update(connected: [speakers])

    let second = DeviceList(newDevices: .top, store: store)
    #expect(second.devices == [airPods, speakers])
    second.update(connected: [speakers, airPods])
    #expect(second.devices == [airPods, speakers])
    #expect(second.chosenDevice == airPods)
}

@Test func reorderKeepsADisconnectedDeviceInItsPlace() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [display])
    list.update(connected: [display, speakers])
    list.update(connected: [display, speakers, airPods])
    list.update(connected: [display, speakers])
    #expect(list.devices == [airPods, speakers, display])
    list.reorder(display, to: 1)
    #expect(list.devices == [airPods, display, speakers])
}

@Test func reorderMovesADisconnectedDevice() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.update(connected: [speakers])
    list.reorder(airPods, to: 1)
    #expect(list.devices == [speakers, airPods])
}

@Test func reorderKeepsTheDeviceInUse() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.reorder(speakers, to: 0)
    #expect(list.chosenDevice == airPods)
}

@Test func reorderOfTheDeviceInUseKeepsIt() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.reorder(airPods, to: 1)
    #expect(list.chosenDevice == airPods)
}

@Test func reorderKeepsTheHandPick() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, display])
    list.update(connected: [speakers, display, airPods])
    list.pick(speakers)
    list.reorder(display, to: 0)
    #expect(list.chosenDevice == speakers)
}

@Test func deviceKeptByAReorderEndsWhenItDisconnects() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    list.reorder(speakers, to: 0)
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    #expect(list.chosenDevice == speakers)
}

@Test func restartKeepsAReorder() {
    let store = MemoryStore()
    let first = DeviceList(newDevices: .top, store: store)
    first.update(connected: [speakers])
    first.update(connected: [speakers, airPods])
    first.reorder(speakers, to: 0)
    #expect(DeviceList(newDevices: .top, store: store).devices == [speakers, airPods])
}

@Test func renamedDeviceKeepsItsPlace() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    let renamed = Device(uid: airPods.uid, name: "Renamed AirPods")
    list.update(connected: [speakers, renamed])
    #expect(list.devices == [renamed, speakers])
}

let microphone = Device(uid: "microphone", name: "MacBook Pro Microphone")
let iPhone = Device(uid: "iphone-1", name: "iPhone D1 Microphone")
let airPodsMicrophone = Device(uid: "airpods-1-input", name: "AirPods Max D")

@Test func newInputGoesToTheBottom() {
    let list = DeviceList(newDevices: .bottom, store: MemoryStore())
    list.update(connected: [microphone])
    list.update(connected: [microphone, iPhone])
    #expect(list.devices == [microphone, iPhone])
    #expect(list.chosenDevice == microphone)
}

@Test func inputReorderKeepsADisconnectedDeviceInItsPlace() {
    let list = DeviceList(newDevices: .bottom, store: MemoryStore())
    list.update(connected: [microphone])
    list.update(connected: [microphone, airPodsMicrophone])
    list.update(connected: [microphone, airPodsMicrophone, iPhone])
    list.update(connected: [microphone, iPhone])
    #expect(list.devices == [microphone, airPodsMicrophone, iPhone])
    list.reorder(iPhone, to: 0)
    #expect(list.devices == [iPhone, microphone, airPodsMicrophone])
}

@Test func firstUpdatePutsTheDeviceInUseFirst() {
    let list = DeviceList(newDevices: .bottom, store: MemoryStore())
    list.update(connected: [airPodsMicrophone, iPhone, microphone], inUse: microphone)
    #expect(list.devices == [microphone, airPodsMicrophone, iPhone])
    #expect(list.chosenDevice == microphone)
}

@Test func laterUpdateIgnoresTheDeviceInUse() {
    let list = DeviceList(newDevices: .bottom, store: MemoryStore())
    list.update(connected: [microphone])
    list.update(connected: [microphone, iPhone], inUse: iPhone)
    #expect(list.devices == [microphone, iPhone])
}

@Test func firstOutputUpdatePutsTheDeviceInUseFirst() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [airPods, display, speakers], inUse: speakers)
    #expect(list.devices == [speakers, airPods, display])
}

let builtInSpeakers = Device(uid: "built-in-speakers", name: "MacBook Pro Speakers", isBuiltIn: true)

@Test func hideRemovesOnlyThatDevice() {
    let store = MemoryStore()
    let list = DeviceList(newDevices: .top, store: store)
    list.update(connected: [speakers])
    list.update(connected: [speakers, display])
    list.update(connected: [speakers, display, airPods])
    list.update(connected: [speakers])
    list.hide(display)
    #expect(list.devices == [airPods, speakers])
    #expect(store.saved == [airPods, speakers])
}

@Test func connectedDeviceCannotBeHidden() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, airPods])
    #expect(list.canHide(airPods) == false)
    list.hide(airPods)
    #expect(list.devices == [airPods, speakers])
}

@Test func builtInDeviceCannotBeHidden() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [builtInSpeakers])
    list.update(connected: [airPods])
    #expect(list.canHide(builtInSpeakers) == false)
    list.hide(builtInSpeakers)
    #expect(list.devices == [airPods, builtInSpeakers])
}

@Test func hiddenOutputComesBackAtTheTop() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [speakers])
    list.update(connected: [speakers, display])
    list.update(connected: [speakers, display, airPods])
    list.update(connected: [speakers, airPods])
    list.hide(display)
    list.update(connected: [speakers, airPods, display])
    #expect(list.devices == [display, airPods, speakers])
}

@Test func hiddenInputComesBackAtTheBottom() {
    let list = DeviceList(newDevices: .bottom, store: MemoryStore())
    list.update(connected: [microphone])
    list.update(connected: [microphone, iPhone])
    list.reorder(iPhone, to: 0)
    list.update(connected: [microphone])
    list.hide(iPhone)
    list.update(connected: [microphone, iPhone])
    #expect(list.devices == [microphone, iPhone])
}

@Test func connectRefreshesWhetherTheDeviceIsBuiltIn() {
    let list = DeviceList(newDevices: .top, store: MemoryStore())
    list.update(connected: [Device(uid: builtInSpeakers.uid, name: builtInSpeakers.name)])
    list.update(connected: [builtInSpeakers])
    list.update(connected: [])
    #expect(list.canHide(builtInSpeakers) == false)
}

@Test func listSavedWithoutBuiltInStillLoads() throws {
    let data = Data(#"[{"uid":"airpods-1","name":"AirPods Pro D1"}]"#.utf8)
    #expect(try JSONDecoder().decode([Device].self, from: data) == [airPods])
}
