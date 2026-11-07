import AppKit
import Priority

/// A section's drag layer: the drag state its view draws, and the item that holds the view.
struct DragLayerItem {
    let rowDrag: RowDrag
    let item: NSMenuItem
}

/// Follows a reorder from the drag's first move to its end. The row that started the drag leaves the menu at the swap, so its drag events keep coming but report a wrong distance: each one reads the pointer instead, and a timer ends the drag if the release never reaches the row.
final class RowDragTracker {
    private struct Drag {
        let direction: Direction
        let startY: CGFloat
        let timer: Timer
        var ticksSinceButtonUp = 0
    }

    private static let releaseTick: TimeInterval = 1.0 / 60
    /// The release reaches the row within about 50 ms after the button goes up, so 200 ms leaves room.
    private static let releaseWait: TimeInterval = 0.2
    private static let releaseTicks = Int((releaseWait / releaseTick).rounded())

    private let model: AppModel
    private let layers: PerDirection<DragLayerItem>
    private var drag: Drag?
    /// The menu swaps the dragged row's section for its drag layer.
    var didStart: (() -> Void)?
    /// The menu swaps the rows back; the window is the drag layer's, taken before it leaves, because the swapped-in row views are not in the menu's window yet.
    var didEnd: ((NSWindow?) -> Void)?

    /// The section whose drag layer shows in place of its rows.
    var direction: Direction? { drag?.direction }

    init(model: AppModel, layers: PerDirection<DragLayerItem>) {
        self.model = model
        self.layers = layers
    }

    func changed(_ device: Device, in direction: Direction, translation: CGFloat) {
        let pointerY = NSEvent.mouseLocation.y
        if let drag {
            let moved = drag.startY - pointerY
            let state = layers[drag.direction].rowDrag
            if moved != state.translation {
                state.translation = moved
            }
            return
        }
        let layer = layers[direction]
        layer.rowDrag.uid = device.uid
        layer.rowDrag.translation = translation
        // The section may have gained or lost rows since the panel was built.
        if let view = layer.item.view {
            view.setFrameSize(view.fittingSize)
        }
        let timer = Timer(timeInterval: Self.releaseTick, repeats: true) { [weak self] _ in
            self?.watchRelease()
        }
        RunLoop.main.add(timer, forMode: .common)
        // The first event's translation is still right, and holds the move made before the drag began.
        drag = Drag(direction: direction, startY: pointerY + translation, timer: timer)
        panelLog.notice("drag start \(String(describing: direction)) \"\(device.name)\"")
        didStart?()
    }

    /// Ends the drag once the menu has handled the release that reached it.
    func endAfterRelease() {
        RunLoop.main.perform(inModes: [.common]) { [weak self] in self?.end() }
    }

    private func watchRelease() {
        guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
        drag?.ticksSinceButtonUp += 1
        if let drag, drag.ticksSinceButtonUp > Self.releaseTicks {
            end()
        }
    }

    private func end() {
        guard let drag else { return }
        drag.timer.invalidate()
        self.drag = nil
        panelLog.notice("drag end")
        let layer = layers[drag.direction]
        if let move = layer.rowDrag.move(in: model.rows[drag.direction] ?? []) {
            model.reorder(move.device, to: move.to, in: drag.direction)
        }
        layer.rowDrag.uid = nil
        didEnd?(layer.item.view?.window)
    }
}
