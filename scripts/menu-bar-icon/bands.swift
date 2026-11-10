import AppKit

// bands <dir> <firstColumn-lastColumn> [<firstColumn-lastColumn> …]: per frame PNG in the directory (sorted), the ink (brightness > 0.35) in each column band, and the box of the first band.
let args = CommandLine.arguments
func need<T>(_ value: T?, _ what: @autoclosure () -> String) -> T {
    guard let value else { fatalError(what()) }
    return value
}

let bands = args.dropFirst(2).compactMap { band -> (Int, Int)? in
    let ends = band.split(separator: "-")
    guard ends.count == 2, let firstColumn = Int(ends[0]), let lastColumn = Int(ends[1]) else { return nil }
    return (firstColumn, lastColumn)
}

guard args.count > 2, bands.count == args.count - 2 else {
    FileHandle.standardError
        .write(Data("usage: bands <dir> <firstColumn-lastColumn> [<firstColumn-lastColumn> …]\n".utf8))
    exit(1)
}

let dir = args[1]
let files = try FileManager.default.contentsOfDirectory(atPath: dir).filter { $0.hasSuffix(".png") }.sorted()
var prev = ""
for file in files {
    let path = dir + "/" + file
    let frame = try need(NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: path))), "cannot decode \(path)")
    var out: [String] = []
    for (firstColumn, lastColumn) in bands {
        var sum = 0.0, minX = 9999, maxX = -1, minY = 9999, maxY = -1
        for y in 0 ..< frame.pixelsHigh {
            for x in max(firstColumn, 0) ... min(lastColumn, frame.pixelsWide - 1) {
                let brightness = need(frame.colorAt(x: x, y: y), "pixel \(x),\(y) is outside \(path)")
                    .brightnessComponent
                if brightness > 0.35 {
                    sum += brightness; minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(
                        maxY,
                        y
                    )
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
