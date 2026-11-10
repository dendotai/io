import AppKit
import Priority

/// One layer of a menu bar symbol as a template image on the whole symbol's canvas, so every piece of a symbol shares one frame and lines up exactly. A piece scales about its own ink centre, as the system's by-layer effects do.
struct MenuBarIconPiece {
    enum Role {
        /// The symbol's heaviest layer: a speaker's body, the headphones under a slash.
        case base
        /// One wave of a speaker.
        case wave
        /// The slash of a slash symbol, which shrinks towards its lower end.
        case slash
        /// Any other layer, as the cups of the AirPods Max.
        case other
    }

    let image: NSImage
    let role: Role
    /// In points from the canvas's bottom-left corner.
    let inkCentre: CGPoint
    /// The lower-right corner of the ink, in the same coordinates.
    let inkEnd: CGPoint
    /// 1 for an active layer; an inactive wave of a speaker draws at the dim the symbol's own rendering uses.
    let opacity: CGFloat
}

enum MenuBarIconPieces {
    /// The Sound icon's ink size, from Size, spacing, and animations in `docs/sound-menu.md`.
    static let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    /// One pure colour per layer for the palette rendering that tells the layers apart, in the symbol's layer order; an edge pixel between two layers blends their colours, and each gets its share. A symbol here has at most three layers.
    private static let palette: [NSColor] = [.red, .green, .blue]

    /// A symbol's pieces, on the canvas of `size` points; `insets` are the image's alignment rect insets, which the status bar centres.
    struct SymbolPieces {
        static let empty = SymbolPieces(pieces: [], size: .zero, insets: NSEdgeInsetsZero)

        let pieces: [MenuBarIconPiece]
        let size: CGSize
        let insets: NSEdgeInsets
    }

    /// The symbol's pieces in drawing order: its base layer first, then its other layers, and a speaker's waves one by one from the body outwards, each at the opacity the symbol's own rendering gives it, as a dim wave at a lower volume or the tips of the AirPods Pro.
    static func pieces(of symbol: MenuBarSymbol, scale: CGFloat) -> SymbolPieces {
        // The pieces come from the symbol with every wave active, so a dim wave is a piece at full alpha with a lower opacity, which a volume change can move.
        guard
            let image = NSImage(
                systemSymbolName: symbol.name,
                variableValue: symbol.variableValue,
                accessibilityDescription: nil
            )?
                .withSymbolConfiguration(configuration),
            let coloured = NSImage(systemSymbolName: symbol.name, variableValue: 1, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration.applying(.init(paletteColors: palette))),
            let plain = render(image, size: image.size, scale: scale),
            let rep = render(coloured, size: image.size, scale: scale),
            let pieces = pieces(of: symbol, layers: layers(in: rep), plain: plain, canvas: image.size, scale: scale)
        else { return .empty }
        let size = image.size
        let aligned = image.alignmentRect
        let insets = NSEdgeInsets(
            top: size.height - aligned.maxY,
            left: aligned.minX,
            bottom: aligned.minY,
            right: size.width - aligned.maxX
        )
        return SymbolPieces(pieces: pieces, size: size, insets: insets)
    }

    /// The palette rendering's pixels, one list per palette colour.
    private static func layers(in rep: NSBitmapImageRep) -> [[Pixel]] {
        var layers: [[Pixel]] = [[], [], []]
        for y in 0 ..< rep.pixelsHigh {
            for x in 0 ..< rep.pixelsWide {
                guard let colour = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      colour.alphaComponent > 0.01 else { continue }
                let shares = [colour.redComponent, colour.greenComponent, colour.blueComponent]
                let total = shares.reduce(0, +)
                guard total > 0 else { continue }
                for (layer, share) in shares.enumerated() where share / total > 0.02 {
                    layers[layer].append(Pixel(x: x, y: y, alpha: colour.alphaComponent * share / total))
                }
            }
        }
        return layers
    }

    /// Nil when AppKit cannot make a piece's image.
    private static func pieces(
        of symbol: MenuBarSymbol,
        layers: [[Pixel]],
        plain: NSBitmapImageRep,
        canvas: CGSize,
        scale: CGFloat
    ) -> [MenuBarIconPiece]? {
        // The base shape leads a symbol's layers: the body of a speaker, the headphones under a slash.
        let ordered = layers.indices.filter { !layers[$0].isEmpty }.sorted { indexA, indexB in
            let inkA = layers[indexA].reduce(0) { $0 + $1.alpha }, inkB = layers[indexB].reduce(0) { $0 + $1.alpha }
            return inkA == inkB ? indexA < indexB : inkA > inkB
        }
        var pieces: [MenuBarIconPiece] = []
        for (index, layer) in ordered.enumerated() {
            let pixels = layers[layer]
            let isWaves = symbol.name.hasPrefix("speaker.wave") && index == 1
            let role: MenuBarIconPiece.Role = index == 0 ? .base : isWaves ? .wave : symbol.name
                .hasSuffix(".slash") || symbol.name.contains(".slash.") ? .slash : .other
            for part in isWaves ? components(pixels) : [pixels] {
                guard let template = templateImage(part, canvas: canvas, scale: scale) else { return nil }
                pieces.append(MenuBarIconPiece(
                    image: template,
                    role: role,
                    inkCentre: inkCentre(part, canvas: canvas, scale: scale),
                    inkEnd: inkEnd(part, canvas: canvas, scale: scale),
                    opacity: opacity(of: part, in: plain)
                ))
            }
        }
        return pieces
    }

