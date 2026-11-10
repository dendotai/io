import AppKit
import CoreMedia
import Priority
import ScreenCaptureKit

// harness <seconds> <steps…>: a 32×22 window at the screen's bottom-left corner holds the real MenuBarIconView; each step "<outputUID>:<symbol>[:<variable>]" is shown 1 s apart; frames are captured at 120 Hz from the window and summed as ink (brightness > 0.35 at 2x), with the ink box and the centre, one line per distinct frame.
let args = CommandLine.arguments
let usage = "usage: harness <seconds> <outputUID>:<symbol>[:<variable>]…\n"
func need<T>(_ value: T?, _ what: @autoclosure () -> String) -> T {
    guard let value else { fatalError(what()) }
    return value
}

guard args.count > 1, let secondsPerStep = Double(args[1]) else {
    FileHandle.standardError.write(Data(usage.utf8))
    exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let env = ProcessInfo.processInfo.environment
let windowHeight = need(Double(env["WINDOW_H"] ?? "22"), "WINDOW_H is not a number"),
    hostY = need(Double(env["HOST_Y"] ?? "0"), "HOST_Y is not a number"),
    hostHeight = need(Double(env["HOST_H"] ?? "22"), "HOST_H is not a number")
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 32, height: windowHeight),
    styleMask: .borderless,
    backing: .buffered,
    defer: false
)
window.appearance = NSAppearance(named: .darkAqua)
window.backgroundColor = NSColor(white: 0.1, alpha: 1)
window.level = .statusBar
window.ignoresMouseEvents = true
window.isOpaque = true
let button = NSStatusBarButton(frame: NSRect(x: 0, y: hostY, width: 32, height: hostHeight))
// `NSWindow(contentRect:styleMask:backing:defer:)` gives the window a content view, and nothing here replaces it.
// swiftlint:disable:next force_unwrapping
window.contentView!.addSubview(button)
button.title = ""
let view = MenuBarIconView(in: button)

window.orderFrontRegardless()
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    // The status bar centres a button that takes its content's size.
}

DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { print(
    "fitting",
    view.fittingSize,
    "intrinsic",
    view.intrinsicContentSize,
    "button",
    button.frame
) }

func icon(_ step: String) -> MenuBarIcon {
    let fields = step.split(separator: ":").map(String.init)
    guard fields.count > 1, let variableValue = fields.count > 2 ? Double(fields[2]) : 1 else {
        FileHandle.standardError.write(Data(usage.utf8))
        exit(1)
    }
    return MenuBarIcon(outputUID: fields[0], symbol: MenuBarSymbol(name: fields[1], variableValue: variableValue))
}

struct Frame {
    let elapsedMs: Int; let ink: Double; let box: String; let centroidY: Double; let centroidX: Double; let png: Data?
}

