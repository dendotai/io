import Testing
import Priority

private let speakersUID = "1"
private let headphonesUID = "999"

private func icon(_ outputUID: String?, _ name: String, _ variableValue: Double = 1) -> MenuBarIcon {
    MenuBarIcon(outputUID: outputUID, symbol: MenuBarSymbol(name: name, variableValue: variableValue))
}

@Test func theSameOutputAndSymbolIsNoChange() {
    #expect(icon(speakersUID, "speaker.wave.3.fill").change(from: icon(speakersUID, "speaker.wave.3.fill")) == nil)
}

@Test func anotherOutputIsAnOutputChange() {
    #expect(icon(headphonesUID, "headphones").change(from: icon(speakersUID, "speaker.wave.3.fill")) == .output)
}

@Test func anotherOutputWithTheSameSymbolShowsOnlyItsLevel() {
    #expect(icon(headphonesUID, "speaker.wave.3.fill", 0.34).change(from: icon(speakersUID, "speaker.wave.3.fill", 1)) == .level)
    #expect(icon(headphonesUID, "speaker.wave.3.fill").change(from: icon(speakersUID, "speaker.wave.3.fill")) == nil)
}

@Test func aLevelChangeKeepsTheSymbol() {
    #expect(icon(speakersUID, "speaker.wave.3.fill", 0.34).change(from: icon(speakersUID, "speaker.wave.3.fill", 1)) == .level)
}

@Test func aMuteChangeWithinTheOutputChangesTheSymbol() {
    #expect(icon(speakersUID, "speaker.slash.fill").change(from: icon(speakersUID, "speaker.wave.3.fill", 0.01)) == .symbol)
    #expect(icon(headphonesUID, "headphones.slash").change(from: icon(headphonesUID, "headphones")) == .symbol)
}
