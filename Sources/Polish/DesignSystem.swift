import AppKit
import SwiftUI

/// Shared surfaces, sizing, and interaction styles for all Polish windows.
enum PolishDesign {
    static let accent = Color(red: 0.23, green: 0.40, blue: 0.34)
    static let border = Color.primary.opacity(0.08)
    static let cardRadius: CGFloat = 12
    static let popupRadius: CGFloat = 16
    static let pageInset: CGFloat = 32
    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.57, green: 0.79, blue: 0.68) : accent
    }

    // Saturated hues that show through frosted surfaces.
    static let mint = Color(red: 0.33, green: 0.86, blue: 0.69)
    static let sky = Color(red: 0.38, green: 0.62, blue: 1.0)
    static let violet = Color(red: 0.66, green: 0.47, blue: 1.0)
    static let peach = Color(red: 1.0, green: 0.64, blue: 0.47)

    /// Milky layer that frosts a blurred surface and keeps text legible.
    static func glassFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.42)
    }
    /// Light catching the top-leading edge of a glass pane.
    static func glassBorder(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(colors: scheme == .dark ? [.white.opacity(0.30), .white.opacity(0.06)] : [.white.opacity(0.95), .white.opacity(0.40)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// Faint color wash for panels floating over other apps, whose backdrop Polish doesn't control.
    static func glow(_ scheme: ColorScheme) -> LinearGradient {
        let strength = scheme == .dark ? 0.6 : 1.0
        return LinearGradient(colors: [mint.opacity(0.20 * strength), sky.opacity(0.08 * strength), violet.opacity(0.16 * strength)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Blurs whatever is behind the window. Kept active because Polish's floating panels
/// never activate the app, and an inactive effect view renders flat and gray.
struct BehindWindowBlur: NSViewRepresentable {
    var cornerRadius: CGFloat
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        // A mask image is the reliable way to round a behind-window blur; layer corner radii are ignored.
        let edge = cornerRadius * 2 + 1
        let mask = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
        mask.resizingMode = .stretch
        view.maskImage = mask
    }
}

/// Frosted glass: background blur, a milky translucent fill, optional color, and a light edge.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?
    var floating: Bool
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                ZStack {
                    if floating {
                        BehindWindowBlur(cornerRadius: cornerRadius)
                        shape.fill(PolishDesign.glow(scheme))
                    } else {
                        shape.fill(.ultraThinMaterial)
                    }
                    shape.fill(PolishDesign.glassFill(scheme))
                    if let tint { shape.fill(tint) }
                }.clipShape(shape)
            }
            .overlay(shape.strokeBorder(PolishDesign.glassBorder(scheme), lineWidth: 1))
    }
}

extension View {
    /// A glass card inside a Polish window, blurring the window's own backdrop.
    func glassCard(cornerRadius: CGFloat = PolishDesign.cardRadius, tint: Color? = nil) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint, floating: false))
    }
    /// A glass panel floating over other apps, blurring the desktop behind it.
    func floatingGlass(cornerRadius: CGFloat = PolishDesign.popupRadius) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: nil, floating: true))
    }
}

/// Soft, saturated color fields behind the Settings window's frosted panes.
struct GlassBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.92, green: 0.97, blue: 0.96), Color(red: 0.95, green: 0.94, blue: 0.99)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            blob(PolishDesign.mint, size: 380, x: -300, y: -230)
            blob(PolishDesign.violet, size: 420, x: 300, y: -200)
            blob(PolishDesign.peach, size: 340, x: -150, y: 250)
            blob(PolishDesign.sky, size: 400, x: 250, y: 210)
        }
        .drawingGroup() // Rasterize the static blurs once instead of on every redraw.
        .accessibilityHidden(true)
    }
    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle().fill(color.opacity(0.7)).frame(width: size, height: size).offset(x: x, y: y).blur(radius: 70)
    }
}

struct PolishButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        let accent = PolishDesign.accent(for: scheme)
        return configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .foregroundStyle(primary ? (scheme == .dark ? Color.black : .white) : Color.primary)
            .background {
                if primary {
                    shape.fill(LinearGradient(colors: [accent, scheme == .dark ? PolishDesign.mint : Color(red: 0.17, green: 0.47, blue: 0.50)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    shape.fill(Color.white.opacity(scheme == .dark ? 0.10 : 0.55))
                }
            }
            .overlay(shape.strokeBorder(primary ? AnyShapeStyle(Color.white.opacity(0.30)) : AnyShapeStyle(PolishDesign.glassBorder(scheme)), lineWidth: 1))
            .contentShape(shape)
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
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(Color.white.opacity((scheme == .dark ? 0.08 : 0.45) + (configuration.isPressed ? 0.12 : 0)), in: shape)
            .overlay(shape.strokeBorder(PolishDesign.glassBorder(scheme), lineWidth: 1))
            .contentShape(Rectangle())
    }
}
