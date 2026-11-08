import AppKit
import OSLog
import SwiftUI

/// Diagnosis for rows that stay grey (https://github.com/dendotai/io/issues/25). Each line also goes to `~/Library/Logs/io/panel.log` (20 to 40 MB kept, with `panel.1.log`), because the system log holds notices for less than a day on this Mac. A bad open (`BAD-OPEN`) is copied whole, with a state dump, to `cases.log`, which never rotates. Search for `BAD-OPEN`, `MISSED-EXIT`, and `GREY-WITHOUT-POINTER`. `scripts/panel-log/` reads the files.
nonisolated let panelLog = PanelLogger()

nonisolated final class PanelLogger: Sendable {
    private let logger = Logger(subsystem: "ai.den.io", category: "panel")
    private let queue = DispatchQueue(label: "ai.den.io.panel-log")
    private static let maxFileSize = 20_000_000
    private static let maxCasesSize = 100_000_000
    private static let maxOpenLines = 50_000
    private static let folder = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/io")
    /// The current open's lines, kept so a case found mid-open is copied from its start.
    nonisolated(unsafe) private var openLines: [String] = []
    nonisolated(unsafe) private var isCapturing = false

    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        let line = Self.line(message, at: .now)
        queue.async {
            Self.append(line, to: Self.folder.appending(path: "panel.log"), rotatingTo: Self.folder.appending(path: "panel.1.log"), over: Self.maxFileSize)
            if self.openLines.count < Self.maxOpenLines { self.openLines.append(line) }
            if self.isCapturing { Self.append(line, to: Self.casesFile, rotatingTo: nil, over: Self.maxCasesSize) }
        }
    }

    /// The open's lines so far go to `cases.log`, and every later line of the open follows them.
    func startCase() {
        queue.async {
            guard !self.isCapturing else { return }
            self.isCapturing = true
            Self.append(Self.line("=== case start ===", at: .now), to: Self.casesFile, rotatingTo: nil, over: Self.maxCasesSize)
            for line in self.openLines { Self.append(line, to: Self.casesFile, rotatingTo: nil, over: Self.maxCasesSize) }
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

    private static var casesFile: URL { folder.appending(path: "cases.log") }

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

private func describe(_ point: NSPoint) -> String {
    "(\(Int(point.x)),\(Int(point.y)))"
}

private func describe(_ rect: CGRect) -> String {
    "\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height))"
}

/// The fields of an event AppKit delivered: its kind, window, place, number, source process, deltas, and the run loop mode it arrived in. Deltas and the source come from the `CGEvent`, because `NSEvent` raises on a delta read of a non-move event.
private func describe(_ event: NSEvent) -> String {
    let cg = event.cgEvent
    let source = cg.map { "\($0.getIntegerValueField(.eventSourceUnixProcessID))" } ?? "?"
    let delta = cg.map { "(\(Int($0.getDoubleValueField(.mouseEventDeltaX))),\(Int($0.getDoubleValueField(.mouseEventDeltaY))))" } ?? "?"
    var tracking = ""
    if event.type == .mouseEntered || event.type == .mouseExited || event.type == .cursorUpdate {
        tracking = " tracking=\(event.trackingNumber) area=\(event.trackingArea.map { "\(ObjectIdentifier($0).hashValue)" } ?? "none")"
    }
    let mode = RunLoop.current.currentMode?.rawValue ?? "none"
    // `NSEvent` raises on a number or subtype read of an event kind that has none, such as a key press that closes the panel.
    let isMouse: Set<NSEvent.EventType> = [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .rightMouseUp, .rightMouseDragged, .otherMouseDown, .otherMouseUp, .otherMouseDragged, .mouseEntered, .mouseExited, .cursorUpdate, .scrollWheel]
    let hasSubtype = isMouse.contains(event.type) || [.appKitDefined, .systemDefined, .applicationDefined, .periodic].contains(event.type)
    let number = isMouse.contains(event.type) ? "\(event.eventNumber)" : "-"
    let subtype = hasSubtype ? "\(event.subtype.rawValue)" : "-"
    return "type=\(event.type.rawValue) subtype=\(subtype) window=\(event.window?.windowNumber ?? -1) location=\(describe(event.locationInWindow)) number=\(number) source=\(source) delta=\(delta)\(tracking) mode=\(mode)"
}

/// Beside SwiftUI's `.onHover`, each row has its own AppKit tracking area, so the log shows which of the two lost an exit, and each row's screen frame, so it shows where the pointer was.
struct HoverProbe: NSViewRepresentable {
    let id: UUID
    let name: String
    let clearHover: () -> Void

    func makeNSView(context: Context) -> ProbeView {
        ProbeView(id: id, name: name)
    }

    func updateNSView(_ view: ProbeView, context: Context) {
        view.name = name
        view.clearHover = clearHover
    }
}

final class ProbeView: NSView {
    static var attached: [UUID: ProbeView] = [:]
    /// Same-row exits with the pointer still inside, re-entered within 5 ms, in the current open: the sign of a bad open.
    static var phantomPairs = 0
    static var missedExits = 0

    private let id: UUID
    var name: String
    var fillReason: String?
    var isReportedWithoutPointer = false
    /// Ticks in a row with the fill on and the pointer outside the frame.
    var ticksGreyWithoutPointer = 0
    var clearHover: (() -> Void)?

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Clicks and hover belong to the row.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    var screenFrame: CGRect? {
        window.map { $0.convertToScreen(convert(bounds, to: nil)) }
    }

    var report: String {
        let pointer = NSEvent.mouseLocation
        let frame = screenFrame
        return "\(name) frame=\(frame.map(describe) ?? "none") pointer=\(describe(pointer)) inside=\(frame?.contains(pointer) ?? false) window=\(window?.windowNumber ?? -1) visible=\(window?.isVisible ?? false) fill=\(fillReason ?? "none")"
    }

    static func report(_ id: UUID?) -> String {
        id.flatMap { attached[$0]?.report } ?? "row not attached"
    }

    private static var lastEntered: UUID?
    private static var lastExit: (id: UUID, at: TimeInterval, inside: Bool)?

    static func noteHover(of id: UUID, hovering: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        if hovering {
            if let lastEntered, lastEntered != id {
                missedExits += 1
                panelLog.notice("MISSED-EXIT \(report(lastEntered)); next row: \(report(id))")
            }
            if let lastExit, lastExit.id == id, lastExit.inside, now - lastExit.at < 0.005 {
                phantomPairs += 1
            }
            lastEntered = id
        } else {
            if lastEntered == id {
                lastEntered = nil
            }
            let inside = attached[id]?.screenFrame?.contains(NSEvent.mouseLocation) ?? false
            lastExit = (id, now, inside)
        }
    }

    static func resetOpen() {
        phantomPairs = 0
        missedExits = 0
        lastEntered = nil
        lastExit = nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        Self.attached[id] = window == nil ? nil : self
        panelLog.notice("row moved to window \(window?.windowNumber ?? -1): \(name)")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        panelLog.notice("tracking area reset: \(report)")
    }

    override func mouseEntered(with event: NSEvent) {
        panelLog.notice("appkit enter: \(report) \(eventReport(event))")
    }

    override func mouseExited(with event: NSEvent) {
        panelLog.notice("appkit exit: \(report) \(eventReport(event))")
    }

    /// Names the window, the tracking area, and the event behind each enter and exit, to find where a phantom exit comes from.
    private func eventReport(_ event: NSEvent) -> String {
        let own = event.trackingArea.map { trackingAreas.contains($0) } ?? false
        return "event \(describe(event)) view window=\(window?.windowNumber ?? -1) own=\(own) areas=\(trackingAreas.count) window areas=\(window.map { WindowDump.trackingAreaCount(in: $0) } ?? 0)"
    }
}

/// Logs each panel open with how it was opened, and while it shows: every event the system and AppKit deliver, each pointer move, each pause of the main thread, each highlighted item, and each grey row with no pointer on it. A row whose frame has not held the pointer for four ticks loses its hover fill, because a bad open drops the exit that would clear it. Five phantom pairs or two such clears mark the open `BAD-OPEN`, which dumps the state and copies the open to `cases.log`.
final class MenuLog: NSObject, NSMenuDelegate {
    private static let clearAfterTicks = 4
    private let launchedAt = ProcessInfo.processInfo.systemUptime
    private var openCount = 0
    private var timer: Timer?
    private weak var openMenu: NSMenu?
    private var lastTick: TimeInterval = 0
    private var lastPointer: NSPoint?
    private var isWindowReported = false
    private var isBadOpen = false
    private var tickClears = 0
    private var eventMonitor: Any?
    private let systemTap = SystemEventTap()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            panelLog.notice("screens changed: \(WindowDump.screens())")
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
            panelLog.notice("space changed: \(WindowDump.frontmost())")
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        openCount += 1
        lastPointer = nil
        isWindowReported = false
        isBadOpen = false
        tickClears = 0
        ProbeView.resetOpen()
        panelLog.beginOpen()
        let event = NSApp.currentEvent.map(describe) ?? "none"
        panelLog.notice("menu open #\(openCount) seconds since launch=\(Int(ProcessInfo.processInfo.systemUptime - launchedAt)) items=\(menu.items.count) pointer=\(describe(NSEvent.mouseLocation)) screens=\(WindowDump.screens()) frontmost=\(WindowDump.frontmost()) event \(event)")
        lastTick = ProcessInfo.processInfo.systemUptime
        openMenu = menu
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited, .cursorUpdate, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .appKitDefined, .systemDefined, .applicationDefined]) { event in
            panelLog.notice("app event \(describe(event))")
            return event
        }
        systemTap.enable()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        timer?.invalidate()
        timer = nil
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        systemTap.disable()
        let event = NSApp.currentEvent.map(describe) ?? "none"
        panelLog.notice("menu close #\(openCount) pointer=\(describe(NSEvent.mouseLocation)) pairs=\(ProbeView.phantomPairs) missed=\(ProbeView.missedExits) tick clears=\(tickClears) bad=\(isBadOpen) event \(event)")
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        panelLog.notice("menu highlight index=\(item.map { "\(menu.index(of: $0))" } ?? "none") pointer=\(describe(NSEvent.mouseLocation))")
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastTick > 0.05 {
            panelLog.notice("main thread pause \(Int((now - lastTick) * 1000)) ms")
        }
        lastTick = now
        let window = openMenu?.items.first?.view?.window
        if !isWindowReported, let window {
            isWindowReported = true
            panelLog.notice("panel window \(window.windowNumber) frame=\(window.frame) level=\(window.level.rawValue) key=\(window.isKeyWindow) app active=\(NSApp.isActive) areas=\(WindowDump.trackingAreaCount(in: window))")
            #if DEBUG
                if UserDefaults.standard.bool(forKey: "forceBadOpen") {
                    markBadOpen("forced by the forceBadOpen default", in: window)
                }
            #endif
        }
        let pointer = NSEvent.mouseLocation
        if pointer != lastPointer {
            lastPointer = pointer
            panelLog.notice("pointer \(describe(pointer)) buttons=\(NSEvent.pressedMouseButtons)")
        }
        for view in ProbeView.attached.values {
            let isGreyWithoutPointer = view.fillReason != nil && view.screenFrame?.contains(pointer) != true
            if isGreyWithoutPointer, !view.isReportedWithoutPointer {
                let greyRows = ProbeView.attached.values.filter { $0.fillReason != nil }.map(\.name).joined(separator: ", ")
                panelLog.notice("GREY-WITHOUT-POINTER \(view.report); all grey rows: \(greyRows)")
            }
            view.isReportedWithoutPointer = isGreyWithoutPointer
            view.ticksGreyWithoutPointer = isGreyWithoutPointer && view.fillReason == "hovered" && NSEvent.pressedMouseButtons == 0 ? view.ticksGreyWithoutPointer + 1 : 0
            if view.ticksGreyWithoutPointer == Self.clearAfterTicks {
                tickClears += 1
                panelLog.notice("fill cleared by tick: \(view.report)")
                view.clearHover?()
            }
        }
        if !isBadOpen, let window {
            if ProbeView.phantomPairs >= 5 {
                markBadOpen("\(ProbeView.phantomPairs) phantom pairs", in: window)
            } else if tickClears >= 2 {
                markBadOpen("\(tickClears) fills cleared by tick", in: window)
            }
        }
    }

    private func markBadOpen(_ reason: String, in window: NSWindow) {
        isBadOpen = true
        panelLog.notice("BAD-OPEN #\(openCount): \(reason)")
        panelLog.startCase()
        panelLog.caseText(WindowDump.state(of: window))
        WindowDump.systemLogSlice { panelLog.caseText($0) }
    }
}

