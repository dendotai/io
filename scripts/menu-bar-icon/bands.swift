import AppKit

// bands <dir> <firstColumn-lastColumn> [<firstColumn-lastColumn> …]: per frame PNG in the directory (sorted), the ink (brightness > 0.35) in each column band, and the box of the first band.
let args = CommandLine.arguments
let dir = args[1]
let bands = args.dropFirst(2).map { band -> (Int, Int) in let ends = band.split(separator: "-"); return (
    Int(ends[0])!,
    Int(ends[1])!
) }
let files = try! FileManager.default.contentsOfDirectory(atPath: dir).filter { $0.hasSuffix(".png") }.sorted()
var prev = ""
for file in files {
    let frame = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: dir + "/" + file)))!
    var out: [String] = []
    for (firstColumn, lastColumn) in bands {
        var sum = 0.0, minX = 9999, maxX = -1, minY = 9999, maxY = -1
        for y in 0 ..< frame
            .pixelsHigh
        {
            for x in max(firstColumn, 0) ...
                min(lastColumn, frame.pixelsWide - 1)
            {
                let brightness = frame.colorAt(x: x, y: y)!.brightnessComponent; if brightness > 0.35 {
                    sum += brightness; minX = min(
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
        print(file.dropFirst(1).prefix(5), line)
    }
    prev = line
}
