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
    // The Battery line in `docs/sound-menu.md`; each gap is set so the ink lands where the crop shows it.
    static let batteryTextSize: CGFloat = 11
    static let budsGlyphGap: CGFloat = 2
    static let budGlyphGap: CGFloat = 4
    static let caseGlyphGap: CGFloat = 4
    static let batteryGap: CGFloat = 8
    // The One-battery level in `docs/sound-menu.md`; each value is set so the ink lands where the crop shows it.
    static let singleBatteryTextSize: CGFloat = 12
    static let singleBatteryGlyphGap: CGFloat = 2
    static let singleBatteryTrailing: CGFloat = 6.5
    static let singleBatteryBodyWidth: CGFloat = 19
    static let singleBatteryBodyHeight: CGFloat = 10
    static let singleBatteryBodyRadius: CGFloat = 3
    static let singleBatteryFillWidth: CGFloat = 15
    static let singleBatteryFillHeight: CGFloat = 6
    static let singleBatteryFillRadius: CGFloat = 1.5
    static let singleBatteryNubWidth: CGFloat = 1.25
    static let singleBatteryNubHeight: CGFloat = 4
    static let singleBatteryFillOpacity: CGFloat = 0.43
    static let singleBatteryOutlineOpacity: CGFloat = 0.23
    // The Listening mode row and the heading text in `docs/sound-menu.md`: the heading 19 below the AirPods row, the rows 3 below the heading and 24 apart, the next device row 10 below the last row's 26.
    static let listeningHeadingTop: CGFloat = 19
    static let listeningHeadingTextHeight: CGFloat = 15
    static let listeningRowsTop: CGFloat = 3
    static let listeningRowPitch: CGFloat = 24
    static let listeningGroupBottom: CGFloat = 12
    // From one 2x crop of the Sound menu in Dark Mode (`docs/sound-menu.md`, Listening mode row): the band behind the group starts 4.5 below the AirPods row and ends 5 below the last mode row. The columns are set so the checkmark, glyph, and text ink lands 20, 49, and 73 in from the body's edge, as in the crop.
    static let listeningBandTop: CGFloat = 4.5
    static let listeningBandBottom: CGFloat = 5
    static let listeningCheckmarkInset: CGFloat = 5
    static let listeningCheckmarkColumn: CGFloat = 32
    static let listeningIconColumn: CGFloat = 27
    static let listeningIconSize: CGFloat = 18
    /// The fold's "›" and "⌄" turn around one centre 22 in from the body's edge, with a lighter stroke than the "›" of a submenu: a 2x crop of the Sound menu in Dark Mode, peak grey 128 on 51.
    static let foldChevronWidth: CGFloat = 16
    /// The swap's length in `docs/sound-menu.md`, Fold animation. Linear, because `.default` reached the last pixel 333 ms after the one before, against 17-50 ms in the Sound menu.
    static let foldChevronSwapDuration: TimeInterval = 0.45
    static let foldChevronOpacity: CGFloat = 0.45
    /// The Sound menu's ⌄ ink strengthens during a press (`docs/sound-menu.md`, Fold chevron, real pointer): grey 150 to 38; io's ink at 0.85 read 66, so the press takes the full primary colour.
    static let foldChevronPressedOpacity: CGFloat = 1
    static let hideWidth: CGFloat = 110
    /// A standard menu item's highlight, measured at 2x.
    static let hideRowHeight: CGFloat = 24
    static let hideHighlightRadius: CGFloat = 7
    static let hideTextInset: CGFloat = 11
    static let rightClickMenuWidth: CGFloat = 190
    static let switchWidth: CGFloat = 35
    static let switchHeight: CGFloat = 15
    static let switchKnobWidth: CGFloat = 20
    static let switchKnobInset: CGFloat = 1.5
    static let liftScale: CGFloat = 1.02
    static let slide = Animation.easeOut(duration: 0.15)
}

