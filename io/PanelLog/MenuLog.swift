import AppKit

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
    private let observers: [(center: NotificationCenter, token: any NSObjectProtocol)]

    override init() {
        let screenCenter = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        observers = [
            (screenCenter, screenCenter.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { _ in
                panelLog.notice("screens changed: \(WindowDump.screens())")
            }),
            (workspaceCenter, workspaceCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                panelLog.notice("space changed: \(WindowDump.frontmost())")
            }),
        ]
        super.init()
    }

    isolated deinit {
        for (center, token) in observers {
            center.removeObserver(token)
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
        panelLog.notice([
            "menu open #\(openCount)",
            "seconds since launch=\(Int(ProcessInfo.processInfo.systemUptime - launchedAt))",
            "items=\(menu.items.count)",
            "pointer=\(describe(NSEvent.mouseLocation))",
            "screens=\(WindowDump.screens())",
            "frontmost=\(WindowDump.frontmost())",
            "event \(event)",
        ].joined(separator: " "))
        lastTick = ProcessInfo.processInfo.systemUptime
        openMenu = menu
        // `defaults write ai.den.io disableEventMonitor -bool true` and `disableSystemTap` switch one layer off, to find which one changes what the panel receives.
        if !UserDefaults.standard.bool(forKey: "disableEventMonitor") {
            // A local monitor on mouseMoved stops every tracking event in the panel (sweep A of PR 90, 0 hover enters), so moves come from the system tap and the monitor watches the rest; `monitorMouseMoved` adds them for a test.
            var mask: NSEvent.EventTypeMask = [
                .mouseEntered,
                .mouseExited,
                .cursorUpdate,
                .leftMouseDown,
                .leftMouseUp,
                .leftMouseDragged,
                .rightMouseDown,
                .appKitDefined,
                .systemDefined,
                .applicationDefined,
            ]
            if UserDefaults.standard.bool(forKey: "monitorMouseMoved") {
                mask.insert(.mouseMoved)
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
                panelLog.notice("app event \(describe(event))")
                return event
            }
        }
        if !UserDefaults.standard.bool(forKey: "disableSystemTap") {
            systemTap.enable()
        }
        let tickTimer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(tickTimer, forMode: .common)
        timer = tickTimer
    }

    func menuDidClose(_: NSMenu) {
        timer?.invalidate()
        timer = nil
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        systemTap.disable()
        let event = NSApp.currentEvent.map(describe) ?? "none"
        panelLog.notice([
            "menu close #\(openCount)",
            "pointer=\(describe(NSEvent.mouseLocation))",
            "pairs=\(ProbeView.phantomPairs)",
            "missed=\(ProbeView.missedExits)",
            "tick clears=\(tickClears)",
            "bad=\(isBadOpen)",
            "event \(event)",
        ].joined(separator: " "))
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        let index = item.map { "\(menu.index(of: $0))" } ?? "none"
        panelLog.notice("menu highlight index=\(index) pointer=\(describe(NSEvent.mouseLocation))")
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
            report(window)
        }
        let pointer = NSEvent.mouseLocation
        if pointer != lastPointer {
            lastPointer = pointer
            panelLog.notice("pointer \(describe(pointer)) buttons=\(NSEvent.pressedMouseButtons)")
        }
        for view in ProbeView.attached.values {
            checkFill(of: view, pointer: pointer)
        }
        if !isBadOpen, let window {
            if ProbeView.phantomPairs >= 5 {
                markBadOpen("\(ProbeView.phantomPairs) phantom pairs", in: window)
            } else if tickClears >= 2 {
                markBadOpen("\(tickClears) fills cleared by tick", in: window)
            }
        }
    }

    private func report(_ window: NSWindow) {
        panelLog.notice([
            "panel window \(window.windowNumber)",
            "frame=\(window.frame)",
            "level=\(window.level.rawValue)",
            "key=\(window.isKeyWindow)",
            "app active=\(NSApp.isActive)",
            "areas=\(WindowDump.trackingAreaCount(in: window))",
        ].joined(separator: " "))
        // Every open lists the windows, so a stale panel window or another process's window over the panel shows on the opens before a case too.
        for line in WindowDump.ioWindows() + WindowDump.windowsOver(window.frame) {
            panelLog.notice(line)
        }
        #if DEBUG
            if UserDefaults.standard.bool(forKey: "forceBadOpen") {
                markBadOpen("forced by the forceBadOpen default", in: window)
            }
        #endif
    }

    private func checkFill(of view: ProbeView, pointer: NSPoint) {
        let isGreyWithoutPointer = view.fillReason != nil && view.screenFrame?.contains(pointer) != true
        if isGreyWithoutPointer, !view.isReportedWithoutPointer {
            let greyRows = ProbeView.attached.values.filter { $0.fillReason != nil }.map(\.name)
                .joined(separator: ", ")
            panelLog.notice("GREY-WITHOUT-POINTER \(view.report); all grey rows: \(greyRows)")
        }
        view.isReportedWithoutPointer = isGreyWithoutPointer
        // A pointer on a row's edge pixel is inside for SwiftUI and outside for the frame, so the clear allows 1 pt; a dropped exit leaves the pointer rows away.
        let isFarFromPointer = view.fillReason == "hovered" && NSEvent.pressedMouseButtons == 0 && view.screenFrame
            .map { !$0.insetBy(
                dx: -1,
                dy: -1
            ).contains(pointer) } == true
        view.ticksGreyWithoutPointer = isFarFromPointer ? view.ticksGreyWithoutPointer + 1 : 0
        if view.ticksGreyWithoutPointer == Self.clearAfterTicks {
            tickClears += 1
            panelLog.notice("fill cleared by tick: \(view.report)")
            view.clearHover?()
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

/// A listen-only tap on the session's pointer events, on while the panel shows: what the system produced, beside what AppKit delivered. It runs on its own thread, because the system switches a tap off when its callback waits on a stalled main thread, and the callback switches it on again when that happens anyway.
private final class SystemEventTap {
    nonisolated(unsafe) static var tap: CFMachPort?
    /// On while the panel shows; the callback switches the tap on again only then, because the switch-off at close reports as a disable too.
    nonisolated(unsafe) static var isWanted = false
    private var thread: Thread?
    private var isReported = false

    func enable() {
        Self.isWanted = true
        if thread == nil {
            let tapThread = Thread { [weak self] in
                let mask: CGEventMask = [
                    CGEventType.mouseMoved,
                    .leftMouseDown,
                    .leftMouseUp,
                    .leftMouseDragged,
                    .rightMouseDown,
                ].reduce(0) { $0 | (1 << $1.rawValue) }
                guard let createdTap = CGEvent.tapCreate(
                    tap: .cgSessionEventTap,
                    place: .headInsertEventTap,
                    options: .listenOnly,
                    eventsOfInterest: mask,
                    callback: systemEventCallback,
                    userInfo: nil
                ) else {
                    panelLog.notice("system event tap unavailable")
                    return
                }
                Self.tap = createdTap
                CGEvent.tapEnable(tap: createdTap, enable: true)
                CFRunLoopAddSource(
                    CFRunLoopGetCurrent(),
                    CFMachPortCreateRunLoopSource(nil, createdTap, 0),
                    .commonModes
                )
                _ = self
                CFRunLoopRun()
            }
            tapThread.name = "ai.den.io.system-event-tap"
            tapThread.start()
            thread = tapThread
            return
        }
        if let tap = Self.tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func disable() {
        Self.isWanted = false
        if let tap = Self.tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
}

private nonisolated func systemEventCallback(
    proxy _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo _: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if SystemEventTap.isWanted, let tap = SystemEventTap.tap {
            panelLog.notice("system event tap disabled: type=\(type.rawValue); enabled again")
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return nil
    }
    let location = event.location
    let delta = CGPoint(
        x: event.getDoubleValueField(.mouseEventDeltaX),
        y: event.getDoubleValueField(.mouseEventDeltaY)
    )
    panelLog.notice([
        "system event type=\(type.rawValue)",
        "position=\(describe(location))",
        "delta=\(describe(delta))",
        "source=\(event.getIntegerValueField(.eventSourceUnixProcessID))",
        "state=\(event.getIntegerValueField(.eventSourceStateID))",
        "number=\(event.getIntegerValueField(.mouseEventNumber))",
        "timestamp=\(event.timestamp)",
    ].joined(separator: " "))
    return nil
}
