import AppKit

// bands <dir> <x0-x1> [<x0-x1> …]: per frame PNG in the directory (sorted), the ink (brightness > 0.35) in each column band, and the box of the first band.
let a = CommandLine.arguments
let dir = a[1]
let bands = a.dropFirst(2).map { s -> (Int, Int) in let p = s.split(separator: "-"); return (Int(p[0])!, Int(p[1])!) }
let files = try! FileManager.default.contentsOfDirectory(atPath: dir).filter { $0.hasSuffix(".png") }.sorted()
var prev = ""
for f in files {
    let r = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: dir + "/" + f)))!
    var out: [String] = []
    for (x0, x1) in bands {
        var sum = 0.0, minX = 9999, maxX = -1, minY = 9999, maxY = -1
        for y in 0 ..< r
            .pixelsHigh
        {
            for x in max(x0, 0) ...
                min(x1, r.pixelsWide - 1)
            {
                let b = r.colorAt(x: x, y: y)!.brightnessComponent; if b > 0.35 {
                    sum += b; minX = min(
                        minX,
                        x
                    ); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        out
            .append(String(format: "%.0f", sum) +
                (maxX < 0 ? "(-)" : "(\(maxX - minX + 1)x\(maxY - minY + 1)@\(minX),\(minY))"))
    }
    let line = out.joined(separator: " ")
    if line != prev {
        print(f.dropFirst(1).prefix(5), line)
    }
    prev = line
}
