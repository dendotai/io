import AppKit

/// The state around the panel at a bad open: every on-screen window over it from any process, io's windows, the panel's tracking areas, the screens, and the frontmost app.
enum WindowDump {
    static func state(of panel: NSWindow) -> String {
        var lines = [
            "--- state dump ---",
            "screens: \(screens())",
            "frontmost: \(frontmost())",
            "panel window \(panel.windowNumber) frame=\(describe(panel.frame))",
        ]
        lines += ioWindows() + windowsOver(panel.frame)
        lines.append("tracking areas in the panel window:")
        if let content = panel.contentView {
            walk(content, into: &lines)
        }
        lines.append("--- end of state dump ---")
        return lines.joined(separator: "\n")
    }

    static func ioWindows() -> [String] {
        NSApp.windows.map { window in
            [
                "io window \(type(of: window)) \(window.windowNumber)",
                "frame=\(describe(window.frame))",
                "level=\(window.level.rawValue)",
                "visible=\(window.isVisible)",
                "alpha=\(window.alphaValue)",
                "ignoresMouse=\(window.ignoresMouseEvents)",
            ].joined(separator: " ")
        }
    }

    /// Every on-screen window of any process whose bounds meet the panel's frame, top first.
    static func windowsOver(_ frame: CGRect) -> [String] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let panelCG = CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
        var lines: [String] = []
        for window in CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? [] {
            guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let rect = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            guard rect.intersects(panelCG) else { continue }
            lines.append([
                "window over the panel \(window[kCGWindowNumber as String] ?? "?")",
                "owner=\(window[kCGWindowOwnerName as String] ?? "?")",
                "pid=\(window[kCGWindowOwnerPID as String] ?? "?")",
                "layer=\(window[kCGWindowLayer as String] ?? "?")",
                "alpha=\(window[kCGWindowAlpha as String] ?? "?")",
                "bounds=\(describe(rect))",
            ].joined(separator: " "))
        }
        return lines
    }

    private static func walk(_ view: NSView, into lines: inout [String]) {
        for area in view.trackingAreas {
            let rect = view.convert(area.options.contains(.inVisibleRect) ? view.visibleRect : area.rect, to: nil)
            let owner = area.owner.map { "\(type(of: $0))" } ?? "none"
            lines.append([
                "  \(type(of: view))",
                "frame=\(describe(view.convert(view.bounds, to: nil)))",
                "area rect=\(describe(rect))",
                "options=\(area.options.rawValue)",
                "owner=\(owner)",
            ].joined(separator: " "))
        }
        for child in view.subviews {
            walk(child, into: &lines)
        }
    }

    static func trackingAreaCount(in window: NSWindow) -> Int {
        func count(_ view: NSView) -> Int {
            view.trackingAreas.count + view.subviews.reduce(0) { $0 + count($1) }
        }
        return window.contentView.map(count) ?? 0
    }

    static func screens() -> String {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.map { screen in
            var marks: [String] = []
            if screen == NSScreen.main {
                marks.append("main")
            }
            if screen.frame.contains(pointer) {
                marks.append("pointer")
            }
            let markText = marks.isEmpty ? "" : "[\(marks.joined(separator: ","))]"
            return "\(describe(screen.frame))@\(screen.backingScaleFactor)\(markText)"
        }.joined(separator: " ")
    }

    /// The frontmost app, and whether one of its windows fills a screen, because the menu bar dims and hides differently in a full-screen Space.
    static func frontmost() -> String {
        guard let app = NSWorkspace.shared.frontmostApplication else { return "none" }
        let screens = NSScreen.screens.map(\.frame)
        let primaryHeight = screens.first?.height ?? 0
        var isFullScreen = false
        for window in CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? [] {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let rect = CGRect(
                x: bounds["X"] ?? 0,
                y: primaryHeight - (bounds["Y"] ?? 0) - (bounds["Height"] ?? 0),
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            if screens.contains(where: { $0.size == rect.size && $0.origin == rect.origin }) {
                isFullScreen = true
            }
        }
        return "\(app.localizedName ?? "?") pid=\(app.processIdentifier) fullscreen=\(isFullScreen)"
    }

    /// The last 30 s of what the window server and io said, read off the main thread.
    static func systemLogSlice(_ completion: @escaping @Sendable (String) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            process.arguments = [
                "show",
                "--last",
                "30s",
                "--style",
                "compact",
                "--predicate",
                "process == \"WindowServer\" OR process == \"io\"",
            ]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                // A cut at 200 000 bytes can split a UTF-8 character, which the failable initializer turns into no text at all.
                // swiftlint:disable:next optional_data_string_conversion
                let text = String(decoding: data.suffix(200_000), as: UTF8.self)
                completion("--- system log, last 30 s ---\n\(text)\n--- end of system log ---")
            } catch {
                completion("--- system log unavailable: \(error) ---")
            }
        }
    }
}
