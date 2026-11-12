import SwiftUI

struct PanelSeparator: View {
    let inset: CGFloat
    var width = Metrics.width

    var body: some View {
        LineGreyFill(shape: Rectangle())
            .frame(height: 1)
            .padding(.horizontal, inset)
            .padding(.top, 5)
            .padding(.bottom, 4)
            .frame(width: width)
    }
}

/// The Sound menu's grey for a section line and for the icon circle of a row not in use: one blend over what is behind the menu, where an opacity reads lighter or darker with the backdrop.
struct LineGreyFill<S: Shape>: View {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        shape
            .fill(Color(white: colorScheme == .dark ? Metrics.lineGreyDark : Metrics.lineGreyLight))
            .blendMode(colorScheme == .dark ? .plusLighter : .plusDarker)
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
            HoverRow(height: Metrics.menuRowHeight, style: .update, isHighlighted: isHighlighted,
                     logName: "update")
            { _ in
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
                            .frame(
                                width: Metrics.switchKnobWidth,
                                height: Metrics.switchHeight - 2 * Metrics.switchKnobInset
                            )
                            .padding(.horizontal, Metrics.switchKnobInset)
                    }
                    .animation(.easeOut(duration: 0.15), value: isOn)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, Metrics.rightClickMenuTextInset)
        .padding(.trailing, Metrics.contentInset)
        .frame(width: Metrics.rightClickMenuWidth, height: Metrics.menuRowHeight)
    }
}

struct MenuRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HoverRow(height: Metrics.menuRowHeight, logName: title) { _ in
                Text(title)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Metrics.edgeInset)
        .frame(width: Metrics.width)
    }
}

/// How a `HoverRow` fills its highlight: the Sound menu's grey, or the update row's blue.
enum HoverRowStyle {
    case plain
    case update

    var fill: Color {
        switch self {
        case .plain: Color.primary.opacity(0.09)
        case .update: Color.accentColor.opacity(0.18)
        }
    }
}

/// A row that highlights under the pointer like a menu item. The caller insets it from the panel edge.
struct HoverRow<Content: View>: View {
    let height: CGFloat
    var style = HoverRowStyle.plain
    var isHighlighted = false
    var radius = Metrics.highlightRadius
    let logName: String
    /// Takes the row's hover, so a control shown on hover clears with the highlight when a lost exit is cleared.
    @ViewBuilder let content: (_ isHovered: Bool) -> Content
    @State private var isHovered = false
    @State private var id = UUID()

    private var fillReason: String? {
        if isHighlighted {
            return "highlighted"
        }
        return isHovered ? "hovered" : nil
    }

    var body: some View {
        content(isHovered)
            .foregroundStyle(.primary)
            .padding(.horizontal, Metrics.contentInset - Metrics.edgeInset)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(fillReason != nil ? style.fill : .clear)
            )
            .background(HoverProbe(id: id, name: logName, clearHover: { isHovered = false }))
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

struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Metrics.chevronSize))
            .frame(width: Metrics.rowButtonWidth, height: Metrics.iconSize)
            .contentShape(Rectangle())
            .foregroundStyle(Color.primary
                .opacity(configuration.isPressed ? Metrics.rowButtonPressedOpacity : Metrics.rowButtonOpacity))
    }
}
