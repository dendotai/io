import AppKit
import Priority
import QuartzCore

/// The menu bar icon, an image view inside the status item's button, because in AppKit only `NSImageView` plays symbol transitions (`NSImageView.h`).
final class MenuBarIconView: NSImageView {
    /// The Sound icon's ink size, from Size, spacing, and animations in `docs/sound-menu.md`.
    private static let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    private var shown: MenuBarIcon?
    /// Counts the changes, so a later one wins over the image a replace still waits to show.
    private var scaleGeneration = 0

    init(in button: NSStatusBarButton) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        imageScaling = .scaleNone
        wantsLayer = true
        setAccessibilityElement(false)
        button.addSubview(self)
        // A fixed frame, because a frame that takes each new symbol's size moves the symbol still on screen during a transition.
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

    /// The first image shows at once; a change during a running scale starts from the frame on screen.
    func show(_ icon: MenuBarIcon) {
        guard
            let image = NSImage(systemSymbolName: icon.symbol.name, variableValue: icon.symbol.variableValue, accessibilityDescription: nil)?
                .withSymbolConfiguration(Self.configuration)
        else { return }
        defer { shown = icon }
        guard let shown else {
            self.image = image
            return
        }
        guard let change = icon.change(from: shown) else { return }
        let scale = stopScale()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        switch change {
        // The headphones keep their size as the slash comes and goes, as in the Sound icon.
        case .symbol where icon.symbol.name.hasPrefix("headphones"): setSymbolImage(image, contentTransition: .automatic)
        // Reduce Motion goes to the system transition, which follows it.
        case .output where reduceMotion, .symbol where reduceMotion: setSymbolImage(image, contentTransition: .automatic)
        // A symbol transition draws the old symbol in the new one's frame, which moves it when the two differ in size.
        case .output, .symbol: replace(shown.symbol, with: icon.symbol, image: image, from: scale)
        // Every symbol transition shrinks the icon, while the Sound icon fades the waves to the new volume.
        case .volume:
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.4
            fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
            layer?.add(fade, forKey: "volume")
            self.image = image
        }
    }

    /// Ends a running replace, so its image never shows over a later one, and returns the scale on screen.
    private func stopScale() -> CGFloat {
        scaleGeneration += 1
        let scale = layer?.presentation()?.transform.m11 ?? 1
        layer?.removeAnimation(forKey: "shrink")
        layer?.removeAnimation(forKey: "grow")
        removeAllSymbolEffects(options: .default, animated: false)
        return scale
    }

    /// The old symbol holds, then drops, in place, and the new one appears by layer, so a speaker's waves fill in one by one, as in the Sound icon. The disappear effect hides a symbol at once here, and symbol effects leave an AirPods symbol at full size, so io scales those itself. The lengths are in Size, spacing, and animations in `docs/sound-menu.md`.
    private func replace(_ old: MenuBarSymbol, with new: MenuBarSymbol, image: NSImage, from scale: CGFloat) {
        let generation = scaleGeneration
        let shrink = 0.36
        layer?.add(drop(from: scale, duration: shrink), forKey: "shrink")
        DispatchQueue.main.asyncAfter(deadline: .now() + shrink) { [weak self] in
            guard let self, generation == scaleGeneration else { return }
            self.image = image
            if MenuBarSymbol.isModelSymbol(new.name) {
                let growth = self.scale(from: 0, to: 1, duration: 0.3, timing: .easeOut)
                growth.isRemovedOnCompletion = true
                layer?.add(growth, forKey: "grow")
            } else {
                addSymbolEffect(.appear.up.byLayer, options: .speed(0.4))
            }
            layer?.removeAnimation(forKey: "shrink")
        }
    }

    /// The Sound icon's old symbol keeps nearly its size for about 250 ms, then drops to nothing in about 100 ms.
    private func drop(from scale: CGFloat, duration: CFTimeInterval) -> CAAnimation {
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = [scale, scale * 0.92, 0.001].map { factor in
            var t = CATransform3DMakeTranslation(centre.x, centre.y, 0)
            t = CATransform3DScale(t, factor, factor, 1)
            return CATransform3DTranslate(t, -centre.x, -centre.y, 0)
        }
        animation.keyTimes = [0, 0.7, 1]
        animation.timingFunctions = [CAMediaTimingFunction(name: .easeIn), CAMediaTimingFunction(name: .easeIn)]
        animation.duration = duration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }

    /// AppKit keeps a view's layer anchored at its corner, so the scale moves around the centre by translation.
    private func scale(from: CGFloat, to: CGFloat, duration: CFTimeInterval, timing: CAMediaTimingFunctionName) -> CAAnimation {
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        func transform(_ factor: CGFloat) -> CATransform3D {
            var t = CATransform3DMakeTranslation(centre.x, centre.y, 0)
            t = CATransform3DScale(t, max(factor, 0.001), max(factor, 0.001), 1)
            return CATransform3DTranslate(t, -centre.x, -centre.y, 0)
        }
        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = transform(from)
        animation.toValue = transform(to)
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: timing)
        // The shrunk symbol stays hidden until the new image replaces it.
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }

    /// Clicks belong to the status item.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