var frames: [Frame] = []
let start = Date()
/// Reads one window through ScreenCaptureKit at the display's refresh rate; the sums are cheap at 64×44 px, so they run in the callback.
final class Sink: NSObject, SCStreamOutput {
    var first: CMTime?
    var lastHash: Int?
    var calls = 0, complete = 0
    func stream(_: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        calls += 1
        guard type == .screen, let attachments = CMSampleBufferGetSampleAttachmentsArray(
                  buffer,
                  createIfNecessary: false
              ) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue,
              let pixels = CMSampleBufferGetImageBuffer(buffer) else { return }
        complete += 1
        let time = CMSampleBufferGetPresentationTimeStamp(buffer)
        let firstTime = first ?? time
        first = firstTime
        let elapsedMs = Int(((CMTimeGetSeconds(time) - CMTimeGetSeconds(firstTime)) * 1000).rounded())
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        let width = CVPixelBufferGetWidth(pixels), height = CVPixelBufferGetHeight(pixels),
            row = CVPixelBufferGetBytesPerRow(pixels)
        let base = need(CVPixelBufferGetBaseAddress(pixels), "frame at \(elapsedMs) ms has no pixels")
            .assumingMemoryBound(to: UInt8.self)
        var hasher = Hasher(); hasher.combine(Data(bytes: base, count: row * height)); let hash = hasher.finalize()
        if hash == lastHash {
            return
        }
        lastHash = hash
        var sum = 0.0, sumY = 0.0, sumX = 0.0, minX = 9999, maxX = -1, minY = 9999, maxY = -1
        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixel = base + y * row + x * 4
                let brightness = Double(max(pixel[0], pixel[1], pixel[2])) / 255
                if brightness > 0.35 {
                    sum += brightness; sumY += brightness * Double(y); sumX += brightness * Double(x); minX = min(
                        minX,
                        x
                    ); maxX = max(
                        maxX,
                        x
                    ); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        let box = maxX < 0 ? "none" : "\(maxX - minX + 1)x\(maxY - minY + 1) y\(minY)"
        var png: Data?
        if ProcessInfo.processInfo.environment["DUMP"] != nil {
            let provider = need(
                CGDataProvider(data: Data(bytes: base, count: row * height) as CFData),
                "cannot read frame at \(elapsedMs) ms"
            )
            let image = need(CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: row,
                space: need(CGColorSpace(name: CGColorSpace.sRGB), "no sRGB colour space"),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo
                    .byteOrder32Little.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            ), "cannot make an image of frame at \(elapsedMs) ms")
            png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        }
        frames.append(Frame(
            elapsedMs: elapsedMs,
            ink: sum,
            box: box,
            centroidY: sum > 0 ? sumY / sum : 0,
            centroidX: sum > 0 ? sumX / sum : 0,
            png: png
        ))
    }
}

let sink = Sink()
var stream: SCStream?
let ownWindowID = CGWindowID(window.windowNumber)
func startCapture() async throws {
    try await Task.sleep(for: .milliseconds(300))
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    let display = need(content.displays.first { $0.displayID == CGMainDisplayID() }, "no main display to capture")
    let config = SCStreamConfiguration()
    // The window sits at the main display's bottom-left corner; the region is in points with a top-left origin.
    config.sourceRect = CGRect(x: 0, y: Double(display.height) - windowHeight, width: 32, height: windowHeight)
    config.width = 64; config.height = Int(windowHeight * 2)
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.minimumFrameInterval = .zero
    config.showsCursor = false
    config.queueDepth = 8
    let captureStream = SCStream(
        filter: SCContentFilter(display: display, excludingWindows: []),
        configuration: config,
        delegate: nil
    )
    stream = captureStream
    try captureStream.addStreamOutput(
        sink,
        type: .screen,
        sampleHandlerQueue: DispatchQueue(label: "frames", qos: .userInteractive)
    )
    try await captureStream.startCapture()
    print("capturing", display.width, display.height)
}

Task {
    do {
        try await startCapture()
    } catch {
        FileHandle.standardError.write(Data("capture failed: \(error)\n".utf8))
        exit(1)
    }
}

let steps = Array(args.dropFirst(2))
let icons = steps.map(icon)
for (i, step) in steps.enumerated() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * secondsPerStep) {
        print("step \(step) at \(Int(Date().timeIntervalSince(start) * 1000))"); view.show(icons[i])
    }
}

DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(steps.count) * secondsPerStep + 0.5) {
    print("calls", sink.calls, "complete", sink.complete, "distinct", frames.count)
    if let dir = ProcessInfo.processInfo.environment["DUMP"] {
        try? FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        ); for frame in frames {
            try? frame.png?.write(to: URL(fileURLWithPath: dir + String(format: "/f%05d.png", frame.elapsedMs)))
        }
    }
    for frame in frames {
        print(
            frame.elapsedMs,
            String(format: "%.0f", frame.ink),
            frame.box,
            String(format: "c %.1f,%.1f", frame.centroidX, frame.centroidY)
        )
    }; fflush(stdout)
    exit(0)
}

app.run()