/// The panel's pieces stacked in one view, for `-renderPanelTo`. The menu itself shows each piece as its own `NSMenuItem` (ADR 0001).
struct PanelView: View {
    let model: AppModel
    let updater: AppUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VolumeSlider(model: model)
            PanelSeparator(inset: Metrics.contentInset)
            ForEach(Direction.allCases, id: \.self) { direction in
                SectionHeader(model: model, direction: direction)
                ForEach(model.rows[direction] ?? []) { row in
                    DeviceRow(model: model, direction: direction, device: row.device)
                    if row.isFoldedOpen, let modes = row.listening?.supported {
                        ListeningModeGroup(model: model, device: row.device, modes: modes)
                    }
                }
                PanelSeparator(inset: direction.separatorInset)
            }
            if model.airPodsName != nil {
                AirPodsSettingsRow(model: model, action: model.openAirPodsSettings)
            }
            MenuRow(title: "Sound Settings…", action: model.openSoundSettings)
            if updater.availableVersion != nil {
                PanelSeparator(inset: Metrics.edgeInset)
                UpdateRow(updater: updater, isHighlighted: UserDefaults.standard.bool(forKey: "renderUpdateHighlighted"), action: updater.installUpdate)
            }
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
                Track(value: model.sliderVolume ?? 0, set: model.setVolume)
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
    let model: AppModel
    let direction: Direction

    var body: some View {
        HStack(spacing: 0) {
            Text(direction.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.48))
            Spacer(minLength: 0)
            if model.canEndHandPick[direction] == true {
                Button {
                    model.endHandPick(in: direction)
                } label: {
                    Text("Back to Auto")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metrics.contentInset)
        .frame(width: Metrics.width, height: Metrics.headerHeight)
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
            DeviceRowLabel(row: row, direction: direction, isLifted: false, isSubmenuOpen: openSubmenu?.uid == device.uid) {
                model.toggleListeningModes(of: device)
            }
            .gesture(reorderOrUse(row))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in dragActions?.pressed(device, direction) }
                        .onEnded { _ in dragActions?.released() })
                .accessibilityElement(children: .contain)
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
    /// nil in the drag layer, where the ⌄ only shows.
    var toggleListeningModes: (() -> Void)?
    @State private var isFoldChevronHovered = false

    var body: some View {
        HoverRow(height: Metrics.deviceRowHeight, isHighlighted: isSubmenuOpen, isHoverHighlightHidden: isFoldChevronHovered, logName: "\(direction.title) \"\(row.device.name)\"") {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: row.symbolName)
                        .font(.system(size: Metrics.glyphSize))
                        .foregroundStyle(row.isInUse ? Color.white : Color.primary.opacity(0.5))
                        .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                        .background(Circle().fill(row.isInUse ? Color.accentColor : Color.primary.opacity(0.1)))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.device.name)
                            .lineLimit(1)
                        if let batteryLevels = row.batteryLevels, batteryLevels.single == nil {
                            BatteryLine(battery: batteryLevels, symbolName: row.symbolName)
                        }
                    }
                }
                .opacity(row.isConnected ? 1 : 0.4)
                Spacer(minLength: 0)
                if let single = row.batteryLevels?.single {
                    SingleBatteryLevel(percent: single)
                }
                if row.canHide {
                    Image(systemName: "chevron.right")
                        .font(.system(size: Metrics.chevronSize, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.7))
                } else if row.listening != nil {
                    Button {
                        toggleListeningModes?()
                    } label: {
                        Image(systemName: row.isFoldedOpen ? "chevron.down" : "chevron.right")
                            .font(.system(size: Metrics.chevronSize))
                            .contentTransition(.symbolEffect(.replace))
                            .animation(.linear(duration: Metrics.foldChevronSwapDuration), value: row.isFoldedOpen)
                            .frame(width: Metrics.foldChevronWidth, height: Metrics.iconSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(FoldChevronButtonStyle())
                    .onHover { isFoldChevronHovered = $0 }
                    .accessibilityLabel("Listening Mode")
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

/// What a fold holds: the heading and one row per mode.
struct ListeningModeGroup: View {
    let model: AppModel
    let device: Device
    let modes: [ListeningMode]

    var body: some View {
        VStack(spacing: 0) {
            ListeningModeHeading()
            ForEach(modes, id: \.self) { mode in
                ListeningModeRow(model: model, device: device, mode: mode)
            }
        }
        .background(ListeningBand().padding(.top, Metrics.listeningBandTop).padding(.bottom, Metrics.listeningBandBottom))
    }
}

/// "Listening Mode" under an AirPods row folded open, with the gap above it that the Sound menu leaves.
struct ListeningModeHeading: View {
    var body: some View {
        Text("Listening Mode")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.primary.opacity(0.48))
            .frame(height: Metrics.listeningHeadingTextHeight)
            .padding(.top, Metrics.listeningHeadingTop)
            .padding(.bottom, Metrics.listeningRowsTop)
            .padding(.horizontal, Metrics.contentInset)
            .frame(width: Metrics.width, alignment: .leading)
    }
}

/// The band behind the listening mode group, edge to edge, with a 1 pt line on its top and bottom edges, as in the Sound menu. In Dark Mode the line and the band are one grey (`docs/sound-menu.md`, Listening mode band).
private struct ListeningBand: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            line
            Rectangle().fill(Color.primary.opacity(colorScheme == .dark ? 0.11 : 0.046))
            line
        }
    }

    private var line: some View {
        Rectangle().fill(Color.primary.opacity(colorScheme == .dark ? 0.11 : 0.095)).frame(height: 1)
    }
}

