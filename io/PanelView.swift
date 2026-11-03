import Priority
import SwiftUI

/// Sizes in points and the grey opacities below, measured on a Light Mode screenshot of the system Sound menu on macOS 27.
enum Metrics {
    static let width: CGFloat = 308
    static let topInset: CGFloat = 5
    static let edgeInset: CGFloat = 5
    static let contentInset: CGFloat = 14
    static let headerHeight: CGFloat = 22
    static let deviceRowHeight: CGFloat = 32
    static let menuRowHeight: CGFloat = 22
    static let iconSize: CGFloat = 26
    static let glyphSize: CGFloat = 13
    static let trackHeight: CGFloat = 6
    static let knobWidth: CGFloat = 20
    static let knobHeight: CGFloat = 16
    /// Half the menu row height: the Sound menu's highlight on "Sound Settings…" is a capsule.
    static let highlightRadius: CGFloat = 11
    /// A shorter move is a click, so a click never reorders.
    static let dragThreshold: CGFloat = 4
    static let chevronSize: CGFloat = 12
    static let hideWidth: CGFloat = 110
    /// A standard menu item's highlight, measured at 2x.
    static let hideRowHeight: CGFloat = 24
    static let hideHighlightRadius: CGFloat = 7
    static let hideTextInset: CGFloat = 11
    static let liftScale: CGFloat = 1.02
    static let slide = Animation.easeOut(duration: 0.15)
}

/// The panel's pieces stacked in one view, for `-renderPanelTo`. The menu itself shows each piece as its own `NSMenuItem` (ADR 0001).
struct PanelView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VolumeSlider(model: model)
            PanelSeparator(inset: Metrics.contentInset)
            ForEach(Direction.allCases, id: \.self) { direction in
                SectionHeader(direction: direction)
                ForEach(model.rows[direction] ?? []) { row in
                    DeviceRow(model: model, direction: direction, device: row.device)
                }
                PanelSeparator(inset: direction.separatorInset)
            }
            if model.airPodsName != nil {
                AirPodsSettingsRow(model: model, action: model.openAirPodsSettings)
            }
            MenuRow(title: "Sound Settings…", action: model.openSoundSettings)
            PanelSeparator(inset: Metrics.edgeInset)
            PanelFooter()
        }
    }
}

/// "Sound" and the slider for the volume of the output in use, at the top of the panel.
/// Drawn by hand, because a system `Slider` in a menu draws in its inactive grey, where the Sound menu's fill is the accent colour.
struct VolumeSlider: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sound")
                .font(.system(size: 13, weight: .bold))
                .padding(.leading, Metrics.contentInset)
            HStack(spacing: 3.5) {
                Image(systemName: "speaker.fill")
                Track(value: model.volume ?? 0, set: model.setVolume)
                Image(systemName: "speaker.wave.3.fill")
            }
            .font(.system(size: 16))
            .foregroundStyle(Color.primary.opacity(0.55))
            .padding(.leading, 15)
            .padding(.trailing, 16)
            .disabled(model.volume == nil)
            .opacity(model.volume == nil ? 0.4 : 1)
        }
        .padding(.top, Metrics.topInset + 3)
        .padding(.bottom, 5)
        .frame(width: Metrics.width, alignment: .leading)
    }

    private struct Track: View {
        let value: Float
        let set: (Float) -> Void
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            GeometryReader { geometry in
                let travel = geometry.size.width - Metrics.knobWidth
                let knobX = travel * CGFloat(value)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                        .frame(height: Metrics.trackHeight)
                    Capsule().fill(Color.accentColor)
                        .frame(width: knobX + Metrics.knobWidth / 2, height: Metrics.trackHeight)
                    Knob().fill(.white)
                        .shadow(color: .black.opacity(0.16), radius: 1.5, y: 2)
                        .frame(width: Metrics.knobWidth, height: Metrics.knobHeight)
                        .offset(x: knobX)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            guard isEnabled, travel > 0 else { return }
                            let fraction = (drag.location.x - Metrics.knobWidth / 2) / travel
                            set(Float(min(max(fraction, 0), 1)))
                        })
            }
            .frame(height: Metrics.knobHeight)
        }
    }

    /// A superellipse: the Sound menu's knob is fuller than an ellipse and rounder than a rounded rectangle, and an exponent of 2.3 fits its outline row by row at 2x.
    nonisolated private struct Knob: Shape {
        func path(in rect: CGRect) -> Path {
            let exponent = 2.3
            var path = Path()
            for step in 0...120 {
                let angle = Double(step) / 120 * 2 * .pi
                let x = pow(abs(cos(angle)), 2 / exponent) * (cos(angle) < 0 ? -1 : 1)
                let y = pow(abs(sin(angle)), 2 / exponent) * (sin(angle) < 0 ? -1 : 1)
                let point = CGPoint(x: rect.midX + x * rect.width / 2, y: rect.midY + y * rect.height / 2)
                step == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()
            return path
        }
    }
}

