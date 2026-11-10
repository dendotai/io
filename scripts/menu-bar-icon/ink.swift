import AppKit

/// Renders each symbol at 2x and prints its ink box (alpha > threshold) in px.
let symbols: [(String, Double)] = [
    ("speaker.slash.fill", 1),
    ("speaker.wave.3.fill", 0.34),
    ("speaker.wave.3.fill", 1),
    ("headphones", 1),
    ("headphones.slash", 1),
    ("airpods.pro", 1),
    ("airpods.max", 1),
]
func need<T>(_ value: T?, _ what: @autoclosure () -> String) -> T {
    guard let value else { fatalError(what()) }
    return value
}

let args = CommandLine.arguments
let pointSize = args.count > 1 ? Double(args[1]) : nil
guard args.count > 1, args[1] == "default" || pointSize != nil,
      let threshold = Int(args.count > 2 ? args[2] : "64")
else {
    FileHandle.standardError.write(Data("usage: ink <pointSize|default> [threshold]\n".utf8))
    exit(1)
}

/// The ink's size in pixels at 2x, and the image's size in points.
struct InkBox {
    let inkWidth: Int
    let inkHeight: Int
    let imageWidth: Double
    let imageHeight: Double
}

func ink(_ name: String, _ variableValue: Double, _ config: NSImage.SymbolConfiguration?) -> InkBox {
    var img = need(
        NSImage(systemSymbolName: name, variableValue: variableValue, accessibilityDescription: nil),
        "no symbol \(name)"
    )
    if let config {
        img = need(img.withSymbolConfiguration(config), "cannot configure \(name)")
    }
    let width = Int(img.size.width * 2) + 4, height = Int(img.size.height * 2) + 4
    let rep = need(NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), "cannot make a \(width)x\(height) bitmap")
    rep.size = NSSize(width: Double(width) / 2, height: Double(height) / 2)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 1, y: 1, width: img.size.width, height: img.size.height))
    NSGraphicsContext.restoreGraphicsState()
    var minX = width, maxX = -1, minY = height, maxY = -1
    for y in 0 ..< height {
        for x in 0 ..< width
            where Int(need(rep.colorAt(x: x, y: y), "pixel \(x),\(y) is outside the render").alphaComponent * 255) >
            threshold
        {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    return InkBox(
        inkWidth: maxX - minX + 1,
        inkHeight: maxY - minY + 1,
        imageWidth: img.size.width,
        imageHeight: img.size.height
    )
}

let arg = args[1]
let config = pointSize.map { NSImage.SymbolConfiguration(pointSize: $0, weight: .regular) }
for (name, variableValue) in symbols {
    let inkBox = ink(name, variableValue, config); print(
        arg,
        name,
        variableValue,
        "\(inkBox.inkWidth)x\(inkBox.inkHeight)",
        "pt \(inkBox.imageWidth)x\(inkBox.imageHeight)"
    )
}
