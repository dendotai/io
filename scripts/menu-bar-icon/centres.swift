import AppKit

// centres <dir> <from ms> <until ms> <firstColumn> <lastColumn>: the ink-weighted centre and coverage of one icon per frame.
let args = CommandLine.arguments
let dir = args[1], from = Int(args[2])!, until = Int(args[3])!, firstColumn = Int(args[4])!, lastColumn = Int(args[5])!
for line in try! String(contentsOfFile: dir + "/frames.txt", encoding: .utf8).split(separator: "\n") {
    let fields = line.split(separator: " "); let elapsedMs = Int(fields[0])!
    guard elapsedMs >= from, elapsedMs <= until else { continue }
    let frame = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: dir + "/" + fields[1])))!
    var sum = 0.0, weightedX = 0.0, weightedY = 0.0
    for y in 0 ..<
        58
    {
        for x in firstColumn ...
            lastColumn
        {
            let brightness = frame.colorAt(x: x, y: y)!
                .brightnessComponent; if brightness > 0.35
            {
                sum += brightness; weightedX += brightness * Double(x); weightedY += brightness * Double(y)
            }
        }
    }
    print(
        elapsedMs,
        String(format: "%.0f %.1f,%.1f", sum, sum > 0 ? weightedX / sum : 0, sum > 0 ? weightedY / sum : 0)
    )
}
