import AppKit

// glyph <png> <firstColumn> <lastColumn>: ink box at half the brightest ink, the row through the box's middle as #/+/., the brightest colour, and the total ink.
let args = CommandLine.arguments
func need<T>(_ value: T?, _ what: @autoclosure () -> String) -> T {
    guard let value else { fatalError(what()) }
    return value
}

guard args.count > 3, let firstColumn = Int(args[2]), let lastColumn = Int(args[3]) else {
    FileHandle.standardError.write(Data("usage: glyph <png> <firstColumn> <lastColumn>\n".utf8))
    exit(1)
}

let bitmap = try need(
    NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: args[1]))),
    "cannot decode \(args[1])"
)
func brightnessAt(_ x: Int, _ y: Int) -> Double {
    let color = need(bitmap.colorAt(x: x, y: y), "pixel \(x),\(y) is outside \(args[1])")
    return need(color.usingColorSpace(.sRGB), "pixel \(x),\(y) has no sRGB colour").brightnessComponent
}

var top = 0.0; var sum = 0.0
for y in 0 ..< 58 {
    for x in firstColumn ... lastColumn {
        let brightness = brightnessAt(x, y); top = max(top, brightness); if brightness > 0.05 {
            sum += brightness
        }
    }
}

let half = top / 2
var minX = 9999, maxX = -1, minY = 9999, maxY = -1
for y in 0 ..< 58 {
    for x in firstColumn ... lastColumn where brightnessAt(x, y) > half {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(
            minY,
            y
        ); maxY = max(maxY, y)
    }
}

print(String(
    format: "box %dx%d at x%d y%d, brightest %.0f, ink %.1f",
    maxX - minX + 1,
    maxY - minY + 1,
    minX,
    minY,
    top * 255,
    sum
))
for y in [minY + (maxY - minY) / 2, minY + (maxY - minY) * 3 / 4] {
    print(
        "row",
        y,
        (minX ... maxX).map { brightnessAt($0, y) > half ? "#" : (brightnessAt($0, y) > half / 3 ? "+" : ".") }.joined()
    )
}
