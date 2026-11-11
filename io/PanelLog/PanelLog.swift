import AppKit
import os

/// Diagnosis for rows that stay grey (https://github.com/dendotai/io/issues/25). Each line also goes to `~/Library/Logs/io/panel.log` (20 to 40 MB kept, with `panel.1.log`), because the system log holds notices for less than a day on this Mac. A bad open (`BAD-OPEN`) is copied whole, with a state dump, to `cases.log`, which never rotates. Search for `BAD-OPEN`, `MISSED-EXIT`, and `GREY-WITHOUT-POINTER`.
nonisolated let panelLog = PanelLogger()

final nonisolated class PanelLogger: Sendable {
    private let logger = Logger(subsystem: "ai.den.io", category: "panel")
    private let queue = DispatchQueue(label: "ai.den.io.panel-log")
    private static let maxFileSize = 20_000_000
    private static let maxCasesSize = 100_000_000
    private static let maxOpenLines = 50000
    private static let folder = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/io")
    /// The current open's lines, kept so a case found mid-open is copied from its start.
    private nonisolated(unsafe) var openLines: [String] = []
    private nonisolated(unsafe) var isCapturing = false

    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        let line = Self.line(message, at: .now)
        queue.async {
            Self.append(
                line,
                to: Self.folder.appending(path: "panel.log"),
                rotatingTo: Self.folder.appending(path: "panel.1.log"),
                over: Self.maxFileSize
            )
            if self.openLines.count < Self.maxOpenLines {
                self.openLines.append(line)
            }
            if self.isCapturing {
                Self.append(line, to: Self.casesFile, rotatingTo: nil, over: Self.maxCasesSize)
            }
        }
    }

    /// The open's lines so far go to `cases.log`, and every later line of the open follows them.
    func startCase() {
        queue.async {
            guard !self.isCapturing else { return }
            self.isCapturing = true
            Self.append(
                Self.line("=== case start ===", at: .now),
                to: Self.casesFile,
                rotatingTo: nil,
                over: Self.maxCasesSize
            )
            for line in self
                .openLines
            {
                Self.append(line, to: Self.casesFile, rotatingTo: nil, over: Self.maxCasesSize)
            }
        }
    }

    func beginOpen() {
        queue.async {
            self.openLines = []
            self.isCapturing = false
        }
    }

    /// A block of text (a state dump, a system log slice) for `cases.log` only.
    func caseText(_ text: String) {
        queue.async { Self.append(text + "\n", to: Self.casesFile, rotatingTo: nil, over: Self.maxCasesSize) }
    }

    private static var casesFile: URL {
        folder.appending(path: "cases.log")
    }

    private static func line(_ message: String, at date: Date) -> String {
        let time = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current).format(date)
        return "\(time) \(ProcessInfo.processInfo.processIdentifier) \(message)\n"
    }

    private static func append(_ text: String, to file: URL, rotatingTo older: URL?, over limit: Int) {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > limit {
                guard let older else { return }
                try? FileManager.default.removeItem(at: older)
                try FileManager.default.moveItem(at: file, to: older)
            }
            if !FileManager.default.fileExists(atPath: file.path) {
                FileManager.default.createFile(atPath: file.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(text.utf8))
        } catch {
            NSLog("io: panel log write failed: \(error)")
        }
    }
}

nonisolated func describe(_ point: NSPoint) -> String {
    "(\(Int(point.x)),\(Int(point.y)))"
}

nonisolated func describe(_ rect: CGRect) -> String {
    "\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height))"
}

/// The fields of an event AppKit delivered: its kind, window, place, number, source process, deltas, and the run loop mode it arrived in. Deltas and the source come from the `CGEvent`, because `NSEvent` raises on a delta read of a non-move event.
func describe(_ event: NSEvent) -> String {
    // `NSEvent` raises on a number, subtype, or CGEvent read of an event kind that has none: a key press that closes the panel, or a tracking event, which AppKit makes itself.
    let isTracking = event.type == .mouseEntered || event.type == .mouseExited || event.type == .cursorUpdate
    let isMouse: Set<NSEvent.EventType> = [
        .mouseMoved,
        .leftMouseDown,
        .leftMouseUp,
        .leftMouseDragged,
        .rightMouseDown,
        .rightMouseUp,
        .rightMouseDragged,
        .otherMouseDown,
        .otherMouseUp,
        .otherMouseDragged,
        .scrollWheel,
    ]
    let cgEvent = isMouse.contains(event.type) ? event.cgEvent : nil
    let source = cgEvent.map { "\($0.getIntegerValueField(.eventSourceUnixProcessID))" } ?? "-"
    let delta = cgEvent.map {
        describe(CGPoint(x: $0.getDoubleValueField(.mouseEventDeltaX), y: $0.getDoubleValueField(.mouseEventDeltaY)))
    } ?? "-"
    var tracking = ""
    if isTracking {
        let area = event.trackingArea.map { "\(ObjectIdentifier($0).hashValue)" } ?? "none"
        tracking = " tracking=\(event.trackingNumber) area=\(area)"
    }
    let hasSubtype = isMouse.contains(event.type) || [.appKitDefined, .systemDefined, .applicationDefined, .periodic]
        .contains(event.type)
    let number = isMouse.contains(event.type) ? "\(event.eventNumber)" : "-"
    let subtype = hasSubtype ? "\(event.subtype.rawValue)" : "-"
    let mode = RunLoop.current.currentMode?.rawValue ?? "none"
    return [
        "type=\(event.type.rawValue)",
        "subtype=\(subtype)",
        "window=\(event.window?.windowNumber ?? -1)",
        "location=\(describe(event.locationInWindow))",
        "number=\(number)",
        "source=\(source)",
        "delta=\(delta)\(tracking)",
        "mode=\(mode)",
    ].joined(separator: " ")
}
