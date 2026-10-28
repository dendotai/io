import Priority
import SwiftUI

/// Sizes in points and the grey opacities below, measured on a Light Mode screenshot of the system Sound menu on macOS 27.
private enum Metrics {
    static let width: CGFloat = 308
    static let edgeInset: CGFloat = 5
    static let contentInset: CGFloat = 14
    static let headerHeight: CGFloat = 22
    static let deviceRowHeight: CGFloat = 32
    static let menuRowHeight: CGFloat = 22
    static let iconSize: CGFloat = 26
    /// Half the menu row height: the Sound menu's highlight on "Sound Settings…" is a capsule.
    static let highlightRadius: CGFloat = 11
}

struct PanelView: View {
    let model: AppModel
    @State private var opensAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Output")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.48))
                .padding(.horizontal, Metrics.contentInset)
                .frame(height: Metrics.headerHeight)

            ForEach(model.rows) { row in
                DeviceRow(row: row) { model.use(row.device) }
            }

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, Metrics.edgeInset)
                .padding(.top, 5)
                .padding(.bottom, 4)

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
        .padding(.top, 5)
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

private struct DeviceRow: View {
    let row: AppModel.Row
    let action: () -> Void

    var body: some View {
        HoverRow(height: Metrics.deviceRowHeight, isEnabled: row.isConnected, action: action) {
            HStack(spacing: 8) {
                Image(systemName: DeviceSymbol.speaker)
                    .font(.system(size: 12))
                    .foregroundStyle(row.isInUse ? .white : .primary)
                    .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                    .background(Circle().fill(row.isInUse ? Color.accentColor : Color.primary.opacity(0.09)))
                Text(row.device.name)
                    .lineLimit(1)
            }
        }
        .opacity(row.isConnected ? 1 : 0.4)
    }
}

private struct MenuRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        HoverRow(height: Metrics.menuRowHeight, isEnabled: true, action: action) {
            Text(title)
        }
    }
}

/// A row that highlights under the pointer, inset from the panel edge like a menu item.
private struct HoverRow<Content: View>: View {
    let height: CGFloat
    let isEnabled: Bool
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, Metrics.contentInset - Metrics.edgeInset)
                .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: Metrics.highlightRadius)
                        .fill(isHovered && isEnabled ? Color.primary.opacity(0.09) : .clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal, Metrics.edgeInset)
        .onHover { isHovered = $0 }
    }
}
