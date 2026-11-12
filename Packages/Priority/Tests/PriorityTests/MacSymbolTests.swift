import Priority
import Testing

@Test(arguments: [
    ("MacBookPro18,1", "macbook.gen2"),
    ("MacBookAir10,1", "macbook.gen1"),
    ("Macmini9,1", "macmini.gen2"),
    ("Mac13,1", "macstudio"),
    ("iMac13,1", "desktopcomputer"),
    ("MacPro7,1", "macpro.gen3"),
])
func aMacShowsTheSymbolOfItsModel(modelCode: String, symbol: String) {
    #expect(MacSymbol.of(modelCode: modelCode) == symbol)
}

@Test func aModelTheSystemDoesNotListShowsTheGenericLaptop() {
    #expect(MacSymbol.of(modelCode: "Mac99,1") == "laptopcomputer")
}
