#if DEBUG
    import Foundation

    /// `io -pickOutput <name>` at launch, or `defaults write ai.den.io pickOutput <name>` while io runs without that argument, picks that output as a click in the panel does, because io sets back a change another process makes.
    final class DebugPick: NSObject {
        private static let key = "pickOutput"
        private let model: AppModel

        init(model: AppModel) {
            self.model = model
            super.init()
            // Only key-value observing reports a change another process makes.
            UserDefaults.standard.addObserver(self, forKeyPath: Self.key, options: [.initial], context: nil)
        }

        override nonisolated func observeValue(
            forKeyPath _: String?,
            of _: Any?,
            change _: [NSKeyValueChangeKey: Any]?,
            context _: UnsafeMutableRawPointer?
        ) {
            Task { @MainActor in
                guard let name = UserDefaults.standard.string(forKey: Self.key) else { return }
                model.pickOutput(named: name)
                // A written value would pick again at every launch, and writing the same name again would report no change.
                UserDefaults.standard.removeObject(forKey: Self.key)
            }
        }
    }
#endif
