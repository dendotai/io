#if DEBUG
    import Foundation
    import Priority

    /// Does what a click in the panel does, for a check that runs without the pointer: `defaults write ai.den.io <key> <value>` while io runs, or `io -<key> <value>` at launch.
    /// `pickOutput`, `pickInput`, `hideOutput` and `hideInput` take a device name; `openPanel` takes any value.
    /// A pick goes through io because io sets back a change another process makes. `openPanel` exists because on macOS 27 the menu bar icon has no window and no Accessibility element, so no tool outside io can find it.
    final class DebugActions {
        private let model: AppModel
        private let openPanel: () -> Void
        private var observations: [NSKeyValueObservation] = []

        init(model: AppModel, openPanel: @escaping () -> Void) {
            self.model = model
            self.openPanel = openPanel
            // Only key-value observing reports a change another process makes, and it can call from any thread.
            let paths: [KeyPath<UserDefaults, String?>] = [
                \.pickOutput,
                \.pickInput,
                \.hideOutput,
                \.hideInput,
                \.openPanel,
            ]
            observations = paths.map {
                UserDefaults.standard.observe($0, options: [.initial]) { @Sendable [weak self] _, _ in
                    // Not a main-actor `Task`: the panel opened here tracks inside the job that opened it, and the main queue runs no other job until it closes. Common modes include the panel's tracking mode.
                    RunLoop.main.perform(inModes: [.common]) { MainActor.assumeIsolated { self?.run() } }
                }
            }
        }

        private func run() {
            let defaults = UserDefaults.standard
            // A written value would act again at every launch, and writing the same value again would report no change.
            if let name = take("pickOutput") {
                model.pick(named: name, in: .output)
            }
            if let name = take("pickInput") {
                model.pick(named: name, in: .input)
            }
            if let name = take("hideOutput") {
                model.hide(named: name, in: .output)
            }
            if let name = take("hideInput") {
                model.hide(named: name, in: .input)
            }
            if take("openPanel") != nil {
                openPanel()
            }

            func take(_ key: String) -> String? {
                guard let value = defaults.string(forKey: key) else { return nil }
                defaults.removeObject(forKey: key)
                return value
            }
        }
    }

    private extension AppModel {
        func pick(named name: String, in direction: Direction) {
            guard let row = rows[direction]?.first(where: { $0.isConnected && $0.device.name == name }) else { return }
            use(row.device, in: direction)
        }

        func hide(named name: String, in direction: Direction) {
            guard let row = rows[direction]?.first(where: { $0.canHide && $0.device.name == name }) else { return }
            hide(row.device, in: direction)
        }
    }

    /// Key-value observing of `UserDefaults` needs a property named as its key.
    private extension UserDefaults {
        @objc dynamic var pickOutput: String? {
            string(forKey: "pickOutput")
        }

        @objc dynamic var pickInput: String? {
            string(forKey: "pickInput")
        }

        @objc dynamic var hideOutput: String? {
            string(forKey: "hideOutput")
        }

        @objc dynamic var hideInput: String? {
            string(forKey: "hideInput")
        }

        @objc dynamic var openPanel: String? {
            string(forKey: "openPanel")
        }
    }
#endif
