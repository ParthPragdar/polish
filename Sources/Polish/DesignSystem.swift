import AppKit
import SwiftUI

/// Shared surfaces, sizing, and interaction styles for all Polish windows.
enum PolishDesign {
    static let accent = Color(red: 0.23, green: 0.40, blue: 0.34)
    static let canvas = Color(red: 0.965, green: 0.963, blue: 0.945)
    static let page = Color(red: 0.978, green: 0.978, blue: 0.967)
    static let border = Color.primary.opacity(0.08)
    static let cardRadius: CGFloat = 12
    static let popupRadius: CGFloat = 16
    static let pageInset: CGFloat = 32
    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.57, green: 0.79, blue: 0.68) : accent
    }
}

struct PolishButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .foregroundStyle(primary ? (scheme == .dark ? Color.black : .white) : Color.primary)
            .background(primary ? PolishDesign.accent(for: scheme) : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(primary ? Color.clear : PolishDesign.border))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.4)
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
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.045), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }
}
