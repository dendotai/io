import AppKit
import SwiftUI

/// Beside SwiftUI's `.onHover`, each row has its own AppKit tracking area, so the log shows which of the two lost an exit, and each row's screen frame, so it shows where the pointer was.
struct HoverProbe: NSViewRepresentable {
    let id: UUID
    let name: String
    let clearHover: () -> Void

    func makeNSView(context _: Context) -> ProbeView {
        ProbeView(id: id, name: name)
    }

    func updateNSView(_ view: ProbeView, context _: Context) {
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
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Clicks and hover belong to the row.
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    var screenFrame: CGRect? {
        window.map { $0.convertToScreen(convert(bounds, to: nil)) }
    }

    var report: String {
        let pointer = NSEvent.mouseLocation
        let frame = screenFrame
        return [
            name,
            "frame=\(frame.map(describe) ?? "none")",
            "pointer=\(describe(pointer))",
            "inside=\(frame?.contains(pointer) ?? false)",
            "window=\(window?.windowNumber ?? -1)",
            "visible=\(window?.isVisible ?? false)",
            "fill=\(fillReason ?? "none")",
        ].joined(separator: " ")
    }

    static func report(_ id: UUID?) -> String {
        id.flatMap { attached[$0]?.report } ?? "row not attached"
    }

    private static var lastEntered: UUID?
    private static var lastExit: HoverExit?

    static func noteHover(of id: UUID, hovering: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        if hovering {
            if let lastEntered, lastEntered != id {
                missedExits += 1
                panelLog.notice("MISSED-EXIT \(report(lastEntered)); next row: \(report(id))")
            }
            if let lastExit, lastExit.id == id, lastExit.inside, now - lastExit.time < 0.005 {
                phantomPairs += 1
            }
            lastEntered = id
        } else {
            if lastEntered == id {
                lastEntered = nil
            }
            let inside = attached[id]?.screenFrame?.contains(NSEvent.mouseLocation) ?? false
            lastExit = HoverExit(id: id, time: now, inside: inside)
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
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
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
        let windowAreas = window.map { WindowDump.trackingAreaCount(in: $0) } ?? 0
        return [
            "event \(describe(event))",
            "view window=\(window?.windowNumber ?? -1)",
            "own=\(own)",
            "areas=\(trackingAreas.count)",
            "window areas=\(windowAreas)",
        ].joined(separator: " ")
    }
}

/// A row's last hover exit: when it came, and whether the pointer was still inside the row's frame.
private struct HoverExit {
    let id: UUID
    let time: TimeInterval
    let inside: Bool
}
