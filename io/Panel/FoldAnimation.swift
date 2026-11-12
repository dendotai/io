import AppKit
import Priority
import SwiftUI

/// For the length of a fold, one menu item stands in for the group and every row between it and the settings rows, as a drag does (ADR 0001), because the rows below the group overlap it and an item's view is cut off at its own frame. The rows ride the moving edge. Opening reveals the group from the top at that edge; closing slides the rows up over the fading group. A tick moves only views' frames and opacity, because a SwiftUI layout on each tick stalls the menu for up to 333 ms, and `NSMenu` resizes only when an item's frame changes.
final class FoldAnimation {
    let uid: String
    let item = NSMenuItem()
    let modes: [ListeningMode]
    private let container = NSView()
    private let groupClip = NSView()
    private let group: NSView
    private let rows: NSView
    private let groupHeight: CGFloat
    private var timer: Timer?
    private var isIdle = true
    private var isOpening = true
    private var height: CGFloat = 0
    /// Counted from the first tick, so the time the menu takes to swap its items is not skipped.
    private var tickStart: Date?
    private var completion: (() -> Void)?

    /// Built when the panel opens, because building these views at the click delays the first frame.
    init(model: AppModel, device: Device, modes: [ListeningMode]) {
        uid = device.uid
        self.modes = modes
        group = NSHostingView(rootView: ListeningModeGroup(model: model, device: device, modes: modes))
        groupHeight = group.fittingSize.height
        group.setFrameSize(NSSize(width: Metrics.width, height: groupHeight))
        rows = NSHostingView(rootView: FoldBelowRows(model: model, uid: device.uid))
        groupClip.wantsLayer = true
        groupClip.layer?.masksToBounds = true
        groupClip.addSubview(group)
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        container.addSubview(groupClip)
        container.addSubview(rows)
        item.view = container
        layOut()
    }

    /// A fold clicked again while it moves carries on from where it is.
    func start(isOpening: Bool, completion: @escaping () -> Void) {
        if timer == nil {
            height = isOpening ? 0 : groupHeight
            group.alphaValue = isOpening ? 0 : 1
        }
        timer?.invalidate()
        isIdle = false
        self.isOpening = isOpening
        rows.setFrameSize(NSSize(width: Metrics.width, height: rows.fittingSize.height))
        let target = isOpening ? groupHeight : 0
        let fromHeight = height, fromOpacity = group.alphaValue
        tickStart = nil
        self.completion = completion
        let foldTimer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            MainActor.assumeIsolated { [self] in
                let begun = tickStart ?? .now
                tickStart = begun
                let elapsed = Date.now.timeIntervalSince(begun)
                let isDone = elapsed >= FoldCurve.duration
                height = isDone ? target : fromHeight + (target - fromHeight) * FoldCurve.position(at: elapsed)
                group.alphaValue = fromOpacity + ((isOpening ? 1 : 0) - fromOpacity) * FoldCurve.fade(at: elapsed)
                layOut()
                if isDone {
                    self.timer?.invalidate()
                    self.timer = nil
                    isIdle = true
                    layOut()
                    let finish = self.completion
                    self.completion = nil
                    finish?()
                }
            }
        }
        RunLoop.main.add(foldTimer, forMode: .common)
        timer = foldTimer
    }

    /// Runs once a starting fold has replaced the real rows: shown beside them, the stand-in makes the menu taller for a frame.
    func layOut() {
        // `NSMenu` gives a shown item at least 1 pt, and the rows below would jump by that much as a fold starts and ends.
        item.isHidden = isIdle
        let total = isIdle ? 0 : rows.frame.height + height
        container.setFrameSize(NSSize(width: Metrics.width, height: total))
        let visibleGroup = isOpening ? height : groupHeight
        groupClip.frame = NSRect(x: 0, y: total - visibleGroup, width: Metrics.width, height: visibleGroup)
        group.setFrameOrigin(NSPoint(x: 0, y: visibleGroup - groupHeight))
        item.menu?.itemChanged(item)
    }
}

/// The Sound menu's fold, read frame by frame from a 120 fps recording on macOS 27.2, the same in both directions (`docs/sound-menu.md`, Fold animation). The values are the recording itself, not a fit: a spring fitted to it missed by up to 13 points of progress.
enum FoldCurve {
    /// The band and rows start to fade 40 ms before the edge moves.
    private static let edgeDelay: TimeInterval = 0.04
    private static let positionStep: TimeInterval = 0.016
    private static let positions: [Double] = [
        0, 0.017, 0.04, 0.075, 0.12, 0.177, 0.239, 0.302, 0.368, 0.436, 0.499, 0.562, 0.623, 0.673, 0.72, 0.761, 0.793,
        0.821, 0.847, 0.869, 0.889, 0.906, 0.921,
        0.933, 0.943, 0.951, 0.96, 0.966, 0.971, 0.976, 0.98, 0.983, 0.985, 0.988, 0.99, 0.992, 0.993, 0.994, 0.995,
        0.996, 0.997, 0.997, 0.998, 0.998, 0.999, 0.999, 0.999, 1,
    ]
    private static let fadeStep: TimeInterval = 0.008
    private static let fades: [Double] = [
        0, 0.024, 0.048, 0.083, 0.155, 0.202, 0.286, 0.333, 0.405, 0.464, 0.536, 0.583, 0.643, 0.69, 0.726, 0.774,
        0.798,
        0.81, 0.833, 0.857, 0.893, 0.905, 0.91, 0.929,
        0.94, 0.952, 0.958, 0.964, 0.976, 0.988, 1,
    ]

    static let duration = edgeDelay + positionStep * Double(positions.count - 1)

    static func position(at time: TimeInterval) -> Double {
        value(in: positions, step: positionStep, at: time - edgeDelay)
    }

    static func fade(at time: TimeInterval) -> Double {
        value(in: fades, step: fadeStep, at: time)
    }

    private static func value(in values: [Double], step: TimeInterval, at time: TimeInterval) -> Double {
        let place = time / step
        guard place > 0 else { return values[0] }
        let index = Int(place)
        guard index < values.count - 1 else { return values[values.count - 1] }
        return values[index] + (values[index + 1] - values[index]) * (place - Double(index))
    }
}