/// A listen-only tap on the session's pointer events, on while the panel shows: what the system produced, beside what AppKit delivered.
private final class SystemEventTap {
    private var tap: CFMachPort?
    private var isReported = false

    func enable() {
        if tap == nil {
            let mask: CGEventMask = [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown].reduce(0) { $0 | (1 << $1.rawValue) }
            tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask, callback: systemEventCallback, userInfo: nil)
            if let tap {
                CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
            } else if !isReported {
                isReported = true
                panelLog.notice("system event tap unavailable")
            }
        }
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    func disable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
    }
}

nonisolated private func systemEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        panelLog.notice("system event tap disabled: type=\(type.rawValue)")
        return nil
    }
    let location = event.location
    panelLog.notice("system event type=\(type.rawValue) position=(\(Int(location.x)),\(Int(location.y))) delta=(\(Int(event.getDoubleValueField(.mouseEventDeltaX))),\(Int(event.getDoubleValueField(.mouseEventDeltaY)))) source=\(event.getIntegerValueField(.eventSourceUnixProcessID)) state=\(event.getIntegerValueField(.eventSourceStateID)) number=\(event.getIntegerValueField(.mouseEventNumber)) timestamp=\(event.timestamp)")
    return nil
}

/// The state around the panel at a bad open: every on-screen window over it from any process, io's windows, the panel's tracking areas, the screens, and the frontmost app.
enum WindowDump {
    static func state(of panel: NSWindow) -> String {
        var lines = ["--- state dump ---", "screens: \(screens())", "frontmost: \(frontmost())", "panel window \(panel.windowNumber) frame=\(describe(panel.frame))"]
        lines.append("io windows:")
        for window in NSApp.windows {
            lines.append("  \(type(of: window)) \(window.windowNumber) frame=\(describe(window.frame)) level=\(window.level.rawValue) visible=\(window.isVisible) alpha=\(window.alphaValue) ignoresMouse=\(window.ignoresMouseEvents)")
        }
        lines.append("windows over the panel (window list, top first):")
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let panelCG = CGRect(x: panel.frame.minX, y: primaryHeight - panel.frame.maxY, width: panel.frame.width, height: panel.frame.height)
        for window in CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? [] {
            guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let rect = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            guard rect.intersects(panelCG) else { continue }
            lines.append("  \(window[kCGWindowNumber as String] ?? "?") owner=\(window[kCGWindowOwnerName as String] ?? "?") pid=\(window[kCGWindowOwnerPID as String] ?? "?") layer=\(window[kCGWindowLayer as String] ?? "?") alpha=\(window[kCGWindowAlpha as String] ?? "?") bounds=\(describe(rect))")
        }
        lines.append("tracking areas in the panel window:")
        if let content = panel.contentView {
            walk(content, into: &lines)
        }
        lines.append("--- end of state dump ---")
        return lines.joined(separator: "\n")
    }