extension Direction {
    fileprivate var title: String {
        self == .output ? "Output" : "Input"
    }

    /// The Sound menu insets the line between device sections to the text, and the line above the settings links to the highlight.
    var separatorInset: CGFloat {
        self == .output ? Metrics.contentInset : Metrics.edgeInset
    }
}

struct SectionHeader: View {
    let direction: Direction

    var body: some View {
        Text(direction.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.primary.opacity(0.48))
            .padding(.horizontal, Metrics.contentInset)
            .frame(width: Metrics.width, height: Metrics.headerHeight, alignment: .leading)
    }
}

/// What a drag on a device row reports. The drag itself is drawn by `DragLayer`, in a window over the open menu (ADR 0001).
struct RowDragActions {
    let pressed: (_ device: Device, _ direction: Direction) -> Void
    let changed: (_ device: Device, _ direction: Direction, _ translation: CGFloat) -> Void
    let released: () -> Void
}

struct DeviceRow: View {
    let model: AppModel
    let direction: Direction
    let device: Device
    var dragActions: RowDragActions?
    var openSubmenu: OpenSubmenu?

    var body: some View {
        if let row = model.rows[direction]?.first(where: { $0.id == device.uid }) {
            DeviceRowLabel(row: row, direction: direction, isLifted: false, isSubmenuOpen: openSubmenu?.uid == device.uid)
                .gesture(reorderOrUse(row))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in dragActions?.pressed(device, direction) }
                        .onEnded { _ in dragActions?.released() })
                .accessibilityAddTraits(row.isConnected ? .isButton : [])
                .accessibilityAction {
                    if row.isConnected {
                        model.use(row.device, in: direction)
                    }
                }
        }
    }

    private func reorderOrUse(_ row: AppModel.Row) -> some Gesture {
        DragGesture(minimumDistance: Metrics.dragThreshold, coordinateSpace: .global)
            .onChanged { dragActions?.changed(device, direction, $0.translation.height) }
            .exclusively(
                before: TapGesture().onEnded {
                    if row.isConnected {
                        model.use(row.device, in: direction)
                    }
                })
    }
}

private struct DeviceRowLabel: View {
    let row: AppModel.Row
    let direction: Direction
    let isLifted: Bool
    var isSubmenuOpen = false

    var body: some View {
        HoverRow(height: Metrics.deviceRowHeight, isHighlighted: isSubmenuOpen, logName: "\(direction.title) \"\(row.device.name)\"") {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: row.symbolName)
                        .font(.system(size: Metrics.glyphSize))
                        .foregroundStyle(row.isInUse ? Color.white : Color.primary.opacity(0.5))
                        .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                        .background(Circle().fill(row.isInUse ? Color.accentColor : Color.primary.opacity(0.1)))
                    Text(row.device.name)
                        .lineLimit(1)
                }
                .opacity(row.isConnected ? 1 : 0.4)
                Spacer(minLength: 0)
                if row.canHide {
                    Image(systemName: "chevron.right")
                        .font(.system(size: Metrics.chevronSize, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.7))
                }
            }
        }
        .background {
            if isLifted {
                RoundedRectangle(cornerRadius: Metrics.highlightRadius)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            }
        }
        .scaleEffect(isLifted ? Metrics.liftScale : 1)
        .padding(.horizontal, Metrics.edgeInset)
        .frame(width: Metrics.width)
    }
}

