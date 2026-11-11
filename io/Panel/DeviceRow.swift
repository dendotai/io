import Priority
import SwiftUI

/// What a drag on a device row reports. The drag itself is drawn by `DragLayer`, in a window over the open menu (ADR 0001).
struct RowDragActions {
    let changed: (_ device: Device, _ direction: Direction, _ translation: CGFloat) -> Void
    let released: () -> Void
}

struct DeviceRow: View {
    let model: AppModel
    let direction: Direction
    let device: Device
    var dragActions: RowDragActions?
    var hide: (() -> Void)?

    var body: some View {
        if let row = model.rows[direction]?.first(where: { $0.id == device.uid }) {
            DeviceRowLabel(row: row, direction: direction, isLifted: false, hide: hide) {
                model.toggleListeningModes(of: device)
            }
            .gesture(reorderOrUse(row))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in dragActions?.released() }
            )
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(row.isConnected ? .isButton : [])
            .accessibilityAction { use(row) }
            .accessibilityActions {
                // The Hide button shows only under the pointer, which VoiceOver does not move.
                if row.canHide, let hide {
                    Button("Hide", action: hide)
                }
            }
        }
    }

    private func reorderOrUse(_ row: AppModel.Row) -> some Gesture {
        DragGesture(minimumDistance: Metrics.dragThreshold, coordinateSpace: .global)
            .onChanged {
                if row.canReorder {
                    dragActions?.changed(device, direction, $0.translation.height)
                }
            }
            .exclusively(before: TapGesture().onEnded { use(row) })
    }

    private func use(_ row: AppModel.Row) {
        if row.isConnected {
            model.use(row.device, in: direction)
        }
    }
}

struct DeviceRowLabel: View {
    let row: AppModel.Row
    let direction: Direction
    let isLifted: Bool
    /// nil in the drag layer and the fold's rows, which show no Hide button.
    var hide: (() -> Void)?
    /// nil in the drag layer, where the ⌄ only shows.
    var toggleListeningModes: (() -> Void)?

    var body: some View {
        HoverRow(
            height: Metrics.deviceRowHeight,
            radius: Metrics.deviceHighlightRadius,
            logName: "\(direction.title) \"\(row.device.name)\""
        ) { isHovered in
            HStack(spacing: 8) {
                identity
                    .opacity(row.isConnected ? 1 : 0.4)
                Spacer(minLength: 0)
                if let single = row.batteryLevels?.single {
                    SingleBatteryLevel(percent: single)
                }
                trailingButton(isHovered: isHovered)
            }
        }
        .background {
            if isLifted {
                RoundedRectangle(cornerRadius: Metrics.deviceHighlightRadius)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            }
        }
        .scaleEffect(isLifted ? Metrics.liftScale : 1)
        .padding(.horizontal, Metrics.edgeInset)
        .frame(width: Metrics.width)
    }

    /// The device's glyph, its name, and the battery line under the name.
    private var identity: some View {
        HStack(spacing: 8) {
            Image(systemName: row.symbolName)
                .font(.system(size: Metrics.glyphSize))
                .foregroundStyle(row.isInUse ? Color.white : Color.primary.opacity(0.5))
                .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                .background(Circle().fill(row.isInUse ? Color.accentColor : Color.primary.opacity(0.1)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.device.name)
                    .lineLimit(1)
                if let batteryLevels = row.batteryLevels, batteryLevels.single == nil {
                    BatteryLine(battery: batteryLevels, symbolName: row.symbolName)
                }
            }
        }
    }

    /// The Hide button, shown on hover, or the listening-mode chevron.
    @ViewBuilder
    private func trailingButton(isHovered: Bool) -> some View {
        if row.canHide, let hide {
            Button(action: hide) {
                Image(systemName: "eye.slash")
                    .imageScale(.small)
            }
            .buttonStyle(RowButtonStyle())
            .opacity(isHovered ? 1 : 0)
            .accessibilityHidden(true)
        } else if row.listening != nil {
            Button {
                toggleListeningModes?()
            } label: {
                Image(systemName: row.isFoldedOpen ? "chevron.down" : "chevron.right")
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.linear(duration: Metrics.foldChevronSwapDuration), value: row.isFoldedOpen)
            }
            .buttonStyle(RowButtonStyle())
            .accessibilityLabel("Listening Mode")
        }
    }
}

/// The buds', or each bud's, and the case's levels under a headphones row's name, as in the Sound menu.
private struct BatteryLine: View {
    let battery: BatteryLevels
    let symbolName: String

