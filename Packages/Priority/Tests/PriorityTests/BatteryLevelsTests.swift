import Priority
import Testing

func part(_ name: String, _ part: String, _ level: Int, group: String,
          isPresent: Bool) -> [String: Any]
{
    [
        "Type": "Accessory Source", "Name": name, "Part Identifier": part, "Group Identifier": group,
        "Current Capacity": level, "Max Capacity": 100, "Is Present": isPresent,
    ]
}

func combined(_ name: String, left: Int, right: Int, group: String) -> [String: Any] {
    var entry = part(name, "Combined", min(left, right), group: group, isPresent: true)
    entry["Combined Parts"] = [
        part(name, "Left", left, group: group, isPresent: true),
        part(name, "Right", right, group: group, isPresent: true),
    ]
    return entry
}

/// Recorded on macOS 27: both buds out of the case, the case open; the Sound menu shows "78%, 62%".
@Test func aPairReportsItsBudsAndCaseUnderTheBudsName() {
    let levels = BatteryLevels.byName([
        part("AirPods Pro Case", "Case", 62, group: "group-1", isPresent: true),
        combined("AirPods Pro", left: 78, right: 79, group: "group-1"),
    ])
    #expect(levels == ["AirPods Pro": BatteryLevels(buds: 78, chargingCase: 62)])
}

@Test func aLevelMacOSDoesNotReportIsLeftOut() {
    let levels = BatteryLevels.byName([combined("AirPods Pro", left: 40, right: 45, group: "group-1")])
    #expect(levels == ["AirPods Pro": BatteryLevels(buds: 40)])
}

@Test func aPartMarkedNotPresentIsLeftOut() {
    let levels = BatteryLevels.byName([
        part("AirPods Pro Case", "Case", 0, group: "group-1", isPresent: false),
        combined("AirPods Pro", left: 50, right: 60, group: "group-1"),
    ])
    #expect(levels == ["AirPods Pro": BatteryLevels(buds: 50)])
}

/// Recorded on macOS 27: the right bud in the case; the Sound menu shows "74%, 71%, 62%".
@Test func budsReportedApartKeepTheirOwnLevels() {
    let levels = BatteryLevels.byName([
        part("AirPods Pro Case", "Case", 62, group: "group-1", isPresent: true),
        part("AirPods Pro", "Left", 74, group: "group-1", isPresent: true),
        part("AirPods Pro", "Right", 71, group: "group-1", isPresent: true),
    ])
    #expect(levels == ["AirPods Pro": BatteryLevels(left: 74, right: 71, chargingCase: 62)])
}

/// Recorded on macOS 27: AirPods Max in use; the Sound menu shows "86%" at the right of the row.
@Test func headphonesWithOneBatteryKeepTheLevelApartFromBuds() {
    let levels = BatteryLevels.byName([part("AirPods Max", "Single", 90, group: "group-2", isPresent: true)])
    #expect(levels == ["AirPods Max": BatteryLevels(single: 90)])
}

@Test func twoPairsKeepTheirOwnCase() {
    let levels = BatteryLevels.byName([
        part("AirPods A Case", "Case", 10, group: "group-a", isPresent: true),
        combined("AirPods A", left: 11, right: 12, group: "group-a"),
        part("AirPods B Case", "Case", 20, group: "group-b", isPresent: true),
        combined("AirPods B", left: 21, right: 22, group: "group-b"),
    ])
    #expect(levels["AirPods A"] == BatteryLevels(buds: 11, chargingCase: 10))
    #expect(levels["AirPods B"] == BatteryLevels(buds: 21, chargingCase: 20))
}

@Test func theMacsOwnBatteryIsNotAnAccessory() {
    let levels = BatteryLevels.byName([
        [
            "Type": "InternalBattery",
            "Name": "InternalBattery-0",
            "Current Capacity": 80,
            "Max Capacity": 100,
            "Is Present": true,
        ],
    ])
    #expect(levels.isEmpty)
}
