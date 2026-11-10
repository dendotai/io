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
let threshold = Int(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "64")!
func ink(_ name: String, _ variableValue: Double,
         _ config: NSImage.SymbolConfiguration?) -> (Int, Int, Double, Double)
{
    var img = NSImage(systemSymbolName: name, variableValue: variableValue, accessibilityDescription: nil)!
    if let config {
        img = img.withSymbolConfiguration(config)!
    }
    let width = Int(img.size.width * 2) + 4, height = Int(img.size.height * 2) + 4
    let rep = NSBitmapImageRep(
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
    )!
    rep.size = NSSize(width: Double(width) / 2, height: Double(height) / 2)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 1, y: 1, width: img.size.width, height: img.size.height))
    NSGraphicsContext.restoreGraphicsState()
    var minX = width, maxX = -1, minY = height, maxY = -1
    for y in 0 ..<
        height
    {
        for x in 0 ..< width {
            if Int(rep.colorAt(x: x, y: y)!.alphaComponent * 255) > threshold {
                minX = min(
                    minX,
                    x
                ); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
    }
    return (maxX - minX + 1, maxY - minY + 1, img.size.width, img.size.height)
}

let arg = CommandLine.arguments[1]
let config: NSImage.SymbolConfiguration? = arg == "default" ? nil : NSImage.SymbolConfiguration(
    pointSize: Double(arg)!,
    weight: .regular
)
for (name, variableValue) in symbols {
    let inkBox = ink(name, variableValue, config); print(
        arg,
        name,
        variableValue,
        "\(inkBox.0)x\(inkBox.1)",
        "pt \(inkBox.2)x\(inkBox.3)"
    )
}
