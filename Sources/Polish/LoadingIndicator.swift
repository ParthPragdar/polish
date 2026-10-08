import SwiftUI

/// Compact progress pill: a traveling wave with a soft breathing glow, what Polish is doing, and Cancel.
struct LoadingIndicator: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    private var tint: Color {
        PolishDesign.accent(for: colorScheme)
    }
    private var label: String {
        if controller.phase == .applying { return "Applying…" }
        return controller.mode == .grammar ? "Correcting grammar…" : "Refining prompt…"
    }
    var body: some View {
        HStack(spacing: 12) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    Circle().fill(tint.opacity(0.13))
                        .frame(width: 28, height: 28).blur(radius: 5)
                        .scaleEffect(reduceMotion ? 1 : 0.9 + 0.15 * sin(time * 2.4))
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            let wave = reduceMotion ? 0.5 : (sin(time * 5 - Double(index) * 0.9) + 1) / 2
                            Capsule().fill(tint.opacity(0.5 + 0.5 * wave))
                                .frame(width: 5, height: 7 + 12 * wave)
                        }
                    }
                }.frame(width: 30, height: 26)
            }.accessibilityElement(children: .ignore).accessibilityLabel("Rewriting text")
            Text(label).font(.system(size: 12, weight: .medium)).lineLimit(1).fixedSize()
            Spacer(minLength: 0)
            Button { controller.dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary).frame(width: 24, height: 28).contentShape(Rectangle())
            }.buttonStyle(.plain).focusable(false).help("Cancel rewrite")
                .accessibilityLabel("Cancel rewrite").disabled(controller.phase == .applying)
        }
        .padding(.leading, 14).padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .floatingGlass(cornerRadius: 22) // Half the panel's 44-point height: a capsule.
        .clipShape(Capsule())
    }
}
