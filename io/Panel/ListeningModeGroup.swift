import Priority
import SwiftUI

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
        .background(ListeningBand().padding(.top, Metrics.listeningBandTop).padding(
            .bottom,
            Metrics.listeningBandBottom
        ))
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

    private var row: AppModel.Row? {
        model.rows[.output]?.first { $0.id == device.uid }
    }

    private var isLast: Bool {
        row?.listening?.supported.last == mode
    }

    var body: some View {
        Button {
            model.setListeningMode(mode, of: device)
        } label: {
            HoverRow(height: Metrics.listeningRowPitch, logName: "listening mode") { _ in
                HStack(spacing: 0) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(row?.listening?.current == mode ? 1 : 0)
                        .padding(.leading, Metrics.listeningCheckmarkInset)
                        .frame(width: Metrics.listeningCheckmarkColumn, alignment: .leading)
                        // The row's `isSelected` trait says what the checkmark shows.
                        .accessibilityHidden(true)
                    Group {
                        if let icon = ListeningModeIcon.images[mode] {
                            Image(nsImage: icon)
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: Metrics.listeningIconSize, height: Metrics.listeningIconSize)
                                .foregroundStyle(Color.primary.opacity(0.5))
                                .accessibilityHidden(true)
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
