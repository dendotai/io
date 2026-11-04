import Testing
import Priority

@Test func aPairWithoutNoiseCancellationHasNoListeningMode() {
    #expect(ListeningMode.supported(productID: 0x2013, isANCSupported: false).isEmpty)
}

@Test func aPairWithAdaptiveOffersAllFourInTheSoundMenusOrder() {
    #expect(ListeningMode.supported(productID: 0x2027, isANCSupported: true) == [.off, .transparency, .adaptive, .noiseCancellation])
}

@Test func airPodsMaxOfferNoAdaptive() {
    #expect(ListeningMode.supported(productID: 0x200A, isANCSupported: true) == [.off, .transparency, .noiseCancellation])
}

@Test func theRawValuesAreTheOnesTheBluetoothSettingTakes() {
    #expect([ListeningMode.off, .noiseCancellation, .transparency, .adaptive].map(\.rawValue) == [1, 2, 3, 4])
}
