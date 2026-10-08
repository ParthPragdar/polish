import AppKit
import PolishCore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var history: RewriteHistory
    @Binding var selection: UUID?
    @State private var copiedID: UUID?
    @State private var confirmClear = false
    private let tint = PolishDesign.accent
    private var selected: HistoryItem? { history.items.first { $0.id == selection } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entry = selected {
                detail(entry)
            } else {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR RECENT WORDS").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(tint)
                        Text("History").font(.system(size: 28, weight: .semibold, design: .rounded))
                        Text("\(history.items.count) of 80 rewrites · saved on this Mac").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !history.items.isEmpty || history.storageError != nil {
                        Button("Clear history") { confirmClear = true }.font(.system(size: 12))
                    }
                }.padding(PolishDesign.pageInset)
                if let error = history.storageError { errorNotice(error) }
                if history.items.isEmpty {
                    VStack(spacing: 13) {
                        Image(systemName: "clock.arrow.circlepath").font(.system(size: 32, weight: .light)).foregroundStyle(tint)
                        Text("A place for your rewrites").font(.system(size: 17, weight: .semibold))
                        Text("Correct a sentence or refine a prompt.\nYour latest 80 results will appear here.")
                            .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(history.items) { entry in
                                Button { selection = entry.id; copiedID = nil } label: { row(entry) }.buttonStyle(PolishRowStyle()).focusEffectDisabled()
                            }
                        }.padding(.horizontal, PolishDesign.pageInset).padding(.bottom, 24)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog("Clear all saved history?", isPresented: $confirmClear) {
            Button("Clear history", role: .destructive) { history.clear(); selection = nil }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This removes the original text and results saved on this Mac. This cannot be undone.") }
    }

    private func row(_ entry: HistoryItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.mode == .grammar ? "text.badge.checkmark" : "sparkles")
                .font(.system(size: 17)).foregroundStyle(tint).frame(width: 24).padding(.top, 2)
            VStack(alignment: .leading, spacing: 7) {
                Text(entry.result).font(.system(size: 13, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(entry.mode.title).lineLimit(1)
                    Text("·")
                    Text(entry.createdAt, style: .relative)
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary).padding(.top, 5)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func detail(_ entry: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { selection = nil } label: { Label("History", systemImage: "chevron.left") }.buttonStyle(PolishButtonStyle()).foregroundStyle(tint)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.result, forType: .string)
                    copiedID = entry.id
                } label: { Label(copiedID == entry.id ? "Copied" : "Copy result", systemImage: copiedID == entry.id ? "checkmark" : "doc.on.doc") }
                .buttonStyle(PolishButtonStyle(primary: true)).tint(tint)
            }.padding(PolishDesign.pageInset)
            if let error = history.storageError { errorNotice(error) }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(entry.mode.title).font(.system(size: 23, weight: .semibold, design: .rounded))
                        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    textCard("RESULT", entry.result, highlight: true)
                    textCard("ORIGINAL", entry.original, highlight: false)
                }.padding(.horizontal, PolishDesign.pageInset).padding(.bottom, 28)
            }
        }
    }
    private func textCard(_ title: String, _ text: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 10, weight: .semibold)).tracking(1.3).foregroundStyle(tint)
            Text(text).font(.system(size: 13)).lineSpacing(4).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(18).glassCard(tint: highlight ? nil : tint.opacity(0.06))
    }
    private func errorNotice(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle").font(.system(size: 12)).foregroundStyle(.orange)
            .padding(.horizontal, PolishDesign.pageInset).padding(.bottom, 16)
    }
}
