import Priority
import Testing

@Test(arguments: [
    ("iPhone18,2", "iphone.gen3"),
    ("iPhone12,1", "iphone.gen2"),
    ("iPhone10,1", "iphone.gen1"),
])
func anIPhoneShowsTheSymbolOfItsGeneration(modelCode: String, symbol: String) {
    #expect(IPhoneSymbol.of(modelCode: modelCode) == symbol)
}

@Test func aModelTheSystemDoesNotListShowsTheGenericIPhone() {
    #expect(IPhoneSymbol.of(modelCode: "iPhone99,1") == "iphone")
}

@Test func aMicrophoneFindsTheCameraOfItsIPhone() {
    let cameras = [
        (uid: "AAAA0000-0000-0000-0000-000100000001", modelCode: "iPhone12,1"),
        (uid: "BBBB0000-0000-0000-0000-000200000001", modelCode: "iPhone18,2"),
    ]
    #expect(IPhoneSymbol
        .modelCode(ofMicrophone: "BBBB0000-0000-0000-0000-000200000003", cameras: cameras) == "iPhone18,2")
}

@Test func aMicrophoneWithNoCameraHasNoModel() {
    let cameras = [(uid: "AAAA0000-0000-0000-0000-000100000001", modelCode: "iPhone12,1")]
    #expect(IPhoneSymbol.modelCode(ofMicrophone: "CCCC0000-0000-0000-0000-000300000003", cameras: cameras) == nil)
}
