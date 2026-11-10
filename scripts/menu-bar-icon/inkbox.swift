import AppKit

// inkbox <dir>: per frame, the grey ink box (yellow Debug mark excluded) of io's icon (px 105..188) and the Sound icon (px 505..602); with "runs" lists ink column runs of the first frame.
let dir = CommandLine.arguments[1]
func ink(_ r: NSBitmapImageRep, _ x: Int, _ y: Int) -> Bool {
    let c = r.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
    return c.brightnessComponent > 0.45 && c.saturationComponent < 0.25
}

func box(_ r: NSBitmapImageRep, _ x0: Int, _ x1: Int) -> String {
    var a = Int.max, b = -1, c = Int.max, d = -1
    for y in 0 ..< 58 {
        for x in x0 ... x1 where ink(r, x, y) {
            a = min(a, x); b = max(b, x); c = min(c, y); d = max(
                d,
                y
            )
        }
    }
    return b < 0 ? "none" : "x\(a)-\(b) y\(c)-\(d) \(b - a + 1)x\(d - c + 1)"
}

let lines = try! String(contentsOfFile: dir + "/frames.txt", encoding: .utf8).split(separator: "\n")
if CommandLine.arguments.count > 2 {
    let r =
        NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: dir + "/" + lines[0]
                .split(separator: " ")[1])))!
    var start: Int?
    for x in 0 ... r.pixelsWide {
        let on = x < r.pixelsWide && (0 ..< 58).contains { ink(r, x, $0) }
        if on, start == nil {
            start = x
        }
        if !on, let s = start {
            print("run \(s)-\(x - 1)"); start = nil
        }
    }
    exit(0)
}

var last = ""
for l in lines {
    let p = l.split(separator: " ")
    let r = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: dir + "/" + p[1])))!
    let s = "io \(box(r, 105, 188)) | sound \(box(r, 505, 602))"
    if s != last {
        print(p[0], s); last = s
    }
}
