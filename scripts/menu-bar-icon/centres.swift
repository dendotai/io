import AppKit

// centres <dir> <from ms> <until ms> <firstColumn> <lastColumn>: the ink-weighted centre and coverage of one icon per frame.
let args = CommandLine.arguments
func need<T>(_ value: T?, _ what: @autoclosure () -> String) -> T {
    guard let value else { fatalError(what()) }
    return value
}

guard args.count > 5, let from = Int(args[2]), let until = Int(args[3]), let firstColumn = Int(args[4]),
      let lastColumn = Int(args[5])
else {
    FileHandle.standardError.write(Data("usage: centres <dir> <from ms> <until ms> <firstColumn> <lastColumn>\n".utf8))
    exit(1)
}

let dir = args[1]
for line in try String(contentsOfFile: dir + "/frames.txt", encoding: .utf8).split(separator: "\n") {
    let fields = line.split(separator: " "); let elapsedMs = need(Int(fields[0]), "cannot read frames.txt line \(line)")
    guard elapsedMs >= from, elapsedMs <= until else { continue }
    let path = dir + "/" + fields[1]
    let frame = try need(NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: path))), "cannot decode \(path)")
    var sum = 0.0, weightedX = 0.0, weightedY = 0.0
    for y in 0 ..< 58 {
        for x in firstColumn ... lastColumn {
            let brightness = need(frame.colorAt(x: x, y: y), "pixel \(x),\(y) is outside \(path)").brightnessComponent
            if brightness > 0.35 {
                sum += brightness; weightedX += brightness * Double(x); weightedY += brightness * Double(y)
            }
        }
    }
    print(
        elapsedMs,
        String(format: "%.0f %.1f,%.1f", sum, sum > 0 ? weightedX / sum : 0, sum > 0 ? weightedY / sum : 0)
    )
}
