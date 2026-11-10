import AppKit

// inkbox <dir>: per frame, the grey ink box (yellow Debug mark excluded) of io's icon (px 105..188) and the Sound icon (px 505..602); with "runs" lists ink column runs of the first frame.
let dir = CommandLine.arguments[1]
func ink(_ frame: NSBitmapImageRep, _ x: Int, _ y: Int) -> Bool {
    let pixel = frame.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
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

let lines = try! String(contentsOfFile: dir + "/frames.txt", encoding: .utf8).split(separator: "\n")
if CommandLine.arguments.count > 2 {
    let firstFrame =
        NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: dir + "/" + lines[0]
                .split(separator: " ")[1])))!
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
    let fields = line.split(separator: " ")
    let frame = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: dir + "/" + fields[1])))!
    let summary = "io \(box(frame, 105, 188)) | sound \(box(frame, 505, 602))"
    if summary != last {
        print(fields[0], summary); last = summary
    }
}
