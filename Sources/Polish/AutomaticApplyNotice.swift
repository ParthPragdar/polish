import SwiftUI

/// An automatic replacement failure is reported without opening the confirmation
/// editor or stealing keyboard focus. The completed result remains in History.
struct AutomaticApplyNotice: View {
    @ObservedObject var controller: AppController
    @Environment(\.colorScheme) private var colorScheme
    private var accent: Color { PolishDesign.accent(for: colorScheme) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                Text("Couldn’t apply automatically").font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                Button { controller.dismiss() } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                    .buttonStyle(PolishDismissStyle()).focusable(false).accessibilityLabel("Dismiss")
            }
            Text(controller.error).font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
            if controller.copiedForPaste {
                Label("Your result is copied — press ⌘V to paste it.", systemImage: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("View in History") { controller.openFailedResult() }.buttonStyle(PolishButtonStyle())
                Spacer()
                Button("Done") { controller.dismiss() }.buttonStyle(PolishButtonStyle(primary: true))
            }.controlSize(.small)
        }.padding(20)
            .floatingGlass()
            .clipShape(RoundedRectangle(cornerRadius: PolishDesign.popupRadius, style: .continuous))
    }
}

/// Click-through confirmation shown briefly after Polish replaces text.
struct AppliedToast: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(PolishDesign.accent(for: colorScheme))
            Text("Replaced").fontWeight(.semibold)
            Text("⌘Z to undo").foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 16).frame(height: 36)
        .floatingGlass(cornerRadius: 18)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}