    private static func walk(_ view: NSView, into lines: inout [String]) {
        for area in view.trackingAreas {
            let rect = view.convert(area.options.contains(.inVisibleRect) ? view.visibleRect : area.rect, to: nil)
            lines.append("  \(type(of: view)) frame=\(describe(view.convert(view.bounds, to: nil))) area rect=\(describe(rect)) options=\(area.options.rawValue) owner=\(area.owner.map { "\(type(of: $0))" } ?? "none")")
        }
        for child in view.subviews {
            walk(child, into: &lines)
        }
    }

    static func trackingAreaCount(in window: NSWindow) -> Int {
        func count(_ view: NSView) -> Int { view.trackingAreas.count + view.subviews.reduce(0) { $0 + count($1) } }
        return window.contentView.map(count) ?? 0
    }

    static func screens() -> String {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.map { screen in
            var marks: [String] = []
            if screen == NSScreen.main { marks.append("main") }
            if screen.frame.contains(pointer) { marks.append("pointer") }
            return "\(describe(screen.frame))@\(screen.backingScaleFactor)\(marks.isEmpty ? "" : "[\(marks.joined(separator: ","))]")"
        }.joined(separator: " ")
    }

    /// The frontmost app, and whether one of its windows fills a screen, because the menu bar dims and hides differently in a full-screen Space.
    static func frontmost() -> String {
        guard let app = NSWorkspace.shared.frontmostApplication else { return "none" }
        let screens = NSScreen.screens.map(\.frame)
        let primaryHeight = screens.first?.height ?? 0
        var isFullScreen = false
        for window in CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? [] {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier, let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let rect = CGRect(x: bounds["X"] ?? 0, y: primaryHeight - (bounds["Y"] ?? 0) - (bounds["Height"] ?? 0), width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            if screens.contains(where: { $0.size == rect.size && $0.origin == rect.origin }) { isFullScreen = true }
        }
        return "\(app.localizedName ?? "?") pid=\(app.processIdentifier) fullscreen=\(isFullScreen)"
    }

    /// The last 30 s of what the window server and io said, read off the main thread.
    static func systemLogSlice(_ completion: @escaping @Sendable (String) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            process.arguments = ["show", "--last", "30s", "--style", "compact", "--predicate", "process == \"WindowServer\" OR process == \"io\""]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let text = String(decoding: data.suffix(200_000), as: UTF8.self)
                completion("--- system log, last 30 s ---\n\(text)\n--- end of system log ---")
            } catch {
                completion("--- system log unavailable: \(error) ---")
            }
        }
    }
}
