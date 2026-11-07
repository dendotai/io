import AppKit
// glyph <png> <x0> <x1>: ink box at half the brightest ink, the row through the box's middle as #/+/., the brightest colour, and the total ink.
let a = CommandLine.arguments
let r = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: a[1])))!
let x0 = Int(a[2])!, x1 = Int(a[3])!
func b(_ x: Int, _ y: Int) -> Double { r.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!.brightnessComponent }
var top = 0.0; var sum = 0.0
for y in 0..<58 { for x in x0...x1 { let v = b(x, y); top = max(top, v); if v > 0.05 { sum += v } } }
let half = top / 2
var minX = 9999, maxX = -1, minY = 9999, maxY = -1
for y in 0..<58 { for x in x0...x1 where b(x, y) > half { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } }
print(String(format: "box %dx%d at x%d y%d, brightest %.0f, ink %.1f", maxX - minX + 1, maxY - minY + 1, minX, minY, top * 255, sum))
for y in [minY + (maxY - minY) / 2, minY + (maxY - minY) * 3 / 4] {
    print("row", y, (minX...maxX).map { b($0, y) > half ? "#" : (b($0, y) > half / 3 ? "+" : ".") }.joined())
}
