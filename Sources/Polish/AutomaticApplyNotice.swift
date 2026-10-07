import SwiftUI

/// An automatic replacement failure is reported without opening the confirmation
/// editor or stealing keyboard focus. The completed result remains in History.
struct AutomaticApplyNotice: View {
    @ObservedObject var controller: AppController
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
            HStack {
                Button(controller.copied ? "Copied" : "Copy result") { controller.copy() }.buttonStyle(PolishButtonStyle())
                Spacer()
                Button("View in History") { controller.openFailedResult() }.buttonStyle(PolishButtonStyle())
            }.controlSize(.small)
        }.padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PolishDesign.popupRadius))
            .overlay(RoundedRectangle(cornerRadius: PolishDesign.popupRadius).stroke(Color.primary.opacity(0.08)))
    }
}