/// Which row's "Hide" submenu is open, so the row keeps its highlight while the pointer is in the submenu, like a standard menu item.
@Observable final class OpenSubmenu: NSObject, NSMenuDelegate {
    var uid: String?

    func menuWillOpen(_ menu: NSMenu) {
        uid = menu.items.first?.representedObject as? String
    }

    func menuDidClose(_ menu: NSMenu) {
        if uid == menu.items.first?.representedObject as? String {
            uid = nil
        }
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
        return min(max(from + shift, 0), rows.count - 1)
    }
}

/// The rows of one section during a drag: the dragged row follows the pointer, lifted, and the others slide out of its way.
struct DragLayer: View {
    let model: AppModel
    let drag: RowDrag

    private var rows: [AppModel.Row] { model.rows[drag.direction] ?? [] }

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
        guard let from = rows.firstIndex(where: { $0.id == drag.uid }), let to = drag.targetIndex(in: rows) else { return 0 }
        if index == from {
            let up = -CGFloat(from) * Metrics.deviceRowHeight
            let down = CGFloat(rows.count - 1 - from) * Metrics.deviceRowHeight
            return min(max(drag.translation, up), down)
        }
        if from < index && index <= to {
            return -Metrics.deviceRowHeight
        }
        if to <= index && index < from {
            return Metrics.deviceRowHeight
        }
        return 0
    }
}

struct PanelFooter: View {
    @State private var opensAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Open at Login")
                Spacer()
                Toggle("Open at Login", isOn: opensAtLoginBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal, Metrics.contentInset)
            .frame(height: Metrics.menuRowHeight)

            MenuRow(title: "Quit io") { NSApp.terminate(nil) }
        }
        .frame(width: Metrics.width, alignment: .leading)
        .onAppear { opensAtLogin = LoginItem.isEnabled }
    }

    private var opensAtLoginBinding: Binding<Bool> {
        Binding(
            get: { opensAtLogin },
            set: { enabled in
                LoginItem.setEnabled(enabled)
                opensAtLogin = LoginItem.isEnabled
            }
        )
    }
}

struct PanelSeparator: View {
    let inset: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, inset)
            .padding(.top, 5)
            .padding(.bottom, 4)
            .frame(width: Metrics.width)
    }
}

/// The "Hide" item of a row's submenu. A custom view, because AppKit closes the whole panel when a standard item is chosen.
struct HideRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HoverRow(height: Metrics.hideRowHeight, radius: Metrics.hideHighlightRadius, textInset: Metrics.hideTextInset, isAccented: true) {
                Text("Hide")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Metrics.edgeInset)
        .frame(width: Metrics.hideWidth)
    }
}

/// Shown only while AirPods are connected; it follows a rename while the menu is open.
struct AirPodsSettingsRow: View {
    let model: AppModel
    let action: () -> Void

    var body: some View {
        MenuRow(title: "\(model.airPodsName ?? "AirPods") Settings…", action: action)
    }
}

struct MenuRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HoverRow(height: Metrics.menuRowHeight) {
                Text(title)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Metrics.edgeInset)
        .frame(width: Metrics.width)
    }
}

/// A row that highlights under the pointer like a menu item. The caller insets it from the panel edge. An accented row highlights in the accent colour, like a standard menu item; the panel rows keep the Sound menu's grey.
private struct HoverRow<Content: View>: View {
    let height: CGFloat
    var radius = Metrics.highlightRadius
    var textInset = Metrics.contentInset - Metrics.edgeInset
    var isHighlighted = false
    var isAccented = false
    var logName: String?
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false

    var body: some View {
        content()
            .foregroundStyle(isAccented && isHovered ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, textInset)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(isHovered || isHighlighted ? (isAccented ? Color.accentColor : Color.primary.opacity(0.09)) : .clear)
            )
            .onHover { hovering in
                isHovered = hovering
                if let logName {
                    panelLog.notice("hover \(hovering ? "enter" : "exit", privacy: .public) \(logName, privacy: .public)")
                }
            }
    }
}
