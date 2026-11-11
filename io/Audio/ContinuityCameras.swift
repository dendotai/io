import AVFoundation
import Priority

/// The model codes of the iPhones that macOS lists as Continuity Camera devices.
enum ContinuityCameras {
    static func modelCode(ofMicrophone uid: String) -> String? {
        let cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external], mediaType: .video, position: .unspecified
        ).devices.map { (uid: $0.uniqueID, modelCode: $0.modelID) }
        return IPhoneSymbol.modelCode(ofMicrophone: uid, cameras: cameras)
    }
}
