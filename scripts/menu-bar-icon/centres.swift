import AppKit
// centres <dir> <from ms> <to ms> <x0> <x1>: the ink-weighted centre and coverage of one icon per frame.
let a = CommandLine.arguments
let dir = a[1], from = Int(a[2])!, to = Int(a[3])!, x0 = Int(a[4])!, x1 = Int(a[5])!
for l in try! String(contentsOfFile: dir + "/frames.txt", encoding: .utf8).split(separator: "\n") {
    let p = l.split(separator: " "); let ms = Int(p[0])!
    guard ms >= from, ms <= to else { continue }
    let r = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: dir + "/" + p[1])))!
    var sum = 0.0, sx = 0.0, sy = 0.0
    for y in 0..<58 { for x in x0...x1 { let b = r.colorAt(x: x, y: y)!.brightnessComponent; if b > 0.35 { sum += b; sx += b * Double(x); sy += b * Double(y) } } }
    print(ms, String(format: "%.0f %.1f,%.1f", sum, sum > 0 ? sx / sum : 0, sum > 0 ? sy / sum : 0))
}
