import AppKit
// pieces <symbol> [variable]: splits the symbol at 14 pt medium into its palette layers at 2x, and the waves layer of a speaker by variable value; prints each piece's box and alpha sum, and the sum against the whole symbol in monochrome; writes piece PNGs beside.
let name = CommandLine.arguments[1]
let variable = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2])! : 1
let size14 = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
func render(_ image: NSImage) -> NSBitmapImageRep {
    let size = image.size
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
func alphaSum(_ r: NSBitmapImageRep, where keep: (NSColor) -> Bool = { _ in true }) -> (Double, String) {
    var s = 0.0, minX = 9999, maxX = -1, minY = 9999, maxY = -1
    for y in 0..<r.pixelsHigh { for x in 0..<r.pixelsWide { let c = r.colorAt(x: x, y: y)!; if c.alphaComponent > 0.02 && keep(c) { s += Double(c.alphaComponent); minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } } }
    return (s, maxX < 0 ? "-" : "\(maxX - minX + 1)x\(maxY - minY + 1)@\(minX),\(minY)")
}
let base = NSImage(systemSymbolName: name, variableValue: variable, accessibilityDescription: nil)!.withSymbolConfiguration(size14)!
let mono = render(base)
print("whole", base.size, alphaSum(mono))
let palette: [NSColor] = [.red, .green, .blue, .magenta, .cyan, .yellow]
let pal = render(base.withSymbolConfiguration(size14.applying(.init(paletteColors: palette)))!)
print("palette render", pal.pixelsWide, pal.pixelsHigh)
for k in 0..<6 {
    let (s, box) = alphaSum(pal) { c in
        let (r, g, b) = (c.redComponent > 0.5, c.greenComponent > 0.5, c.blueComponent > 0.5)
        return [r && !g && !b, g && !r && !b, b && !r && !g, r && b && !g, g && b && !r, r && g && !b][k]
    }
    if s > 0 { print("layer \(k)", box, Int(s)) }
}
// A speaker's waves by variable value in draw mode: cumulative renders, each wave is the difference.
if name.hasPrefix("speaker.wave") {
    let draw = size14.applying(.init(variableValueMode: .draw))
    var previous: NSBitmapImageRep?
    for v in [0.0, 0.34, 0.67, 1.0] {
        let r = render(NSImage(systemSymbolName: name, variableValue: v, accessibilityDescription: nil)!.withSymbolConfiguration(draw)!)
        var s = 0.0, minX = 9999, maxX = -1, minY = 9999, maxY = -1
        for y in 0..<r.pixelsHigh { for x in 0..<r.pixelsWide {
            let a = Double(r.colorAt(x: x, y: y)!.alphaComponent) - Double(previous?.colorAt(x: x, y: y)!.alphaComponent ?? 0)
            if a > 0.02 { s += a; minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
        } }
        print("draw v=\(v) new ink \(Int(s)) box \(maxX - minX + 1)x\(maxY - minY + 1)@\(minX),\(minY)")
        previous = r
    }
    // The dim opacity of an inactive wave in colour mode at v=0 against draw mode v=1.
    let dim = render(NSImage(systemSymbolName: name, variableValue: 0, accessibilityDescription: nil)!.withSymbolConfiguration(size14)!)
    let full = render(NSImage(systemSymbolName: name, variableValue: 1, accessibilityDescription: nil)!.withSymbolConfiguration(size14)!)
    var ratios: [Double] = []
    for y in 0..<dim.pixelsHigh { for x in 30..<dim.pixelsWide { let a = Double(full.colorAt(x: x, y: y)!.alphaComponent); if a > 0.9 { ratios.append(Double(dim.colorAt(x: x, y: y)!.alphaComponent) / a) } } }
    print("inactive wave alpha ratio", ratios.min() ?? 0, ratios.max() ?? 0)
}
// The pieces' alpha against the whole symbol's, pixel by pixel.
do {
    let whole = render(base)
    var layersAlpha = [[Double]](repeating: [Double](repeating: 0, count: whole.pixelsWide), count: whole.pixelsHigh)
    for y in 0..<pal.pixelsHigh { for x in 0..<pal.pixelsWide {
        let c = pal.colorAt(x: x, y: y)!
        let (r, g, b) = (c.redComponent > 0.5, c.greenComponent > 0.5, c.blueComponent > 0.5)
        let known = (r && !g && !b) || (g && !r && !b) || (b && !r && !g) || (r && b && !g) || (g && b && !r) || (r && g && !b)
        if c.alphaComponent > 0.01 && known { layersAlpha[y][x] = Double(c.alphaComponent) }
    } }
    var maxDiff = 0.0, lost = 0.0, at = (0, 0)
    for y in 0..<whole.pixelsHigh { for x in 0..<whole.pixelsWide {
        let w = Double(whole.colorAt(x: x, y: y)!.alphaComponent)
        let d = w - layersAlpha[y][x]
        if abs(d) > maxDiff { maxDiff = abs(d); at = (x, y) }
        lost += max(d, 0)
    } }
    print("pieces vs whole: max alpha diff", String(format: "%.2f", maxDiff), "at", at, "alpha lost in total", String(format: "%.1f", lost))
}
