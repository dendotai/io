import AppKit
import OSLog
import SwiftUI

/// Diagnosis for rows that stay grey (https://github.com/dendotai/io/issues/25). Each line also goes to `~/Library/Logs/io/panel.log` (20 to 40 MB kept, with `panel.1.log`), because the system log holds notices for less than a day on this Mac. Search it for `MISSED-EXIT` and `GREY-WITHOUT-POINTER`.
let panelLog = PanelLogger()

nonisolated final class PanelLogger: Sendable {
    private let logger = Logger(subsystem: "ai.den.io", category: "panel")
    private let queue = DispatchQueue(label: "ai.den.io.panel-log")
    private static let maxFileSize = 20_000_000

    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        let date = Date.now
        queue.async { Self.append(message, at: date) }
    }

    private static func append(_ message: String, at date: Date) {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/io")
        let file = folder.appending(path: "panel.log")
        let older = folder.appending(path: "panel.1.log")
        let time = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current).format(date)
        let line = Data("\(time) \(ProcessInfo.processInfo.processIdentifier) \(message)\n".utf8)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxFileSize {
                try? FileManager.default.removeItem(at: older)
                try FileManager.default.moveItem(at: file, to: older)
            }
            if !FileManager.default.fileExists(atPath: file.path) {
                FileManager.default.createFile(atPath: file.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } catch {
            NSLog("io: panel log write failed: \(error)")
        }
    }
}

private func describe(_ point: NSPoint) -> String {
    "(\(Int(point.x)),\(Int(point.y)))"
}

/// Beside SwiftUI's `.onHover`, each row has its own AppKit tracking area, so the log shows which of the two lost an exit, and each row's screen frame, so it shows where the pointer was.
struct HoverProbe: NSViewRepresentable {
    let id: UUID
    let name: String

    func makeNSView(context: Context) -> ProbeView {
        ProbeView(id: id, name: name)
    }

    func updateNSView(_ view: ProbeView, context: Context) {
        view.name = name
    }
}

final class ProbeView: NSView {
    static var attached: [UUID: ProbeView] = [:]

    private let id: UUID
    var name: String
    var fillReason: String?
    var isReportedWithoutPointer = false

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
        return "\(name) frame=\(frame.map { "\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height))" } ?? "none") pointer=\(describe(pointer)) inside=\(frame?.contains(pointer) ?? false) window=\(window?.windowNumber ?? -1) visible=\(window?.isVisible ?? false) fill=\(fillReason ?? "none")"
    }

    static func report(_ id: UUID?) -> String {
        id.flatMap { attached[$0]?.report } ?? "row not attached"
    }

    private static var lastEntered: UUID?

    static func noteHover(of id: UUID, hovering: Bool) {
        if hovering {
            if let lastEntered, lastEntered != id {
                panelLog.notice("MISSED-EXIT \(report(lastEntered)); next row: \(report(id))")
            }
            lastEntered = id
        } else if lastEntered == id {
            lastEntered = nil
        }
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
        panelLog.notice("appkit enter: \(report)")
    }

    override func mouseExited(with event: NSEvent) {
        panelLog.notice("appkit exit: \(report)")
    }
}

/// Logs each panel open with how it was opened, and while it shows: each pointer move, each pause of the main thread, each highlighted item, and each grey row with no pointer on it.
final class MenuLog: NSObject, NSMenuDelegate {
    private let launchedAt = ProcessInfo.processInfo.systemUptime
    private var openCount = 0
    private var timer: Timer?
    private weak var openMenu: NSMenu?
    private var lastTick: TimeInterval = 0
    private var lastPointer: NSPoint?
    private var isWindowReported = false

    func menuWillOpen(_ menu: NSMenu) {
        openCount += 1
        lastPointer = nil
        isWindowReported = false
        let event = NSApp.currentEvent.map { "\($0.type.rawValue)" } ?? "none"
        let screens = NSScreen.screens.map { "\(Int($0.frame.width))x\(Int($0.frame.height))@\($0.backingScaleFactor)" }.joined(separator: " ")
        panelLog.notice("menu open #\(openCount) seconds since launch=\(Int(ProcessInfo.processInfo.systemUptime - launchedAt)) event type=\(event) items=\(menu.items.count) pointer=\(describe(NSEvent.mouseLocation)) screens=\(screens)")
        lastTick = ProcessInfo.processInfo.systemUptime
        openMenu = menu
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        timer?.invalidate()
        timer = nil
        panelLog.notice("menu close #\(openCount) pointer=\(describe(NSEvent.mouseLocation))")
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
        if !isWindowReported, let window = openMenu?.items.first?.view?.window {
            isWindowReported = true
            panelLog.notice("panel window \(window.windowNumber) frame=\(window.frame) level=\(window.level.rawValue) key=\(window.isKeyWindow) app active=\(NSApp.isActive)")
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
        }
    }
}
