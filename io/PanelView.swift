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
    /// A shorter move is a click, so a click never reorders.
    static let dragThreshold: CGFloat = 4
    static let liftScale: CGFloat = 1.02
    static let gripSize: CGFloat = 11
    static let slide = Animation.easeOut(duration: 0.15)
}

struct PanelView: View {
    let model: AppModel
    @State private var opensAtLogin = LoginItem.isEnabled
    @State private var drag: RowDrag?

    private struct RowDrag {
        let uid: String
        var translation: CGFloat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Output")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.48))
                .padding(.horizontal, Metrics.contentInset)
                .frame(height: Metrics.headerHeight)

            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                let isLifted = drag?.uid == row.id
                DeviceRow(row: row, isLifted: isLifted)
                    .offset(y: offset(at: index))
                    .animation(isLifted ? nil : Metrics.slide, value: offset(at: index))
                    .zIndex(isLifted ? 1 : 0)
                    .gesture(reorderOrUse(row))
                    .accessibilityAddTraits(row.isConnected ? .isButton : [])
                    .accessibilityAction {
                        if row.isConnected {
                            model.use(row.device)
                        }
                    }
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
        // A menu closed mid-drag never ends the gesture.
        .onDisappear { drag = nil }
    }

    private func reorderOrUse(_ row: AppModel.Row) -> some Gesture {
        // Global coordinates, because the row's own offset follows the pointer and would shift a local translation.
        DragGesture(minimumDistance: Metrics.dragThreshold, coordinateSpace: .global)
            .onChanged { value in
                drag = RowDrag(uid: row.id, translation: clampedTranslation(value.translation.height, of: row.id))
            }
            .onEnded { _ in drop() }
            .exclusively(
                before: TapGesture().onEnded {
                    if row.isConnected {
                        model.use(row.device)
                    }
                })
    }

    private func rowIndex(of uid: String) -> Int? {
        model.rows.firstIndex { $0.id == uid }
    }

    private func targetIndex(of drag: RowDrag) -> Int? {
        guard let from = rowIndex(of: drag.uid) else { return nil }
        let shift = Int((drag.translation / Metrics.deviceRowHeight).rounded())
        return min(max(from + shift, 0), model.rows.count - 1)
    }

    private func clampedTranslation(_ translation: CGFloat, of uid: String) -> CGFloat {
        guard let from = rowIndex(of: uid) else { return 0 }
        let up = -CGFloat(from) * Metrics.deviceRowHeight
        let down = CGFloat(model.rows.count - 1 - from) * Metrics.deviceRowHeight
        return min(max(translation, up), down)
    }

    private func offset(at index: Int) -> CGFloat {
        guard let drag, let from = rowIndex(of: drag.uid), let to = targetIndex(of: drag) else { return 0 }
        if index == from {
            return drag.translation
        }
        if from < index && index <= to {
            return -Metrics.deviceRowHeight
        }
        if to <= index && index < from {
            return Metrics.deviceRowHeight
        }
        return 0
    }

    private func drop() {
        guard let drag, let from = rowIndex(of: drag.uid), let to = targetIndex(of: drag) else {
            self.drag = nil
            return
        }
        withAnimation(Metrics.slide) {
            // A drop on the row's own place is no reorder, so it keeps the hand pick.
            if to != from {
                model.reorder(model.rows[from].device, to: to)
            }
            self.drag = nil
        }
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
    let isLifted: Bool

    var body: some View {
        HoverRow(height: Metrics.deviceRowHeight) { isHovered in
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: DeviceSymbol.speaker)
                        .font(.system(size: 12))
                        .foregroundStyle(row.isInUse ? .white : .primary)
                        .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                        .background(Circle().fill(row.isInUse ? Color.accentColor : Color.primary.opacity(0.09)))
                    Text(row.device.name)
                        .lineLimit(1)
                }
                .opacity(row.isConnected ? 1 : 0.4)
                Spacer(minLength: 0)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: Metrics.gripSize))
                    .foregroundStyle(Color.primary.opacity(0.3))
                    .opacity(isHovered || isLifted ? 1 : 0)
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
    }
}

private struct MenuRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HoverRow(height: Metrics.menuRowHeight) { _ in
                Text(title)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Metrics.edgeInset)
    }
}

/// A row that highlights under the pointer like a menu item. The caller insets it from the panel edge.
private struct HoverRow<Content: View>: View {
    let height: CGFloat
    @ViewBuilder let content: (_ isHovered: Bool) -> Content
    @State private var isHovered = false

    var body: some View {
        content(isHovered)
            .padding(.horizontal, Metrics.contentInset - Metrics.edgeInset)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Metrics.highlightRadius)
                    .fill(isHovered ? Color.primary.opacity(0.09) : .clear)
            )
            .onHover { isHovered = $0 }
    }
}
