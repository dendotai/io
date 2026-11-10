import AppKit
import CoreMedia
import ScreenCaptureKit

// record120 X Y W H SECONDS OUTDIR (region of the main display in points, top-left origin; compile with `swiftc -O`): records at the display's refresh rate, writes f<ms>.png per distinct frame (ms after the first frame) and frames.txt (one "<ms> <file>" line per frame), and prints the frame count, the mean gap, and the max gap.
let a = CommandLine.arguments
let rect = CGRect(x: Double(a[1])!, y: Double(a[2])!, width: Double(a[3])!, height: Double(a[4])!)
let seconds = Double(a[5])!
let out = URL(fileURLWithPath: a[6])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

final class Sink: NSObject, SCStreamOutput {
    var first: CMTime?
    var lastHash: Int?
    var duplicates = 0
    var frames: [(ms: Int, width: Int, height: Int, bytesPerRow: Int, data: Data)] = []
    func stream(_: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let attachments = CMSampleBufferGetSampleAttachmentsArray(
                  buffer,
                  createIfNecessary: false
              ) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue,
              let pixels = CMSampleBufferGetImageBuffer(buffer)
        else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(buffer)
        if first == nil {
            first = time
        }
        let ms = Int(((CMTimeGetSeconds(time) - CMTimeGetSeconds(first!)) * 1000).rounded())
        // Copy the pixels out at once so the stream gets its buffer back; the PNGs are written after the recording, because encoding inside the callback stalls the stream.
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        let data = Data(bytes: CVPixelBufferGetBaseAddress(pixels)!, count: CVPixelBufferGetDataSize(pixels))
        let size = (CVPixelBufferGetWidth(pixels), CVPixelBufferGetHeight(pixels), CVPixelBufferGetBytesPerRow(pixels))
        CVPixelBufferUnlockBaseAddress(pixels, .readOnly)
        var hasher = Hasher(); hasher.combine(data); let hash = hasher.finalize()
        if hash == lastHash {
            duplicates += 1; return
        }
        lastHash = hash
        frames.append((ms, size.0, size.1, size.2, data))
    }
}

let sink = Sink()
Task {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    let display = content.displays
        .first {
            $0
                .displayID ==
                CGDirectDisplayID(ProcessInfo.processInfo.environment["DISPLAY_ID"]
                    .flatMap(UInt32.init) ?? CGMainDisplayID())
        }!
    let config = SCStreamConfiguration()
    config.sourceRect = rect
    config.width = Int(rect.width) * 2
    config.height = Int(rect.height) * 2
    config.pixelFormat = kCVPixelFormatType_32BGRA
    // .zero means the display's own refresh rate; 1/120 caps the stream below it.
    config.minimumFrameInterval = .zero
    config.showsCursor = false
    config.queueDepth = 8
    let stream = SCStream(
        filter: SCContentFilter(display: display, excludingWindows: []),
        configuration: config,
        delegate: nil
    )
    try stream.addStreamOutput(
        sink,
        type: .screen,
        sampleHandlerQueue: DispatchQueue(label: "frames", qos: .userInteractive)
    )
    try await stream.startCapture()
    print("recording"); fflush(stdout)
    try await Task.sleep(for: .seconds(seconds))
    try await stream.stopCapture()
    var list = ""
    for frame in sink.frames {
        let provider = CGDataProvider(data: frame.data as CFData)!
        let image = CGImage(
            width: frame.width,
            height: frame.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: frame.bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo
                .byteOrder32Little.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        let name = String(format: "f%05d.png", frame.ms)
        try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
            .write(to: out.appendingPathComponent(name))
        list += "\(frame.ms) \(name)\n"
    }
    try list.write(to: out.appendingPathComponent("frames.txt"), atomically: true, encoding: .utf8)
    let times = sink.frames.map(\.ms)
    let gaps = zip(times.dropFirst(), times).map { $0 - $1 }
    let span = (times.last ?? 0) - (times.first ?? 0)
    print(String(
        format: "frames %d (%d duplicates skipped) over %.2f s = %.1f fps, mean gap %.1f ms, max gap %d ms",
        times.count,
        sink.duplicates,
        Double(span) / 1000,
        Double(times.count - 1) * 1000 / Double(max(span, 1)),
        Double(span) / Double(max(times.count - 1, 1)),
        gaps.max() ?? 0
    ))
    exit(0)
}

RunLoop.main.run()