/// The rows a fold moves: the rest of the Output list and the Input list, drawn with no gestures for the length of the fold.
struct FoldBelowRows: View {
    let model: AppModel
    let uid: String

    var body: some View {
        let output = model.rows[.output] ?? []
        let start = output.firstIndex { $0.id == uid }.map { $0 + 1 } ?? output.count
        VStack(spacing: 0) {
            ForEach(output[start...]) { row in
                DeviceRowLabel(row: row, direction: .output, isLifted: false)
                if row.isFoldedOpen, let modes = row.listening?.supported {
                    ListeningModeGroup(model: model, device: row.device, modes: modes)
                }
            }
            PanelSeparator(inset: Direction.output.separatorInset)
            SectionHeader(model: model, direction: .input)
            ForEach(model.rows[.input] ?? []) { row in
                DeviceRowLabel(row: row, direction: .input, isLifted: false)
            }
            PanelSeparator(inset: Direction.input.separatorInset)
        }
        // These rows enter the window under the pointer before the fold lays them out, and a hover started there never ends.
        .allowsHitTesting(false)
    }
}


/// One mode under "Listening Mode", with a checkmark on the current one. The last row carries the gap to the next device row.
struct ListeningModeRow: View {
    let model: AppModel
    let device: Device
    let mode: ListeningMode

    private var row: AppModel.Row? { model.rows[.output]?.first { $0.id == device.uid } }
    private var isLast: Bool { row?.listening?.supported.last == mode }

    var body: some View {
        Button {
            model.setListeningMode(mode, of: device)
        } label: {
            HoverRow(height: Metrics.listeningRowPitch, logName: "listening mode") {
                HStack(spacing: 0) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(row?.listening?.current == mode ? 1 : 0)
                        .padding(.leading, Metrics.listeningCheckmarkInset)
                        .frame(width: Metrics.listeningCheckmarkColumn, alignment: .leading)
                    Group {
                        if let icon = ListeningModeIcon.images[mode] {
                            Image(nsImage: icon)
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: Metrics.listeningIconSize, height: Metrics.listeningIconSize)
                                .foregroundStyle(Color.primary.opacity(0.5))
                        }
                    }
                    .frame(width: Metrics.listeningIconColumn, alignment: .leading)
                    Text(mode.title)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Metrics.edgeInset)
        .padding(.bottom, isLast ? Metrics.listeningGroupBottom : 0)
        .frame(width: Metrics.width)
        .accessibilityAddTraits(row?.listening?.current == mode ? .isSelected : [])
    }
}

