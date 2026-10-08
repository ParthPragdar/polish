import AppKit
import SwiftUI

/// An automatic replacement failure is reported without opening the confirmation
/// editor or stealing keyboard focus. The completed result remains in History.
struct AutomaticApplyNotice: View {
    @ObservedObject var controller: AppController
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark").font(.system(size: 12, weight: .bold)).foregroundStyle(PolishDesign.orange)
                    .frame(width: 26, height: 26).background(Circle().fill(PolishDesign.orange.opacity(0.16)))
                Text("Couldn’t apply automatically").font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                Button { controller.dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(PolishDismissStyle()).focusable(false).accessibilityLabel("Dismiss")
            }
            Text(controller.error).font(.system(size: 12)).foregroundStyle(PolishDesign.secondaryText)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
            if controller.copiedForPaste {
                Label("Your result is copied — press ⌘V to paste it.", systemImage: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(PolishDesign.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("View in History") { controller.openFailedResult() }.buttonStyle(PolishButtonStyle())
                Spacer()
                Button("Done") { controller.dismiss() }.buttonStyle(PolishButtonStyle(primary: true))
            }
        }
        .padding(18)
        .foregroundStyle(.white)
        .darkCard(radius: PolishDesign.popupRadius, fill: Color(white: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: PolishDesign.popupRadius, style: .continuous))
        .preferredColorScheme(.dark)
    }
}

/// Click-through confirmation shown briefly after Polish replaces text, styled like a notification.
struct AppliedToast: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Polish").font(.system(size: 11, weight: .semibold)).foregroundStyle(PolishDesign.secondaryText)
                HStack(spacing: 6) {
                    Text("Text replaced").font(.system(size: 13, weight: .semibold))
                    Text("⌘Z to undo").font(.system(size: 12)).foregroundStyle(PolishDesign.secondaryText)
                }
            }
        }
        .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 9)
        .foregroundStyle(.white)
        .darkCard(radius: 14, fill: Color(white: 0.17))
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .combine)
    }
}
