import AppKit
import Priority

/// The menu bar icon, an image view inside the status item's button, because in AppKit only `NSImageView` plays symbol transitions (`NSImageView.h`).
final class MenuBarIconView: NSImageView {
    /// The Sound icon's ink size, from Size, spacing, and animations in `docs/sound-menu.md`.
    private static let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    private var shown: MenuBarIcon?

    init(in button: NSStatusBarButton) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        imageScaling = .scaleNone
        setAccessibilityElement(false)
        button.setAccessibilityLabel("io")
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
        case .output: setSymbolImage(image, contentTransition: .replace.downUp.byLayer)
        case .symbol: setSymbolImage(image, contentTransition: .automatic)
        // Every symbol transition shrinks the icon, while the Sound icon swaps the waves at once.
        case .level: self.image = image
        }
    }

    /// Clicks belong to the status item.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
