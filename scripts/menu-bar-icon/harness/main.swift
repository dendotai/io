import AppKit
import CoreMedia
import Priority
import ScreenCaptureKit

// harness <seconds> <steps…>: a 32×22 window at the screen's bottom-left corner holds the real MenuBarIconView; each step "<outputUID>:<symbol>[:<variable>]" is shown 1 s apart; frames are captured at 120 Hz from the window and summed as ink (brightness > 0.35 at 2x), with the ink box and the centre, one line per distinct frame.
let args = CommandLine.arguments
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let env = ProcessInfo.processInfo.environment
let windowHeight = Double(env["WINDOW_H"] ?? "22")!, hostY = Double(env["HOST_Y"] ?? "0")!,
    hostHeight = Double(env["HOST_H"] ?? "22")!
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
    let p = step.split(separator: ":").map(String.init)
    return MenuBarIcon(
        outputUID: p[0],
        symbol: MenuBarSymbol(name: p[1], variableValue: p.count > 2 ? Double(p[2])! : 1)
    )
}

struct Frame { let ms: Int; let ink: Double; let box: String; let cy: Double; let cx: Double; let png: Data? }
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
        if first == nil {
            first = time
        }
        let ms = Int(((CMTimeGetSeconds(time) - CMTimeGetSeconds(first!)) * 1000).rounded())
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        let w = CVPixelBufferGetWidth(pixels), h = CVPixelBufferGetHeight(pixels),
            row = CVPixelBufferGetBytesPerRow(pixels)
        let base = CVPixelBufferGetBaseAddress(pixels)!.assumingMemoryBound(to: UInt8.self)
        var hasher = Hasher(); hasher.combine(Data(bytes: base, count: row * h)); let hash = hasher.finalize()
        if hash == lastHash {
            return
        }
        lastHash = hash
        var sum = 0.0, sy = 0.0, sx = 0.0, minX = 9999, maxX = -1, minY = 9999, maxY = -1
        for y in 0 ..< h {
            for x in 0 ..< w {
                let p = base + y * row + x * 4
                let b = Double(max(p[0], p[1], p[2])) / 255
                if b > 0.35 {
                    sum += b; sy += b * Double(y); sx += b * Double(x); minX = min(minX, x); maxX = max(
                        maxX,
                        x
                    ); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        let box = maxX < 0 ? "none" : "\(maxX - minX + 1)x\(maxY - minY + 1) y\(minY)"
        var png: Data?
        if ProcessInfo.processInfo.environment["DUMP"] != nil {
            let provider = CGDataProvider(data: Data(bytes: base, count: row * h) as CFData)!
            let image = CGImage(
                width: w,
                height: h,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: row,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo
                    .byteOrder32Little.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )!
            png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        }
        frames.append(Frame(
            ms: ms,
            ink: sum,
            box: box,
            cy: sum > 0 ? sy / sum : 0,
            cx: sum > 0 ? sx / sum : 0,
            png: png
        ))
    }
}

let sink = Sink()
var stream: SCStream?
let ownWindowID = CGWindowID(window.windowNumber)
Task {
    try await Task.sleep(for: .milliseconds(300))
    let content = try! await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    let display = content.displays.first { $0.displayID == CGMainDisplayID() }!
    let config = SCStreamConfiguration()
    // The window sits at the main display's bottom-left corner; the region is in points with a top-left origin.
    config.sourceRect = CGRect(x: 0, y: Double(display.height) - windowHeight, width: 32, height: windowHeight)
    config.width = 64; config.height = Int(windowHeight * 2)
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.minimumFrameInterval = .zero
    config.showsCursor = false
    config.queueDepth = 8
    stream = SCStream(
        filter: SCContentFilter(display: display, excludingWindows: []),
        configuration: config,
        delegate: nil
    )
    try stream!.addStreamOutput(
        sink,
        type: .screen,
        sampleHandlerQueue: DispatchQueue(label: "frames", qos: .userInteractive)
    )
    do { try await stream!.startCapture(); print("capturing", display.width, display.height) } catch { print(
        "capture failed",
        error
    ); exit(1) }
}

let steps = Array(args.dropFirst(2))
for (i, step) in steps.enumerated() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * Double(args[1])!) {
        print("step \(step) at \(Int(Date().timeIntervalSince(start) * 1000))"); view.show(icon(step))
    }
}

DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(steps.count) * Double(args[1])! + 0.5) {
    print("calls", sink.calls, "complete", sink.complete, "distinct", frames.count)
    if let dir = ProcessInfo.processInfo.environment["DUMP"] {
        try? FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        ); for f in frames {
            try? f.png?.write(to: URL(fileURLWithPath: dir + String(format: "/f%05d.png", f.ms)))
        }
    }
    for f in frames {
        print(f.ms, String(format: "%.0f", f.ink), f.box, String(format: "c %.1f,%.1f", f.cx, f.cy))
    }; fflush(stdout)
    exit(0)
}

app.run()
