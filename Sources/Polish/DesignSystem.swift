import AppKit
import PolishCore
import SwiftUI

/// Dark charcoal surfaces, quiet gray type, and two signal colors: green for grammar, orange for prompts.
enum PolishDesign {
    static let window = Color(white: 0.155)
    static let surface = Color(white: 0.215)
    static let raised = Color(white: 0.30)
    static let well = Color(white: 0.115)
    static let hairline = Color.white.opacity(0.08)
    static let secondaryText = Color.white.opacity(0.55)
    static let tertiaryText = Color.white.opacity(0.32)
    static let green = Color(red: 0.30, green: 0.80, blue: 0.42)
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.26)
    static let red = Color(red: 1.0, green: 0.42, blue: 0.40)
    static let cardRadius: CGFloat = 14
    static let popupRadius: CGFloat = 18
    static let pageInset: CGFloat = 28

    static func tint(for mode: RewriteMode) -> Color { mode == .grammar ? green : orange }
    static func symbol(for mode: RewriteMode) -> String { mode == .grammar ? "text.badge.checkmark" : "sparkles" }
    static func shortTitle(for mode: RewriteMode) -> String { mode == .grammar ? "Grammar" : "Prompt" }
}

extension View {
    /// A raised charcoal panel with a hairline edge.
    func darkCard(radius: CGFloat = PolishDesign.cardRadius, fill: Color = PolishDesign.surface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(PolishDesign.hairline, lineWidth: 1))
    }
}

/// Small rounded label, like a year or status tag beside a title.
struct Pill: View {
    var text: String
    var tint: Color? = nil
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold)).tracking(0.3)
            .foregroundStyle(tint ?? Color.white.opacity(0.85))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((tint ?? .white).opacity(tint == nil ? 0.12 : 0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// A symbol inside a charcoal disc.
struct IconDisc: View {
    var systemName: String
    var size: CGFloat = 40
    var tint: Color = Color.white.opacity(0.85)
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(PolishDesign.raised.opacity(0.55)))
            .overlay(Circle().strokeBorder(PolishDesign.hairline))
    }
}

/// A key cap, for showing shortcuts inline.
struct KeyCap: View {
    var text: String
    var body: some View {
        Text(text).font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8).frame(minWidth: 28, minHeight: 24)
            .darkCard(radius: 6, fill: PolishDesign.raised.opacity(0.6))
    }
}

/// A capsule segmented control with a sliding lighter thumb.
struct SegmentedPicker<Value: Hashable>: View {
    var options: [(value: Value, title: String)]
    @Binding var selection: Value
    var compact = false
    @Namespace private var thumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.system(size: compact ? 11 : 13, weight: .medium))
                        .foregroundStyle(selected ? Color.white : PolishDesign.secondaryText)
                        .padding(.horizontal, compact ? 10 : 16).frame(height: compact ? 24 : 30)
                        .background {
                            if selected { Capsule().fill(PolishDesign.raised).matchedGeometryEffect(id: "thumb", in: thumb) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(PolishDesign.surface))
        .overlay(Capsule().strokeBorder(PolishDesign.hairline))
    }
}

struct PolishButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 32)
            .foregroundStyle(primary ? Color.black : Color.white.opacity(0.9))
            .background(primary ? Color.white.opacity(0.92) : Color.white.opacity(0.09), in: shape)
            .overlay(shape.strokeBorder(primary ? Color.clear : PolishDesign.hairline, lineWidth: 1))
            .contentShape(shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Retains the label's layout while making every part of a row interactive.
struct PolishRowStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PolishDismissStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(PolishDesign.secondaryText)
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08)))
            .contentShape(Circle())
    }
}

/// A header icon button; the current screen's icon sits on a lighter plate.
struct HeaderIconButton: View {
    var systemName: String
    var help: String
    var selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.75))
                .frame(width: 32, height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(selected ? Color.white.opacity(0.12) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .help(help).accessibilityLabel(help)
    }
}

/// Edits between the original and the rewrite: removals struck through in red, additions in green.
func diffText(original: String, result: String) -> Text? {
    guard let changes = WordDiff.changes(from: original, to: result) else { return nil }
    var text = AttributedString()
    for change in changes {
        switch change {
        case .same(let value):
            text += AttributedString(value)
        case .removed(let value):
            var part = AttributedString(value)
            part.foregroundColor = PolishDesign.red.opacity(0.85)
            part.strikethroughStyle = .single
            text += part
        case .added(let value):
            var part = AttributedString(value)
            part.foregroundColor = PolishDesign.green
            part.backgroundColor = PolishDesign.green.opacity(0.14)
            text += part
        }
    }
    return Text(text)
}
