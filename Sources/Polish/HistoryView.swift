import AppKit
import PolishCore
import SwiftUI

/// A month calendar of rewrites beside the selected day's list, or search results across all saved rewrites.
struct HistoryView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var history: RewriteHistory
    @Binding var selection: UUID?
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())!.start
    @State private var day: Date?
    @State private var query = ""
    @State private var confirmClear = false
    private let calendar = Calendar.current

    private var selected: HistoryItem? { history.items.first { $0.id == selection } }
    private var listedItems: [HistoryItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return history.items.filter { $0.result.localizedCaseInsensitiveContains(trimmed) || $0.original.localizedCaseInsensitiveContains(trimmed) || $0.sourceApp.localizedCaseInsensitiveContains(trimmed) }
        }
        guard let day else { return history.items }
        return history.items.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BackButton { controller.settingsSection = "Overview" }
                Text("History").font(.system(size: 26, weight: .bold))
                Pill(text: "\(history.items.count) of \(RewriteHistory.limit)")
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(PolishDesign.tertiaryText)
                    TextField("Search rewrites", text: $query).textFieldStyle(.plain).font(.system(size: 13))
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(PolishDesign.tertiaryText) }
                            .buttonStyle(.plain).accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 10).frame(width: 210, height: 30).darkCard(radius: 8)
                if !history.items.isEmpty || history.storageError != nil {
                    Button { confirmClear = true } label: { Image(systemName: "trash") }
                        .help("Clear history").accessibilityLabel("Clear history")
                }
            }
            .padding(.horizontal, PolishDesign.pageInset).padding(.top, 24).padding(.bottom, 18)

            if let error = history.storageError {
                Label(error, systemImage: "exclamationmark.triangle").font(.system(size: 12)).foregroundStyle(PolishDesign.orange)
                    .padding(.horizontal, PolishDesign.pageInset).padding(.bottom, 12)
            }

            HStack(alignment: .top, spacing: 22) {
                CalendarMonth(month: $month, day: $day, tallies: RewriteStats.byDay(history.items, calendar: calendar))
                    .frame(width: 300)
                Group {
                    if let entry = selected { HistoryDetail(entry: entry) { selection = nil } }
                    else { list }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, PolishDesign.pageInset).padding(.bottom, 22)
        }
        .onAppear { focusSelection() }
        .onChange(of: selection) { _, _ in focusSelection() }
        .confirmationDialog("Clear all saved history?", isPresented: $confirmClear) {
            Button("Clear history", role: .destructive) { history.clear(); selection = nil; day = nil }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This removes the original text and results saved on this Mac. This cannot be undone.") }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(listTitle).font(.system(size: 13, weight: .semibold)).foregroundStyle(PolishDesign.secondaryText)
                Spacer()
                if day != nil && query.isEmpty {
                    Button("Show all") { day = nil }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(PolishDesign.green)
                }
            }
            if listedItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: history.items.isEmpty ? "clock.arrow.circlepath" : "calendar.badge.exclamationmark")
                        .font(.system(size: 28, weight: .light)).foregroundStyle(PolishDesign.tertiaryText)
                    Text(history.items.isEmpty ? "Your latest \(RewriteHistory.limit) rewrites will appear here." : "Nothing on this day.")
                        .font(.system(size: 13)).foregroundStyle(PolishDesign.secondaryText)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(listedItems) { entry in
                            Button { selection = entry.id } label: { HistoryRow(entry: entry, showsDate: day == nil || !query.isEmpty) }
                                .buttonStyle(PolishRowStyle()).focusEffectDisabled()
                        }
                    }
                }
            }
        }
    }
    private var listTitle: String {
        if !query.isEmpty { return listedItems.count == 1 ? "1 match" : "\(listedItems.count) matches" }
        guard let day else { return "All rewrites" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
    private func focusSelection() {
        guard let entry = selected else { return }
        day = calendar.startOfDay(for: entry.createdAt)
        month = calendar.dateInterval(of: .month, for: entry.createdAt)?.start ?? month
    }
}

struct BackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28).background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .help("Back to Activity").accessibilityLabel("Back to Activity")
    }
}