    /// The layer's opacity in the plain rendering: the alpha of its solid pixels there. A dim wave is at 0.3, the tips of the AirPods Pro at 0.5.
    private static func opacity(of pixels: [Pixel], in plain: NSBitmapImageRep) -> CGFloat {
        let solid = pixels.filter { $0.alpha > 0.98 }
        guard !solid.isEmpty else { return 1 }
        let ratios = solid.map { (plain.colorAt(x: $0.x, y: $0.y)?.alphaComponent ?? 1) / $0.alpha }.sorted()
        return (ratios[ratios.count / 2] * 100).rounded() / 100
    }

    private struct Pixel {
        let x: Int
        let y: Int
        let alpha: CGFloat
    }

    /// A clear bitmap of `size` points at `scale`; nil when AppKit cannot make one, as for a zero size.
    private static func bitmap(size: CGSize, scale: CGFloat) -> NSBitmapImageRep? {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        rep?.size = size
        return rep
    }

    private static func render(_ image: NSImage, size: CGSize, scale: CGFloat) -> NSBitmapImageRep? {
        guard let rep = bitmap(size: size, scale: scale) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// The layer's connected shapes from left to right, which parts a speaker's waves.
    private static func components(_ pixels: [Pixel]) -> [[Pixel]] {
        var remaining = Dictionary(uniqueKeysWithValues: pixels.map { (Point(x: $0.x, y: $0.y), $0) })
        var parts: [[Pixel]] = []
        while let start = remaining.keys.min(by: { ($0.x, $0.y) < ($1.x, $1.y) }) {
            var part: [Pixel] = []
            var stack = [start]
            remaining.removeValue(forKey: start).map { part.append($0) }
            while let point = stack.popLast() {
                for xOffset in -1 ... 1 {
                    for yOffset in -1 ... 1 {
                        let next = Point(x: point.x + xOffset, y: point.y + yOffset)
                        if let pixel = remaining.removeValue(forKey: next) {
                            part.append(pixel)
                            stack.append(next)
                        }
                    }
                }
            }
            parts.append(part)
        }
        // Each part holds at least its start pixel.
        // swiftlint:disable:next force_unwrapping
        return parts.sorted { $0.map(\.x).min()! < $1.map(\.x).min()! }
    }

    private struct Point: Hashable {
        let x: Int
        let y: Int
    }

    /// The bitmap's rows run from the top; the point is in the canvas's bottom-up coordinates.
    private static func inkCentre(_ pixels: [Pixel], canvas: CGSize, scale: CGFloat) -> CGPoint {
        let ink = pixels.reduce(0) { $0 + $1.alpha }
        let x = pixels.reduce(0) { $0 + CGFloat($1.x) * $1.alpha } / ink
        let y = pixels.reduce(0) { $0 + CGFloat($1.y) * $1.alpha } / ink
        return CGPoint(x: (x + 0.5) / scale, y: canvas.height - (y + 0.5) / scale)
    }

    private static func inkEnd(_ pixels: [Pixel], canvas: CGSize, scale: CGFloat) -> CGPoint {
        // A piece is never empty: `pieces(of:scale:)` skips an empty layer, and each wave holds at least one pixel.
        // swiftlint:disable:next force_unwrapping
        let x = pixels.map(\.x).max()!, y = pixels.map(\.y).max()!
        return CGPoint(x: (CGFloat(x) + 0.5) / scale, y: canvas.height - (CGFloat(y) + 0.5) / scale)
    }

    /// A template image of the canvas size holding only these pixels, so the menu bar tints it as it tints the whole symbol.
    private static func templateImage(_ pixels: [Pixel], canvas: CGSize, scale: CGFloat) -> NSImage? {
        guard let rep = bitmap(size: canvas, scale: scale) else { return nil }
        for pixel in pixels {
            rep.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: pixel.alpha), atX: pixel.x, y: pixel.y)
        }
        let image = NSImage(size: canvas)
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }
}
