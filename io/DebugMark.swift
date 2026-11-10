#if DEBUG
    import AppKit

    /// A dot over the menu bar icon, not part of its image, so the icon's own pixels stay comparable with the Sound icon. `defaults write ai.den.io hideDebugMark -bool true` hides it at once, and `defaults delete ai.den.io hideDebugMark` shows it again.
    final class DebugMark: NSObject {
        private static let hideKey = "hideDebugMark"
        private let dot = DotView()

        init(on button: NSStatusBarButton) {
            super.init()
            button.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 5),
                dot.heightAnchor.constraint(equalToConstant: 5),
                dot.topAnchor.constraint(equalTo: button.topAnchor, constant: 3),
                dot.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -1),
            ])
            // Only key-value observing reports a change another process makes.
            UserDefaults.standard.addObserver(self, forKeyPath: Self.hideKey, options: [.initial], context: nil)
        }

        override nonisolated func observeValue(
            forKeyPath _: String?,
            of _: Any?,
            change _: [NSKeyValueChangeKey: Any]?,
            context _: UnsafeMutableRawPointer?
        ) {
            Task { @MainActor in
                dot.isHidden = UserDefaults.standard.bool(forKey: Self.hideKey)
            }
        }
    }

    private final class DotView: NSView {
        init() {
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            wantsLayer = true
            layer?.backgroundColor = NSColor.systemYellow.cgColor
            layer?.cornerRadius = 2.5
            // Yellow alone fades on a light menu bar.
            layer?.borderColor = NSColor.black.withAlphaComponent(0.5).cgColor
            layer?.borderWidth = 0.5
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        /// Clicks belong to the status item.
        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }
    }
#endif
