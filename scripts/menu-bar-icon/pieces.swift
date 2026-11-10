import AppKit

// pieces <symbol> [variable]: splits the symbol at 14 pt medium into its palette layers at 2x, and the waves layer of a speaker by variable value; prints each piece's box and alpha sum, and the sum against the whole symbol in monochrome; writes piece PNGs beside.

func need<T>(_ value: T?, _ what: @autoclosure () -> String) -> T {
    guard let value else { fatalError(what()) }
    return value
}

func colour(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) -> NSColor {
    need(bitmap.colorAt(x: x, y: y), "pixel \(x),\(y) is outside the render")
}

let args = CommandLine.arguments
guard args.count > 1, let variable = args.count > 2 ? Double(args[2]) : 1 else {
    FileHandle.standardError.write(Data("usage: pieces <symbol> [variable]\n".utf8))
    exit(1)
}

let name = args[1]
let size14 = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
func render(_ image: NSImage) -> NSBitmapImageRep {
    let size = image.size
    let rep = need(NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * 2),
        pixelsHigh: Int(size.height * 2),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), "cannot make a bitmap for \(size)")
    rep.size = size
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func alphaSum(_ bitmap: NSBitmapImageRep, where keep: (NSColor) -> Bool) -> (Double, String) {
    var alphaTotal = 0.0, minX = 9999, maxX = -1, minY = 9999, maxY = -1
    for y in 0 ..< bitmap
        .pixelsHigh
    {
        for x in 0 ..< bitmap
            .pixelsWide
        {
            let color = colour(bitmap, x, y); if color
                .alphaComponent > 0.02,
                keep(color)
            {
                alphaTotal += Double(color.alphaComponent); minX = min(
                    minX,
                    x
                ); maxX = max(maxX, x); minY = min(minY, y); maxY = max(
                    maxY,
                    y
                )
            }
        }
    }
    return (alphaTotal, maxX < 0 ? "-" : "\(maxX - minX + 1)x\(maxY - minY + 1)@\(minX),\(minY)")
}

let base = need(
    NSImage(systemSymbolName: name, variableValue: variable, accessibilityDescription: nil)?
        .withSymbolConfiguration(size14),
    "no symbol \(name)"
)
let mono = render(base)
print("whole", base.size, alphaSum(mono) { _ in true })
let palette: [NSColor] = [.red, .green, .blue, .magenta, .cyan, .yellow]
let pal = render(need(
    base.withSymbolConfiguration(size14.applying(.init(paletteColors: palette))),
    "cannot apply the palette to \(name)"
))
print("palette render", pal.pixelsWide, pal.pixelsHigh)
for layer in 0 ..< 6 {
    let (alphaTotal, box) = alphaSum(pal) { color in
        let (isRed, isGreen, isBlue) = (color.redComponent > 0.5, color.greenComponent > 0.5, color.blueComponent > 0.5)
        return [
            isRed && !isGreen && !isBlue,
            isGreen && !isRed && !isBlue,
            isBlue && !isRed && !isGreen,
            isRed && isBlue && !isGreen,
            isGreen && isBlue && !isRed,
            isRed && isGreen && !isBlue,
        ][layer]
    }
    if alphaTotal > 0 {
        print("layer \(layer)", box, Int(alphaTotal))
    }
}

// A speaker's waves by variable value in draw mode: cumulative renders, each wave is the difference.
if name.hasPrefix("speaker.wave") {
    let draw = size14.applying(.init(variableValueMode: .draw))
    var previous: NSBitmapImageRep?
    for variableValue in [0.0, 0.34, 0.67, 1.0] {
        let bitmap = render(need(
            NSImage(systemSymbolName: name, variableValue: variableValue, accessibilityDescription: nil)?
                .withSymbolConfiguration(draw),
            "cannot draw \(name) at \(variableValue)"
        ))
        var newInk = 0.0, minX = 9999, maxX = -1, minY = 9999, maxY = -1
        for y in 0 ..< bitmap.pixelsHigh {
            for x in 0 ..< bitmap.pixelsWide {
                let addedAlpha = Double(colour(bitmap, x, y)
                    .alphaComponent) -
                    Double(previous
                        .map { colour($0, x, y).alphaComponent } ??
                        0)
                if addedAlpha > 0.02 {
                    newInk += addedAlpha; minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(
                        maxY,
                        y
                    )
                }
            }
        }
        print(
            "draw v=\(variableValue) new ink \(Int(newInk)) box \(maxX - minX + 1)x\(maxY - minY + 1)@\(minX),\(minY)"
        )
        previous = bitmap
    }
    // The dim opacity of an inactive wave in colour mode at v=0 against draw mode v=1.
    let dim = render(need(
        NSImage(systemSymbolName: name, variableValue: 0, accessibilityDescription: nil)?
            .withSymbolConfiguration(size14),
        "cannot draw \(name) at 0"
    ))
    let full = render(need(
        NSImage(systemSymbolName: name, variableValue: 1, accessibilityDescription: nil)?
            .withSymbolConfiguration(size14),
        "cannot draw \(name) at 1"
    ))
    var ratios: [Double] = []
    for y in 0 ..< dim
        .pixelsHigh
    {
        for x in 30 ..< dim
            .pixelsWide
        {
            let fullAlpha = Double(colour(full, x, y)
                .alphaComponent); if fullAlpha > 0.9
            {
                ratios
                    .append(Double(colour(dim, x, y)
                            .alphaComponent) / fullAlpha)
            }
        }
    }
    print("inactive wave alpha ratio", ratios.min() ?? 0, ratios.max() ?? 0)
}

// The pieces' alpha against the whole symbol's, pixel by pixel.
do {
    let whole = render(base)
    var layersAlpha = [[Double]](repeating: [Double](repeating: 0, count: whole.pixelsWide), count: whole.pixelsHigh)
    for y in 0 ..< pal.pixelsHigh {
        for x in 0 ..< pal.pixelsWide {
            let color = colour(pal, x, y)
            let (isRed, isGreen, isBlue) = (
                color.redComponent > 0.5,
                color.greenComponent > 0.5,
                color.blueComponent > 0.5
            )
            let known = (isRed && !isGreen && !isBlue) || (isGreen && !isRed && !isBlue) ||
                (isBlue && !isRed && !isGreen) || (isRed && isBlue && !isGreen) || (isGreen && isBlue && !isRed) ||
                (isRed && isGreen && !isBlue)
            if color.alphaComponent > 0.01, known {
                layersAlpha[y][x] = Double(color.alphaComponent)
            }
        }
    }
    var maxDiff = 0.0, lost = 0.0, maxDiffAt = (0, 0)
    for y in 0 ..< whole.pixelsHigh {
        for x in 0 ..< whole.pixelsWide {
            let wholeAlpha = Double(colour(whole, x, y)
                .alphaComponent)
            let alphaDiff = wholeAlpha - layersAlpha[y][x]
            if abs(alphaDiff) > maxDiff {
                maxDiff = abs(alphaDiff); maxDiffAt = (x, y)
            }
            lost += max(alphaDiff, 0)
        }
    }
    print(
        "pieces vs whole: max alpha diff",
        String(format: "%.2f", maxDiff),
        "at",
        maxDiffAt,
        "alpha lost in total",
        String(format: "%.1f", lost)
    )
}
