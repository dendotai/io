import AppKit
import Priority
import QuartzCore

/// The menu bar icon: one template image view per symbol layer inside the status item's button, animated by Core Animation. The system's symbol effects commit a frame from io's process for each step, and the menu bar blocks those commits for about 700 ms after an output change while its own Sound icon changes, so they stall; the render server plays a Core Animation animation on its own (`scripts/menu-bar-icon/README.md`).
final class MenuBarIconView: NSView {
    private var shown: MenuBarIcon?
    /// The shown symbol's pieces, in `MenuBarIconPieces` order.
    private var pieces: [PieceView] = []
    private var outgoing: [PieceView] = []
    /// Counts the changes, so a later one wins over the pieces an earlier change still waits to remove.
    private var generation = 0

    init(in button: NSStatusBarButton) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        setAccessibilityElement(false)
        button.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: button.leadingAnchor),
            trailingAnchor.constraint(equalTo: button.trailingAnchor),
            topAnchor.constraint(equalTo: button.topAnchor),
            bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// The first image shows at once; a change during a running transition starts from the frame on screen. The transitions and their lengths are in Size, spacing, and animations in `docs/sound-menu.md`.
    func show(_ icon: MenuBarIcon) {
        defer { shown = icon }
        guard let shown else {
            pieces = make(icon.symbol)
            return
        }
        guard let change = icon.change(from: shown) else { return }
        generation += 1
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        switch change {
        // The Sound icon fades the waves to the new volume; the pieces are the same, so only the waves' opacity moves.
        case .volume:
            let new = MenuBarIconPieces.pieces(of: icon.symbol, scale: scale).pieces
            for (view, piece) in zip(pieces, new) where view.layer?.opacity != Float(piece.opacity) {
                view.animateOpacity(to: piece.opacity, duration: Transition.fade)
            }
        case .output where reduceMotion, .symbol where reduceMotion:
            crossfade(to: icon.symbol)
        case .output, .symbol:
            replace(with: icon.symbol, magic: Self.isSlashPair(shown.symbol.name, icon.symbol.name))
        }
    }

    /// The lengths, in seconds, and scales of the system's replace by layer, each from the replace paragraph of Size, spacing, and animations in `docs/sound-menu.md`: the old symbol's accents wipe or shrink while its base scales down to about 0.4, where, after an empty frame, the new base takes over and grows out; a slash line shrinks slowly towards its lower end; the headphones' slash springs in and out while the headphones stay.
    private enum Transition {
        static let fade = 0.4
        /// A speaker's waves are erased from their middle row outward over the whole down phase; its body shrinks only at the end.
        static let wavesWipe = 0.225
        /// The erased band's half-height at 0, 0.3, 0.6, 0.9 and 1 of the wipe; the tips still showing at the end hide with the piece.
        static let wipeCurve: [CGFloat] = [0, 0.14, 0.39, 0.62, 0.7]
        static let bodyShrink = 0.1
        static let baseShrink = 0.24
        /// A whole symbol's shrink keeps most of its size for half its length, then drops.
        static let baseShrinkTiming = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.75, 0.5)
        static let slashBodyShrink = 0.28
        static let slashShrink = 0.45
        static let swapScale = 0.4
        /// One frame at 120 Hz shows neither symbol.
        static let swapGap = 0.01
        static let bodyGrow = 0.1
        static let baseGrow = 0.22
        static let wavesGrow = 0.22
        static let slashGrow = 0.3
        /// The growth of an accent reaches half its size in a fifth of its length and then eases out over a long tail: the scale at 0, 0.2, 0.65 and 0.95 of the length.
        static let accentGrowth: [CGFloat] = [0.45, 0.71, 0.95, 0.985]
        static let magicSpring = 0.45
        /// The base crossfades to the base cut by the slash while the slash springs in, slowly at first, so the notch opens as the slash fills it; the slash leaves fast, so the base crossfades back as fast.
        static let magicNotchOpen = 0.3
        static let magicNotchClose = 0.1
    }

    /// The old symbol's layers go in the system's order and lengths, then the new symbol's layers grow from the swap scale. A magic pair keeps its base and springs the slash alone.
    private func replace(with symbol: MenuBarSymbol, magic: Bool) {
        let generation = generation
        let new = make(symbol)
        new.forEach { $0.setScale(0.001) }
        let old = pieces
        pieces = new
        removeOutgoing()
        outgoing = old
        var swap = 0.0
        if magic {
            for view in old where view.piece.role != .base {
                view.spring(to: 0.001, duration: Transition.magicSpring)
            }
        } else {
            let oldIsSlash = old.contains { $0.piece.role == .slash }
            let oldHasWaves = old.contains { $0.piece.role == .wave }
            // One band erases all the waves, so the short inner wave goes first.
            let waveHalfHeight = old.filter { $0.piece.role == .wave }.map { $0.piece.inkCentre.y - $0.piece.inkEnd.y }.max() ?? 0
            for view in old {
                switch view.piece.role {
                case .wave:
                    view.wipe(through: Transition.wipeCurve, halfHeight: waveHalfHeight, delay: 0, duration: Transition.wavesWipe)
                    swap = max(swap, Transition.wavesWipe)
                case .slash:
                    view.shrink(to: 0.001, about: view.piece.inkEnd, delay: 0, duration: Transition.slashShrink)
                    swap = max(swap, Transition.slashShrink)
                case .base, .other:
                    let duration = oldIsSlash ? Transition.slashBodyShrink : oldHasWaves ? Transition.bodyShrink : Transition.baseShrink
                    let delay = oldHasWaves ? Transition.wavesWipe - Transition.bodyShrink : 0
                    let timing = oldIsSlash || oldHasWaves ? CAMediaTimingFunction(name: .easeIn) : Transition.baseShrinkTiming
                    view.shrink(to: Transition.swapScale, about: view.piece.inkCentre, delay: delay, duration: duration, timing: timing)
                    swap = max(swap, delay + duration)
                }
            }
            swap += Transition.swapGap
        }
        let newHasWaves = new.contains { $0.piece.role == .wave }
        for view in new {
            if magic {
                view.setScale(1)
                if view.piece.role == .base, let keptBase = old.first(where: { $0.piece.role == .base }) {
                    // The base under a slash is the base cut by it.
                    let slashIn = new.contains { $0.piece.role == .slash }
                    let duration = slashIn ? Transition.magicNotchOpen : Transition.magicNotchClose
                    let timing: CAMediaTimingFunctionName = slashIn ? .easeIn : .linear
                    let opacity = view.piece.opacity
                    view.layer?.opacity = 0
                    view.animateOpacity(to: opacity, duration: duration, timing: timing)
                    keptBase.animateOpacity(to: 0, duration: duration, timing: timing)
                } else {
                    view.spring(from: 0.001, to: 1, duration: Transition.magicSpring)
                }
                continue
            }
            switch view.piece.role {
            case .base: view.grow(from: Transition.swapScale, delay: swap, duration: newHasWaves ? Transition.bodyGrow : Transition.baseGrow)
            case .other: view.grow(from: Transition.swapScale, delay: swap, duration: Transition.baseGrow)
            case .wave: view.grow(through: Transition.accentGrowth, delay: swap, duration: Transition.wavesGrow)
            case .slash: view.grow(through: Transition.accentGrowth, delay: swap, duration: Transition.slashGrow)
            }
        }
        let end = swap + max(Transition.baseGrow, Transition.wavesGrow, Transition.slashGrow, Transition.magicSpring)
        DispatchQueue.main.asyncAfter(deadline: .now() + end + 0.05) { [weak self] in
            guard let self, generation == self.generation else { return }
            removeOutgoing()
        }
    }

    /// With Reduce Motion the Sound icon fades the old symbol out and the new one in.
    private func crossfade(to symbol: MenuBarSymbol) {
        let generation = generation
        let new = make(symbol)
        let old = pieces
        pieces = new
        removeOutgoing()
        outgoing = old
        for view in new {
            view.layer?.opacity = 0
            view.animateOpacity(to: view.piece.opacity, duration: Transition.fade)
        }
        for view in old {
            view.animateOpacity(to: 0, duration: Transition.fade)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Transition.fade) { [weak self] in
            guard let self, generation == self.generation else { return }
            removeOutgoing()
        }
    }

    private func removeOutgoing() {
        outgoing.forEach { $0.removeFromSuperview() }
        outgoing = []
    }

    /// The symbol's pieces as subviews, on the symbol's own canvas centred in the button, so each symbol sits where an image of it would.
    private func make(_ symbol: MenuBarSymbol) -> [PieceView] {
        let (pieces, size, insets) = MenuBarIconPieces.pieces(of: symbol, scale: scale)
        return pieces.map { piece in
            let view = PieceView(piece: piece, frame: CGRect(origin: canvasOrigin(for: size, insets: insets), size: size), insets: insets)
            addSubview(view)
            return view
        }
    }

    /// The image's alignment rect centred on the button, on the pixel grid at 2x, as the status bar places an image.
    private func canvasOrigin(for size: CGSize, insets: NSEdgeInsets) -> CGPoint {
        let aligned = CGSize(width: size.width - insets.left - insets.right, height: size.height - insets.top - insets.bottom)
        let x = (bounds.width - aligned.width) / 2 - insets.left
        let y = (bounds.height - aligned.height) / 2 - insets.bottom
        return CGPoint(x: (x * 2).rounded() / 2, y: (y * 2).rounded() / 2)
    }

    /// The first symbol shows before the button has its size.
    override func layout() {
        super.layout()
        for view in pieces + outgoing {
            view.frame.origin = canvasOrigin(for: view.frame.size, insets: view.insets)
        }
    }

    private var scale: CGFloat { window?.backingScaleFactor ?? 2 }

    /// `headphones` and `headphones.slash`: the symbol only gains or loses its slash, which the system's magic replace animates alone.
    private static func isSlashPair(_ a: String, _ b: String) -> Bool {
        a == b + ".slash" || b == a + ".slash"
    }

    /// Clicks belong to the status item.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// One layer of the symbol, scaled about its ink centre.
