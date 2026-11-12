import Priority
import Testing

private let slash = MenuBarSymbol(name: "speaker.slash.fill")

private func waves(_ variableValue: Double) -> MenuBarSymbol {
    MenuBarSymbol(name: "speaker.wave.3.fill", variableValue: variableValue)
}

@Test func anOutputWithoutItsOwnSymbolShowsItsLevel() {
    let expected: [(Float, MenuBarSymbol)] = [
        (0, slash), (0.01, waves(0.01)), (0.33, waves(0.01)), (0.34, waves(0.34)),
        (0.66, waves(0.34)), (0.67, waves(1)), (1, waves(1)),
    ]
    for (volume, symbol) in expected {
        #expect(MenuBarSymbol.of(deviceSymbol: "macbook.gen2", volume: volume, isMuted: false) == symbol)
    }
}

@Test func aMutedOutputWithoutItsOwnSymbolShowsTheSlash() {
    #expect(MenuBarSymbol.of(deviceSymbol: "display", volume: 0.8, isMuted: true) == slash)
}

@Test func anOutputWithNoVolumeControlAlwaysShowsAllWaves() {
    #expect(MenuBarSymbol.of(deviceSymbol: "display", volume: nil, isMuted: false) == waves(1))
    #expect(MenuBarSymbol.of(deviceSymbol: "display", volume: nil, isMuted: true) == waves(1))
}

@Test func headphonesShowTheirSymbolAboveZeroAndTheSlashAtZeroOrMute() {
    #expect(MenuBarSymbol
        .of(deviceSymbol: "headphones", volume: 0.01, isMuted: false) == MenuBarSymbol(name: "headphones"))
    #expect(MenuBarSymbol
        .of(deviceSymbol: "headphones", volume: 0, isMuted: false) == MenuBarSymbol(name: "headphones.slash"))
    #expect(MenuBarSymbol
        .of(deviceSymbol: "headphones", volume: 0.5, isMuted: true) == MenuBarSymbol(name: "headphones.slash"))
}

@Test(arguments: ["airpods.pro.gen3", "airpods.max", "beats.studiobuds"])
func airPodsAndBeatsKeepTheirSymbolInEveryState(model: String) {
    let own = MenuBarSymbol(name: model)
    #expect(MenuBarSymbol.of(deviceSymbol: model, volume: 0.5, isMuted: false) == own)
    #expect(MenuBarSymbol.of(deviceSymbol: model, volume: 0, isMuted: false) == own)
    #expect(MenuBarSymbol.of(deviceSymbol: model, volume: 0.5, isMuted: true) == own)
}

@Test(arguments: ["airpods.pro.gen3", "airpods.max", "beats.studiobuds"])
func airPodsAndBeatsHaveAModelSymbol(model: String) {
    #expect(MenuBarSymbol.isModelSymbol(model))
}

@Test(arguments: ["speaker.wave.3.fill", "headphones", "headphones.slash"])
func speakersAndHeadphonesHaveNoModelSymbol(name: String) {
    #expect(!MenuBarSymbol.isModelSymbol(name))
}
