/// The battery levels of one pair of headphones, in percent, as the Sound menu shows them. A level macOS does not report is nil.
public struct BatteryLevels: Equatable, Sendable {
    /// Both buds as one level.
    public var buds: Int?
    public var left: Int?
    public var right: Int?
    public var chargingCase: Int?
    /// The level of headphones with one battery, such as AirPods Max, which the Sound menu shows at the row's right, not under the name.
    public var single: Int?

    public init(buds: Int? = nil, left: Int? = nil, right: Int? = nil, chargingCase: Int? = nil, single: Int? = nil) {
        self.buds = buds
        self.left = left
        self.right = right
        self.chargingCase = chargingCase
        self.single = single
    }

    /// Reads the accessory power sources that `pmset -g accps` lists, keyed by the name the buds report, which is the Core Audio device name.
    /// macOS reports both buds as one "Combined" entry while they are alike, and a "Left" and a "Right" entry once one is in the case; the Sound menu follows the entries. The case is its own entry, named "<name> Case", in the same group.
    public static func byName(_ sources: [[String: Any]]) -> [String: BatteryLevels] {
        var levelsByGroup: [String: BatteryLevels] = [:]
        var nameByGroup: [String: String] = [:]
        for source in sources where source["Type"] as? String == "Accessory Source" && source["Is Present"] as? Bool != false {
            guard let name = source["Name"] as? String, let current = source["Current Capacity"] as? Int,
                let max = source["Max Capacity"] as? Int, max > 0
            else { continue }
            let group = source["Group Identifier"] as? String ?? name
            let level = Int((Double(current) / Double(max) * 100).rounded())
            var levels = levelsByGroup[group] ?? BatteryLevels()
            let part = source["Part Identifier"] as? String
            switch part {
            case "Case": levels.chargingCase = level
            case "Left": levels.left = level
            case "Right": levels.right = level
            case "Single": levels.single = level
            default: levels.buds = level
            }
            levelsByGroup[group] = levels
            if part != "Case" {
                nameByGroup[group] = name
            }
        }
        var levelsByName: [String: BatteryLevels] = [:]
        for (group, name) in nameByGroup {
            levelsByName[name] = levelsByGroup[group]
        }
        return levelsByName
    }
}