/// Monday-first month grid; days with rewrites are tinted by their main mode.
struct CalendarMonth: View {
    @Binding var month: Date
    @Binding var day: Date?
    var tallies: [Date: RewriteStats.Tally]
    private var calendar: Calendar { var calendar = Calendar.current; calendar.firstWeekday = 2; return calendar }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        let days = cells()
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year())).font(.system(size: 15, weight: .semibold))
                Spacer()
                stepButton("chevron.left", by: -1)
                stepButton("chevron.right", by: 1)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, letter in
                    Text(letter).font(.system(size: 9, weight: .semibold)).foregroundStyle(PolishDesign.secondaryText)
                        .frame(maxWidth: .infinity).frame(height: 16)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] { cell(date) } else { Color.clear.frame(height: 36) }
                }
            }
            HStack(spacing: 14) {
                legend(PolishDesign.green, "Grammar")
                legend(PolishDesign.orange, "Prompt")
            }.padding(.top, 4)
        }
        .padding(16).darkCard()
    }

    private func cell(_ date: Date) -> some View {
        let tally = tallies[date]
        let isSelected = day.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()
        let tint: Color? = tally.map { $0.grammar >= $0.prompt ? PolishDesign.green : PolishDesign.orange }
        return Button { day = isSelected ? nil : date } label: {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.map { $0.opacity(0.22) } ?? Color.white.opacity(isFuture ? 0.025 : 0.05))
                if let tally, let tint {
                    Text("\(tally.total)").font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(tint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 8, weight: isToday ? .bold : .medium).monospacedDigit())
                    .foregroundStyle(isToday ? Color.white : PolishDesign.tertiaryText)
                    .padding(4)
            }
            .frame(height: 36)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(isSelected ? Color.white.opacity(0.8) : isToday ? Color.white.opacity(0.25) : .clear, lineWidth: isSelected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(tally?.total ?? 0) rewrites")
    }
    private func stepButton(_ symbol: String, by months: Int) -> some View {
        Button { if let next = calendar.date(byAdding: .month, value: months, to: month) { month = next } } label: {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityLabel(months < 0 ? "Previous month" : "Next month")
    }
    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.6)).frame(width: 10, height: 10)
            Text(title).font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText)
        }
    }
    /// Leading blanks for the weekdays before the 1st, then each day of the month.
    private func cells() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let lead = (calendar.component(.weekday, from: month) + 5) % 7
        return Array(repeating: nil, count: lead) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }
}

struct HistoryRow: View {
    var entry: HistoryItem
    var showsDate: Bool
    var body: some View {
        HStack(spacing: 12) {
            AppIcon(name: entry.sourceApp).frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.preview).font(.system(size: 13, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading)
                Text("\(entry.sourceApp) · \(showsDate ? entry.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()) : entry.createdAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText).lineLimit(1)
            }
            Spacer(minLength: 8)
            Pill(text: PolishDesign.shortTitle(for: entry.mode), tint: PolishDesign.tint(for: entry.mode))
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .darkCard(radius: 12)
    }
}

/// One rewrite: the result, what changed, or the original.
struct HistoryDetail: View {
    var entry: HistoryItem
    var close: () -> Void
    @State private var tab = Tab.result
    @State private var copied = false
    private enum Tab { case result, changes, original }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                BackButton(action: close).help("Back to list")
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.mode.title).font(.system(size: 15, weight: .semibold))
                    Text("\(entry.sourceApp) · \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11)).foregroundStyle(PolishDesign.secondaryText)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.result, forType: .string)
                    copied = true
                } label: { Label(copied ? "Copied" : "Copy result", systemImage: copied ? "checkmark" : "doc.on.doc") }
                .buttonStyle(PolishButtonStyle(primary: true))
            }
            SegmentedPicker(options: [(.result, "Result"), (.changes, "Changes"), (.original, "Original")], selection: $tab, compact: true)
            ScrollView {
                Group {
                    switch tab {
                    case .result: Text(entry.result)
                    case .original: Text(entry.original).foregroundStyle(PolishDesign.secondaryText)
                    case .changes: diffText(original: entry.original, result: entry.result) ?? Text("This rewrite is too long to compare.").foregroundStyle(PolishDesign.secondaryText)
                    }
                }
                .font(.system(size: 13)).lineSpacing(5).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }
            .darkCard(radius: 12, fill: PolishDesign.well)
        }
        .onChange(of: entry.id) { _, _ in copied = false; tab = .result }
    }
}
