import SwiftUI

/// Compact progress pill: a traveling wave in the mode's color, what Polish is doing, and Cancel.
struct LoadingIndicator: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var tint: Color { controller.isTranslation ? PolishDesign.teal : PolishDesign.tint(for: controller.mode) }
    private var label: String {
        if controller.phase == .applying { return "Applying…" }
        if controller.isTranslation { return "Translating to Gujarati…" }
        switch controller.mode {
        case .grammar: return "Correcting grammar…"
        case .prompt: return "Refining prompt…"
        case .english: return "Rewriting in English…"
        }
    }
    var body: some View {
        HStack(spacing: 12) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    Circle().fill(tint.opacity(0.18))
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
            }.accessibilityElement(children: .ignore).accessibilityLabel(controller.isTranslation ? "Translating text" : "Rewriting text")
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.9)).lineLimit(1).fixedSize()
            Spacer(minLength: 0)
            Button { controller.dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PolishDesign.secondaryText).frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.08))).contentShape(Circle())
            }.buttonStyle(.plain).focusable(false).help(controller.isTranslation ? "Cancel translation" : "Cancel rewrite")
                .accessibilityLabel(controller.isTranslation ? "Cancel translation" : "Cancel rewrite").disabled(controller.phase == .applying)
        }
        .padding(.leading, 14).padding(.trailing, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Capsule().fill(Color(white: 0.17)))
        .overlay(Capsule().strokeBorder(PolishDesign.hairline))
        .clipShape(Capsule())
        .preferredColorScheme(.dark)
    }
}