extension ListeningMode {
    var title: String {
        switch self {
        case .off: "Off"
        case .transparency: "Transparency"
        case .adaptive: "Adaptive"
        case .noiseCancellation: "Noise Cancellation"
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
                level(buds, symbolName: symbolName, gap: Metrics.budsGlyphGap)
            }
            if let left = battery.left {
                level(left, symbolName: DeviceSymbol.bud(of: symbolName, side: "left"), gap: Metrics.budGlyphGap)
            }
            if let right = battery.right {
                level(right, symbolName: DeviceSymbol.bud(of: symbolName, side: "right"), gap: Metrics.budGlyphGap)
            }
            if let chargingCase = battery.chargingCase {
                level(chargingCase, symbolName: DeviceSymbol.chargingCase(of: symbolName), gap: Metrics.caseGlyphGap)
            }
        }
        .font(.system(size: Metrics.batteryTextSize))
        .foregroundStyle(.secondary)
    }

    private func level(_ percent: Int, symbolName: String, gap: CGFloat) -> some View {
        HStack(spacing: gap) {
            Image(systemName: symbolName)
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
                        .frame(width: Metrics.singleBatteryFillWidth * CGFloat(percent) / 100, height: Metrics.singleBatteryFillHeight)
                        .padding(.leading, 2)
                }
                .frame(width: Metrics.singleBatteryBodyWidth, height: Metrics.singleBatteryBodyHeight)
                UnevenRoundedRectangle(bottomTrailingRadius: Metrics.singleBatteryNubWidth, topTrailingRadius: Metrics.singleBatteryNubWidth)
                    .fill(Color.primary.opacity(Metrics.singleBatteryOutlineOpacity))
                    .frame(width: Metrics.singleBatteryNubWidth, height: Metrics.singleBatteryNubHeight)
            }
        }
        .fixedSize()
        .padding(.trailing, Metrics.singleBatteryTrailing)
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
            HoverRow(height: Metrics.hideRowHeight, radius: Metrics.hideHighlightRadius, textInset: Metrics.hideTextInset, isAccented: true, logName: "Hide") {
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

/// Blue at rest and under the pointer, because it is the one row that acts on the app itself. It has no "…", because a click installs at once.
struct UpdateRow: View {
    let updater: AppUpdater
    var isHighlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HoverRow(height: Metrics.menuRowHeight, isHighlighted: isHighlighted, highlightColor: Color.accentColor.opacity(0.18), logName: "update") {
                Text(updater.updateTitle ?? "")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Metrics.edgeInset)
        .frame(width: Metrics.width)
    }
}

/// "Open at Login" in the right-click menu. A system switch draws grey in an open menu (`.tint`, `NSSwitch`, and a key window tried), so this one is drawn here, at the size of a mini system switch. A click keeps the menu open, so the switch shows the new state.
struct OpenAtLoginRow: View {
    @State private var isOn = LoginItem.isEnabled

    var body: some View {
        HStack {
            Text("Open at Login")
            Spacer()
            Button {
                LoginItem.setEnabled(!isOn)
                isOn = LoginItem.isEnabled
            } label: {
                Capsule()
                    .fill(isOn ? Color.accentColor : Color.primary.opacity(0.15))
                    .frame(width: Metrics.switchWidth, height: Metrics.switchHeight)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Capsule()
                            .fill(.white)
                            .frame(width: Metrics.switchKnobWidth, height: Metrics.switchHeight - 2 * Metrics.switchKnobInset)
                            .padding(.horizontal, Metrics.switchKnobInset)
                    }
                    .animation(.easeOut(duration: 0.15), value: isOn)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Metrics.contentInset)
        .frame(width: Metrics.rightClickMenuWidth, height: Metrics.menuRowHeight)
    }
}

struct MenuRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HoverRow(height: Metrics.menuRowHeight, logName: title) {
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
    /// The Sound menu's AirPods row shows no highlight with the pointer on its ⌄.
    var isHoverHighlightHidden = false
    var isAccented = false
    var highlightColor: Color?
    let logName: String
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false
    @State private var id = UUID()

    private var fillReason: String? {
        if isHighlighted { return "highlighted" }
        return isHovered && !isHoverHighlightHidden ? "hovered" : nil
    }

    var body: some View {
        content()
            .foregroundStyle(isAccented && isHovered ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, textInset)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(fillReason != nil ? (highlightColor ?? (isAccented ? Color.accentColor : Color.primary.opacity(0.09))) : .clear)
            )
            .background(HoverProbe(id: id, name: logName))
            .onChange(of: fillReason, initial: true) {
                ProbeView.attached[id]?.fillReason = fillReason
                if fillReason != nil || ProbeView.attached[id] != nil {
                    panelLog.notice("fill \(fillReason ?? "none"): \(ProbeView.report(id))")
                }
            }
            .onHover { hovering in
                panelLog.notice("hover \(hovering ? "enter" : "exit"): \(ProbeView.report(id))")
                isHovered = hovering
                ProbeView.noteHover(of: id, hovering: hovering)
            }
    }
}

private struct FoldChevronButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary.opacity(configuration.isPressed ? Metrics.foldChevronPressedOpacity : Metrics.foldChevronOpacity))
    }
}