private final class PieceView: NSImageView {
    let piece: MenuBarIconPiece
    let insets: NSEdgeInsets

    init(piece: MenuBarIconPiece, frame: CGRect, insets: NSEdgeInsets) {
        self.piece = piece
        self.insets = insets
        super.init(frame: frame)
        image = piece.image
        imageScaling = .scaleNone
        wantsLayer = true
        layer?.opacity = Float(piece.opacity)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// AppKit keeps a view's layer anchored at its corner, so a scale about a point goes by translation.
    var presentedScale: CGFloat {
        (layer?.presentation() ?? layer)?.transform.m11 ?? 1
    }

    func setScale(_ factor: CGFloat) {
        layer?.transform = transform(factor, about: piece.inkCentre)
    }

    private func transform(_ factor: CGFloat, about point: CGPoint) -> CATransform3D {
        let f = max(factor, 0.001)
        var t = CATransform3DMakeTranslation(point.x, point.y, 0)
        t = CATransform3DScale(t, f, f, 1)
        return CATransform3DTranslate(t, -point.x, -point.y, 0)
    }

    /// Scales from the size on screen down to `scale` about the point, then hides, so the layer stays at full size until its turn.
    func shrink(to scale: CGFloat, about point: CGPoint, delay: TimeInterval, duration: TimeInterval, timing: CAMediaTimingFunction = CAMediaTimingFunction(name: .easeIn)) {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = transform(presentedScale, about: point)
        animation.toValue = transform(scale, about: point)
        animation.beginTime = CACurrentMediaTime() + delay
        animation.duration = duration
        animation.timingFunction = timing
        animation.fillMode = .backwards
        layer?.transform = transform(scale, about: point)
        layer?.add(animation, forKey: "scale")
        hide(at: delay + duration)
    }

    /// Hides the layer at the moment, with no fade.
    private func hide(at delay: TimeInterval) {
        let hide = CABasicAnimation(keyPath: "opacity")
        hide.fromValue = layer?.opacity
        hide.toValue = 0
        hide.beginTime = CACurrentMediaTime() + delay
        hide.duration = 0.001
        hide.fillMode = .backwards
        layer?.opacity = 0
        layer?.add(hide, forKey: "hide")
    }

    /// Grows as a critically damped spring from rest, which settles within the length: the system's base growth fits one within a frame at every sample.
    func grow(from scale: CGFloat, delay: TimeInterval, duration: TimeInterval) {
        let animation = CASpringAnimation(keyPath: "transform")
        animation.fromValue = transform(scale, about: piece.inkCentre)
        animation.toValue = transform(1, about: piece.inkCentre)
        animation.beginTime = CACurrentMediaTime() + delay
        let omega = 6 / duration
        animation.mass = 1
        animation.stiffness = omega * omega
        animation.damping = 2 * omega
        animation.initialVelocity = 0
        animation.duration = animation.settlingDuration
        animation.fillMode = .backwards
        layer?.transform = transform(1, about: piece.inkCentre)
        layer?.add(animation, forKey: "scale")
        // Nothing shows before its turn.
        let show = CABasicAnimation(keyPath: "opacity")
        show.fromValue = 0
        show.toValue = layer?.opacity
        show.beginTime = CACurrentMediaTime() + delay
        show.duration = 0.001
        show.fillMode = .backwards
        layer?.add(show, forKey: "show")
    }

    /// Grows through the scales at the fractions 0, 0.2, 0.65 and 0.95 of the length, then to 1.
    func grow(through scales: [CGFloat], delay: TimeInterval, duration: TimeInterval) {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = (scales + [1]).map { transform($0, about: piece.inkCentre) }
        animation.keyTimes = [0, 0.2, 0.65, 0.95, 1]
        animation.beginTime = CACurrentMediaTime() + delay
        animation.duration = duration
        animation.fillMode = .backwards
        layer?.transform = transform(1, about: piece.inkCentre)
        layer?.add(animation, forKey: "scale")
        let show = CABasicAnimation(keyPath: "opacity")
        show.fromValue = 0
        show.toValue = layer?.opacity
        show.beginTime = CACurrentMediaTime() + delay
        show.duration = 0.001
        show.fillMode = .backwards
        layer?.add(show, forKey: "show")
    }

    /// Erases the piece from the row through its ink centre outward, as the system takes a speaker's waves off: a mask of two bars, one anchored at the top edge and one at the bottom, each losing the fractions of `curve` of `halfHeight` at 0, 0.3, 0.6, 0.9 and 1 of the length.
    func wipe(through curve: [CGFloat], halfHeight: CGFloat, delay: TimeInterval, duration: TimeInterval) {
        guard let layer else { return }
        let mask = CALayer()
        mask.frame = layer.bounds
        let centre = piece.inkCentre.y
        let upper = CALayer(), lower = CALayer()
        upper.anchorPoint = CGPoint(x: 0.5, y: 1)
        upper.frame = CGRect(x: 0, y: centre, width: layer.bounds.width, height: layer.bounds.height - centre)
        lower.anchorPoint = CGPoint(x: 0.5, y: 0)
        lower.frame = CGRect(x: 0, y: 0, width: layer.bounds.width, height: centre)
        for bar in [upper, lower] {
            bar.backgroundColor = CGColor(gray: 1, alpha: 1)
            mask.addSublayer(bar)
            let animation = CAKeyframeAnimation(keyPath: "bounds.size.height")
            animation.values = curve.map { max(bar.bounds.height - halfHeight * $0, 0) }
            animation.keyTimes = [0, 0.3, 0.6, 0.9, 1]
            animation.beginTime = CACurrentMediaTime() + delay
            animation.duration = duration
            animation.fillMode = .backwards
            bar.bounds.size.height = 0
            bar.add(animation, forKey: "wipe")
        }
        layer.mask = mask
        hide(at: delay + duration)
    }

    /// A spring about the ink centre that overshoots a little and settles within the length.
    func spring(from start: CGFloat? = nil, to scale: CGFloat, duration: TimeInterval) {
        let animation = CASpringAnimation(keyPath: "transform")
        animation.fromValue = transform(start ?? presentedScale, about: piece.inkCentre)
        animation.toValue = transform(scale, about: piece.inkCentre)
        animation.mass = 1
        animation.stiffness = 180
        animation.damping = 12
        animation.initialVelocity = 0
        animation.duration = duration
        layer?.transform = transform(scale, about: piece.inkCentre)
        layer?.add(animation, forKey: "scale")
    }

    func animateOpacity(to opacity: CGFloat, duration: TimeInterval, delay: TimeInterval = 0, timing: CAMediaTimingFunctionName = .easeInEaseOut) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = (layer?.presentation() ?? layer)?.opacity
        animation.toValue = Float(opacity)
        animation.beginTime = CACurrentMediaTime() + delay
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: timing)
        animation.fillMode = .backwards
        layer?.opacity = Float(opacity)
        layer?.add(animation, forKey: "opacity")
    }
}
