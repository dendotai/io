import AppKit
import Priority
import QuartzCore

/// The menu bar icon, an image view inside the status item's button, because in AppKit only `NSImageView` plays symbol transitions (`NSImageView.h`).
final class MenuBarIconView: NSImageView {
    /// The Sound icon's ink size, from Size, spacing, and animations in `docs/sound-menu.md`.
    private static let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    private var shown: MenuBarIcon?
    /// Counts the scale animations, so a later change wins over the image an earlier one still waits to show.
    private var scaleGeneration = 0

    init(in button: NSStatusBarButton) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        imageScaling = .scaleNone
        wantsLayer = true
        setAccessibilityElement(false)
        button.addSubview(self)
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: button.centerXAnchor),
            centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// The first image shows at once; a change during a running transition starts from the frame on screen.
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
        switch icon.change(from: shown) {
        case nil: break
        // Symbol transitions leave an AirPods symbol at full size, where the Sound icon shrinks and grows it as any other.
        // Reduce Motion goes to the system transition, which follows it.
        case .output where (DeviceSymbol.isAirPods(icon.symbol.name) || DeviceSymbol.isAirPods(shown.symbol.name)) && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion:
            scaleReplace(with: image)
        // The speaker's waves fill in one by one, as in the Sound icon.
        case .output: setSymbolImage(image, contentTransition: .replace.downUp.byLayer)
        case .symbol: setSymbolImage(image, contentTransition: .automatic)
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

    /// The lengths come from recordings beside the Sound icon (Size, spacing, and animations in `docs/sound-menu.md`), where its whole change takes about 420 ms.
    private func scaleReplace(with image: NSImage) {
        scaleGeneration += 1
        let generation = scaleGeneration
        layer?.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, generation == scaleGeneration else { return }
            self.image = image
            superview?.layoutSubtreeIfNeeded()
            layer?.removeAllAnimations()
            let grow = scale(from: 0, to: 1, duration: 0.25, timing: .easeOut)
            grow.isRemovedOnCompletion = true
            layer?.add(grow, forKey: "grow")
        }
        layer?.add(scale(from: 1, to: 0, duration: 0.2, timing: .easeIn), forKey: "shrink")
        CATransaction.commit()
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
