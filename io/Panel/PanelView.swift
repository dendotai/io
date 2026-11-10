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
    /// The Sound menu's radius on a 32 pt device row: the Hover highlight in `docs/sound-menu.md`.
    static let deviceHighlightRadius: CGFloat = 10
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
    /// The fold's "›" and "⌄" turn around one centre 22 in from the body's edge: a 2x crop of the Sound menu in Dark Mode, peak grey 128 on 51.
    static let rowButtonWidth: CGFloat = 16
    /// The swap's length in `docs/sound-menu.md`, Fold animation. Linear, because `.default` reached the last pixel 333 ms after the one before, against 17-50 ms in the Sound menu.
    static let foldChevronSwapDuration: TimeInterval = 0.45
    static let rowButtonOpacity: CGFloat = 0.45
    /// The Sound menu's ⌄ ink strengthens during a press (`docs/sound-menu.md`, Fold chevron, real pointer): grey 150 to 38; io's ink at 0.85 read 66, so the press takes the full primary colour.
    static let rowButtonPressedOpacity: CGFloat = 1
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
                UpdateRow(
                    updater: updater,
                    isHighlighted: UserDefaults.standard.bool(forKey: "renderUpdateHighlighted"),
                    action: updater.installUpdate
                )
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
                Image(systemName: "speaker.fill").accessibilityHidden(true)
                Track(value: model.sliderVolume ?? 0, set: model.setVolume)
                Image(systemName: "speaker.wave.3.fill").accessibilityHidden(true)
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
                        }
                )
            }
            .frame(height: Metrics.knobHeight)
        }
    }

    /// A superellipse: the Sound menu's knob is fuller than an ellipse and rounder than a rounded rectangle, and an exponent of 2.3 fits its outline row by row at 2x.
    private nonisolated struct Knob: Shape {
        func path(in rect: CGRect) -> Path {
            let exponent = 2.3
            var path = Path()
            for step in 0 ... 120 {
                let angle = Double(step) / 120 * 2 * .pi
                let x = pow(abs(cos(angle)), 2 / exponent) * (cos(angle) < 0 ? -1 : 1)
                let y = pow(abs(sin(angle)), 2 / exponent) * (sin(angle) < 0 ? -1 : 1)
                let point = CGPoint(x: rect.midX + x * rect.width / 2, y: rect.midY + y * rect.height / 2)
                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            return path
        }
    }
}

extension Direction {
    var title: String {
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