    var body: some View {
        HStack(spacing: Metrics.batteryGap) {
            if let buds = battery.buds {
                level(buds, symbolName: symbolName, name: "Battery", gap: Metrics.budsGlyphGap)
            }
            if let left = battery.left {
                level(
                    left,
                    symbolName: DeviceSymbol.bud(of: symbolName, side: "left"),
                    name: "Left",
                    gap: Metrics.budGlyphGap
                )
            }
            if let right = battery.right {
                level(
                    right,
                    symbolName: DeviceSymbol.bud(of: symbolName, side: "right"),
                    name: "Right",
                    gap: Metrics.budGlyphGap
                )
            }
            if let chargingCase = battery.chargingCase {
                level(
                    chargingCase,
                    symbolName: DeviceSymbol.chargingCase(of: symbolName),
                    name: "Case",
                    gap: Metrics.caseGlyphGap
                )
            }
        }
        .font(.system(size: Metrics.batteryTextSize))
        .foregroundStyle(.secondary)
    }

    private func level(_ percent: Int, symbolName: String, name: String, gap: CGFloat) -> some View {
        HStack(spacing: gap) {
            Image(systemName: symbolName).accessibilityLabel(name)
            Text("\(percent)%")
        }
    }
}

/// The level of headphones with one battery, at the row's right, as in the Sound menu. The glyph is drawn from shapes because the Sound menu's outline is paler than its fill.
private struct SingleBatteryLevel: View {
    let percent: Int

    var body: some View {
        HStack(spacing: Metrics.singleBatteryGlyphGap) {
            Text("\(percent)%")
                .font(.system(size: Metrics.singleBatteryTextSize))
                .foregroundStyle(.secondary)
            HStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Metrics.singleBatteryBodyRadius)
                        .strokeBorder(Color.primary.opacity(Metrics.singleBatteryOutlineOpacity), lineWidth: 1)
                    RoundedRectangle(cornerRadius: Metrics.singleBatteryFillRadius)
                        .fill(Color.primary.opacity(Metrics.singleBatteryFillOpacity))
                        .frame(
                            width: Metrics.singleBatteryFillWidth * CGFloat(percent) / 100,
                            height: Metrics.singleBatteryFillHeight
                        )
                        .padding(.leading, 2)
                }
                .frame(width: Metrics.singleBatteryBodyWidth, height: Metrics.singleBatteryBodyHeight)
                UnevenRoundedRectangle(
                    bottomTrailingRadius: Metrics.singleBatteryNubWidth,
                    topTrailingRadius: Metrics.singleBatteryNubWidth
                )
                .fill(Color.primary.opacity(Metrics.singleBatteryOutlineOpacity))
                .frame(width: Metrics.singleBatteryNubWidth, height: Metrics.singleBatteryNubHeight)
            }
        }
        .fixedSize()
        .padding(.trailing, Metrics.singleBatteryTrailing)
    }
}

@Observable final class RowDrag {
    let direction: Direction
    var uid: String?
    var translation: CGFloat = 0

    init(direction: Direction) {
        self.direction = direction
    }

    func targetIndex(in rows: [AppModel.Row]) -> Int? {
        guard let from = rows.firstIndex(where: { $0.id == uid }) else { return nil }
        let shift = Int((translation / Metrics.deviceRowHeight).rounded())
        return min(max(from + shift, Self.topIndex(in: rows)), rows.count - 1)
    }

    /// The highest place a dragged row can reach: under the rows that cannot be reordered, such as the AirPlay row.
    static func topIndex(in rows: [AppModel.Row]) -> Int {
        rows.firstIndex(where: \.canReorder) ?? 0
    }

    func drop(into model: AppModel) {
        let rows = model.rows[direction] ?? []
        guard let from = rows.firstIndex(where: { $0.id == uid }), let target = targetIndex(in: rows),
              target != from else { return }
        model.reorder(rows[from].device, to: target, in: direction)
    }
}

/// The rows of one section during a drag: the dragged row follows the pointer, lifted, and the others slide out of its way.
struct DragLayer: View {
    let model: AppModel
    let drag: RowDrag

    private var rows: [AppModel.Row] {
        model.rows[drag.direction] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                let isLifted = row.id == drag.uid
                DeviceRowLabel(row: row, direction: drag.direction, isLifted: isLifted)
                    .offset(y: offset(at: index))
                    .animation(isLifted ? nil : Metrics.slide, value: offset(at: index))
                    .zIndex(isLifted ? 1 : 0)
            }
        }
    }

    private func offset(at index: Int) -> CGFloat {
        guard let from = rows.firstIndex(where: { $0.id == drag.uid }),
              let target = drag.targetIndex(in: rows) else { return 0 }
        if index == from {
            let upLimit = -CGFloat(from - RowDrag.topIndex(in: rows)) * Metrics.deviceRowHeight
            let downLimit = CGFloat(rows.count - 1 - from) * Metrics.deviceRowHeight
            return min(max(drag.translation, upLimit), downLimit)
        }
        if from < index, index <= target {
            return -Metrics.deviceRowHeight
        }
        if target <= index, index < from {
            return Metrics.deviceRowHeight
        }
        return 0
    }
}
