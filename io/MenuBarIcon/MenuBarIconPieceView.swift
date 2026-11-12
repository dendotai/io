import AppKit
import QuartzCore

/// One layer of the menu bar icon's symbol, scaled about its ink centre.
final class MenuBarIconPieceView: NSImageView {
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
    required init?(coder _: NSCoder) {
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
        let clampedFactor = max(factor, 0.001)
        var matrix = CATransform3DMakeTranslation(point.x, point.y, 0)
        matrix = CATransform3DScale(matrix, clampedFactor, clampedFactor, 1)
        return CATransform3DTranslate(matrix, -point.x, -point.y, 0)
    }

    /// Scales from the size on screen down to `scale` about the point, then hides, so the layer stays at full size until its turn.
    func shrink(
        to scale: CGFloat,
        about point: CGPoint,
        delay: TimeInterval,
        duration: TimeInterval,
        timing: CAMediaTimingFunction
    ) {
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
    func spring(from start: CGFloat, to scale: CGFloat, duration: TimeInterval) {
        let animation = CASpringAnimation(keyPath: "transform")
        animation.fromValue = transform(start, about: piece.inkCentre)
        animation.toValue = transform(scale, about: piece.inkCentre)
        animation.mass = 1
        animation.stiffness = 180
        animation.damping = 12
        animation.initialVelocity = 0
        animation.duration = duration
        layer?.transform = transform(scale, about: piece.inkCentre)
        layer?.add(animation, forKey: "scale")
    }

    func animateOpacity(
        to opacity: CGFloat,
        duration: TimeInterval,
        timing: CAMediaTimingFunctionName
    ) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = (layer?.presentation() ?? layer)?.opacity
        animation.toValue = Float(opacity)
        animation.beginTime = CACurrentMediaTime()
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: timing)
        animation.fillMode = .backwards
        layer?.opacity = Float(opacity)
        layer?.add(animation, forKey: "opacity")
    }
}
