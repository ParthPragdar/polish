import SwiftUI

/// Read-only Gujarati translation of the selection. A click anywhere outside the popup, or Escape, closes it.
struct TranslationView: View {
    @ObservedObject var controller: AppController
    private var isError: Bool { controller.phase == .error }
    private var tint: Color { isError ? PolishDesign.orange : PolishDesign.teal }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.16))
                    Image(systemName: isError ? "exclamationmark" : PolishDesign.translationSymbol)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                }.frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isError ? controller.errorTitle : "ગુજરાતી").font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText).lineLimit(1)
                }
                Spacer(minLength: 8)
                Button { controller.dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(PolishDismissStyle()).focusable(false).help("Close").accessibilityLabel("Close translation")
                    .keyboardShortcut(.cancelAction)
            }
            .padding(18)

            if isError {
                Text(controller.error).font(.system(size: 13)).foregroundStyle(PolishDesign.secondaryText)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 18).padding(.bottom, 16)
            } else {
                // Sized to the text's measured height, up to 340 points; longer translations scroll.
                ScrollView {
                    Text(controller.result)
                        .font(.system(size: 17)).lineSpacing(7).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                }
                .frame(maxHeight: 340).fixedSize(horizontal: false, vertical: true)
                .darkCard(radius: 12, fill: PolishDesign.well)
                .padding(.horizontal, 18).padding(.bottom, 16)
            }

            Rectangle().fill(PolishDesign.hairline).frame(height: 1)
            HStack(spacing: 10) {
                Text("Click outside or press esc to close").font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText)
                Spacer(minLength: 8)
                if !isError {
                    Button { controller.copy() } label: {
                        Label(controller.copied ? "Copied" : "Copy", systemImage: controller.copied ? "checkmark" : "doc.on.doc")
                    }.buttonStyle(PolishButtonStyle())
                } else if controller.errorNeedsAccessibility {
                    Button("Open Accessibility Settings") { controller.dismiss(); TextAccess.openAccessibilitySettings() }.buttonStyle(PolishButtonStyle(primary: true))
                } else if controller.errorNeedsSettings {
                    Button("Open Settings") { controller.dismiss(); controller.showSettings(section: "Settings") }.buttonStyle(PolishButtonStyle(primary: true))
                } else if controller.canRetry {
                    Button("Try again") { controller.retry() }.buttonStyle(PolishButtonStyle(primary: true))
                }
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 18).padding(.vertical, 14)
        }
        .foregroundStyle(.white)
        .darkCard(radius: PolishDesign.popupRadius, fill: Color(white: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: PolishDesign.popupRadius, style: .continuous))
        .tint(PolishDesign.teal)
        .preferredColorScheme(.dark)
    }

    private var subtitle: String {
        if isError { return "Nothing was translated" }
        return controller.destination.isEmpty ? "Translated to Gujarati" : "Translated to Gujarati · \(controller.destination)"
    }
}
