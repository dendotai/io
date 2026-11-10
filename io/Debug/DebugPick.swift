#if DEBUG
    import Foundation

    /// `io -pickOutput <name>` at launch, or `defaults write ai.den.io pickOutput <name>` while io runs without that argument, picks that output as a click in the panel does, because io sets back a change another process makes.
    final class DebugPick {
        private let model: AppModel
        private var observation: NSKeyValueObservation?

        init(model: AppModel) {
            self.model = model
            // Only key-value observing reports a change another process makes, and it can call from any thread.
            observation = UserDefaults.standard
                .observe(\.pickOutput, options: [.initial]) { @Sendable [weak self] _, _ in
                    Task { @MainActor in self?.pick() }
                }
        }

        private func pick() {
            guard let name = UserDefaults.standard.pickOutput else { return }
            model.pickOutput(named: name)
            // A written value would pick again at every launch, and writing the same name again would report no change.
            UserDefaults.standard.removeObject(forKey: UserDefaults.pickOutputKey)
        }
    }

    private extension UserDefaults {
        static let pickOutputKey = "pickOutput"

        /// Key-value observing of `UserDefaults` needs a property named as its key.
        @objc dynamic var pickOutput: String? {
            string(forKey: Self.pickOutputKey)
        }
    }
#endif
