import AppKit

// glyph <png> <firstColumn> <lastColumn>: ink box at half the brightest ink, the row through the box's middle as #/+/., the brightest colour, and the total ink.
let args = CommandLine.arguments
let bitmap = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: args[1])))!
let firstColumn = Int(args[2])!, lastColumn = Int(args[3])!
func brightnessAt(_ x: Int, _ y: Int) -> Double {
    bitmap.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!.brightnessComponent
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
