import AppKit

// inkbox <dir>: per frame, the grey ink box (yellow Debug mark excluded) of io's icon (px 105..188) and the Sound icon (px 505..602); with "runs" lists ink column runs of the first frame.

func need<T>(_ value: T?, _ what: @autoclosure () -> String) -> T {
    guard let value else { fatalError(what()) }
    return value
}

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: inkbox <dir> [runs]\n".utf8))
    exit(1)
}

let dir = CommandLine.arguments[1]
func ink(_ frame: NSBitmapImageRep, _ x: Int, _ y: Int) -> Bool {
    let color = need(frame.colorAt(x: x, y: y), "pixel \(x),\(y) is outside the frame")
    let pixel = need(color.usingColorSpace(.sRGB), "pixel \(x),\(y) has no sRGB colour")
    return pixel.brightnessComponent > 0.45 && pixel.saturationComponent < 0.25
}

func box(_ frame: NSBitmapImageRep, _ firstColumn: Int, _ lastColumn: Int) -> String {
    var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
    for y in 0 ..< 58 {
        for x in firstColumn ... lastColumn where ink(frame, x, y) {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(
                maxY,
                y
            )
        }
    }
    return maxX < 0 ? "none" : "x\(minX)-\(maxX) y\(minY)-\(maxY) \(maxX - minX + 1)x\(maxY - minY + 1)"
}

/// The frame's PNG path, from a frames.txt line of "<ms> <file>".
func framePath(_ line: Substring) -> String {
    let fields = line.split(separator: " ")
    guard fields.count > 1 else { fatalError("cannot read frames.txt line \(line)") }
    return dir + "/" + fields[1]
}

let lines = try String(contentsOfFile: dir + "/frames.txt", encoding: .utf8).split(separator: "\n")
if CommandLine.arguments.count > 2 {
    let path = framePath(need(lines.first, "frames.txt is empty"))
    let firstFrame = try need(
        NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: path))),
        "cannot decode \(path)"
    )
    var start: Int?
    for x in 0 ... firstFrame.pixelsWide {
        let hasInk = x < firstFrame.pixelsWide && (0 ..< 58).contains { ink(firstFrame, x, $0) }
        if hasInk, start == nil {
            start = x
        }
        if !hasInk, let runStart = start {
            print("run \(runStart)-\(x - 1)"); start = nil
        }
    }
    exit(0)
}

var last = ""
for line in lines {
    let path = framePath(line)
    let frame = try need(NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: path))), "cannot decode \(path)")
    let summary = "io \(box(frame, 105, 188)) | sound \(box(frame, 505, 602))"
    if summary != last {
        print(line.prefix { $0 != " " }, summary); last = summary
    }
}
