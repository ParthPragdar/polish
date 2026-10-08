import AppKit
import PolishCore
import SwiftUI

/// Home screen: what Polish has done for your writing, drawn from saved history.
struct OverviewView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var history: RewriteHistory
    @ObservedObject var settings: Settings
    @State private var chart = Chart.days
    private enum Chart { case days, apps }
    private var setup: SetupState { controller.setup }

    var body: some View {
        let stats = RewriteStats(items: history.items)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text("Activity").font(.system(size: 26, weight: .bold))
                        Pill(text: Date().formatted(.dateTime.year()))
                    }
                    Text(subtitle(stats)).font(.system(size: 15)).foregroundStyle(PolishDesign.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 16)
                if setup.ready && stats.overall.total > 0 {
                    SegmentedPicker(options: [(.days, "Days"), (.apps, "Apps")], selection: $chart)
                }
            }
            .padding(.horizontal, PolishDesign.pageInset).padding(.top, 24)

            Group {
                if !setup.ready {
                    SetupChecklist(controller: controller).frame(maxWidth: 480)
                } else if stats.overall.total == 0 {
                    emptyState
                } else if chart == .days {
                    RadarChart(tallies: stats.weekdays, today: RewriteStats.weekdayIndex(of: Date()))
                } else {
                    AppRanking(apps: Array(stats.apps.prefix(6)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, PolishDesign.pageInset)

            Rectangle().fill(PolishDesign.hairline).frame(height: 1)
            HStack(spacing: 40) {
                StatTile(systemName: "text.word.spacing", value: stats.words.formatted(), caption: "Words\npolished")
                StatTile(systemName: PolishDesign.symbol(for: .grammar), value: stats.overall.grammar.formatted(), caption: "Grammar\nfixes", tint: PolishDesign.green)
                StatTile(systemName: PolishDesign.symbol(for: .prompt), value: stats.overall.prompt.formatted(), caption: "Prompts\nrefined", tint: PolishDesign.orange)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, PolishDesign.pageInset).frame(height: 96)
        }
    }

    private func subtitle(_ stats: RewriteStats) -> String {
        if !setup.ready { return setup.stepsLeft == 1 ? "One quick step and Polish is ready." : "Two quick steps and Polish is ready." }
        guard let since = stats.since else { return "Select text in any app and press \(settings.grammar.label) to polish it." }
        let passages = stats.overall.total == 1 ? "1 passage" : "\(stats.overall.total) passages"
        return "You polished \(passages) since \(since.formatted(.dateTime.month(.wide).day()))."
    }

    private var emptyState: some View {
        ZStack {
            RadarChart(tallies: Array(repeating: .init(), count: 7), today: RewriteStats.weekdayIndex(of: Date()), showsTooltip: false)
                .opacity(0.5)
            VStack(spacing: 14) {
                Text("Your first rewrite will appear here").font(.system(size: 15, weight: .semibold))
                HStack(spacing: 18) {
                    shortcut(settings.grammar.label, RewriteMode.grammar.title)
                    shortcut(settings.prompt.label, RewriteMode.prompt.title)
                }
            }
            .padding(.horizontal, 22).padding(.vertical, 18)
            .darkCard(fill: PolishDesign.surface.opacity(0.95))
        }
    }
    private func shortcut(_ keys: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            KeyCap(text: keys)
            Text(title).font(.system(size: 12)).foregroundStyle(PolishDesign.secondaryText)
        }
    }
}

/// Rewrites per weekday as a radar, with a tooltip card on the hovered (or busiest) day.
struct RadarChart: View {
    var tallies: [RewriteStats.Tally]
    var today: Int
    var showsTooltip = true
    @State private var hovered: Int?
    private static let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = max(40, min(proxy.size.width, proxy.size.height) / 2 - 34)
            let peak = max(tallies.map(\.total).max() ?? 0, 1)
            let points = tallies.indices.map { index in
                point(index, fraction: tallies[index].total == 0 ? 0.08 : 0.18 + 0.82 * CGFloat(tallies[index].total) / CGFloat(peak), center: center, radius: radius)
            }
            let busiest = tallies.indices.max { tallies[$0].total < tallies[$1].total }
            let focus = hovered ?? (showsTooltip ? busiest : nil)

            ZStack {
                Path { path in
                    for ring in 1...4 {
                        let fraction = CGFloat(ring) / 4
                        path.addLines(tallies.indices.map { point($0, fraction: fraction, center: center, radius: radius) })
                        path.closeSubpath()
                    }
                    for index in tallies.indices {
                        path.move(to: center); path.addLine(to: point(index, fraction: 1, center: center, radius: radius))
                    }
                }.stroke(Color.white.opacity(0.07), lineWidth: 1)

                Path { path in path.addLines(points); path.closeSubpath() }
                    .fill(LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                Path { path in path.addLines(points); path.closeSubpath() }
                    .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

                ForEach(tallies.indices, id: \.self) { index in
                    let isFocus = index == focus
                    Circle()
                        .fill(isFocus ? Color.white : index == today ? PolishDesign.green : Color(white: 0.5))
                        .frame(width: isFocus ? 13 : index == today ? 9 : 7, height: isFocus ? 13 : index == today ? 9 : 7)
                        .shadow(color: isFocus ? Color.white.opacity(0.5) : .clear, radius: 6)
                        .position(points[index])
                    Text(Self.labels[index])
                        .font(.system(size: 11, weight: index == today ? .semibold : .regular))
                        .foregroundStyle(index == today ? PolishDesign.green : PolishDesign.tertiaryText)
                        .position(point(index, fraction: 1, center: center, radius: radius + 20))
                }

                if let focus, tallies[focus].total > 0 {
                    tooltip(for: focus)
                        .position(tooltipPosition(near: points[focus], in: proxy.size))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let nearest = points.indices.min { distance(points[$0], location) < distance(points[$1], location) }
                    hovered = nearest.flatMap { distance(points[$0], location) < 60 ? $0 : nil }
                case .ended:
                    hovered = nil
                }
            }
            .animation(.easeOut(duration: 0.15), value: focus)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rewrites by weekday")
        .accessibilityValue(tallies.indices.map { "\(Self.names[$0]) \(tallies[$0].total)" }.joined(separator: ", "))
    }

    private func tooltip(for index: Int) -> some View {
        let tally = tallies[index]
        return VStack(alignment: .leading, spacing: 5) {
            Text(Self.names[index]).font(.system(size: 15, weight: .bold))
            Text(tally.total == 1 ? "1 rewrite" : "\(tally.total) rewrites").font(.system(size: 14)).foregroundStyle(PolishDesign.secondaryText)
            if tally.grammar > 0 { modeRow(.grammar, tally.grammar) }
            if tally.prompt > 0 { modeRow(.prompt, tally.prompt) }
        }
        .padding(14).frame(width: 190, alignment: .leading)
        .darkCard(radius: 12, fill: Color(white: 0.25))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }
    private func modeRow(_ mode: RewriteMode, _ count: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: PolishDesign.symbol(for: mode)).font(.system(size: 9, weight: .bold)).foregroundStyle(.black)
                .frame(width: 18, height: 18).background(Circle().fill(PolishDesign.tint(for: mode)))
            Text("\(mode.title) · \(count)").font(.system(size: 13))
        }
    }
    private func tooltipPosition(near point: CGPoint, in size: CGSize) -> CGPoint {
        let width: CGFloat = 190, height: CGFloat = 120
        let x = point.x > size.width / 2 ? point.x - width / 2 - 18 : point.x + width / 2 + 18
        return CGPoint(x: min(max(x, width / 2), size.width - width / 2),
                       y: min(max(point.y - 30, height / 2), size.height - height / 2))
    }
    private func point(_ index: Int, fraction: CGFloat, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = -CGFloat.pi / 2 + 2 * .pi * CGFloat(index) / CGFloat(max(tallies.count, 1))
        return CGPoint(x: center.x + cos(angle) * radius * fraction, y: center.y + sin(angle) * radius * fraction)
    }
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}

/// The apps you polish most, with each bar split into grammar and prompt rewrites.
struct AppRanking: View {
    var apps: [RewriteStats.AppUsage]
    var body: some View {
        let peak = max(apps.first?.tally.total ?? 1, 1)
        VStack(spacing: 14) {
            ForEach(apps, id: \.name) { app in
                HStack(spacing: 14) {
                    AppIcon(name: app.name).frame(width: 28, height: 28)
                    Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1).frame(width: 130, alignment: .leading)
                    GeometryReader { proxy in
                        let width = proxy.size.width * CGFloat(app.tally.total) / CGFloat(peak)
                        HStack(spacing: 2) {
                            if app.tally.grammar > 0 {
                                Capsule().fill(PolishDesign.green).frame(width: max(6, width * CGFloat(app.tally.grammar) / CGFloat(app.tally.total)))
                            }
                            if app.tally.prompt > 0 {
                                Capsule().fill(PolishDesign.orange).frame(width: max(6, width * CGFloat(app.tally.prompt) / CGFloat(app.tally.total)))
                            }
                        }.frame(height: 8).frame(maxHeight: .infinity)
                    }.frame(height: 28)
                    Text(app.tally.total.formatted()).font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(PolishDesign.secondaryText).frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: 620)
    }
}

/// The icon of a running or installed app found by its display name, or a generic glyph.
struct AppIcon: View {
    var name: String
    var body: some View {
        if let icon = Self.icon(for: name) {
            Image(nsImage: icon).resizable().interpolation(.high)
        } else {
            IconDisc(systemName: "app.dashed", size: 28)
        }
    }
    private static var cache: [String: NSImage] = [:]
    private static func icon(for name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        let running = NSWorkspace.shared.runningApplications.first { $0.localizedName == name }?.icon
        let installed = ["/Applications", "/System/Applications", "/System/Applications/Utilities"].lazy
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name + ".app") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        let icon = running ?? installed
        if let icon { cache[name] = icon }
        return icon
    }
}

/// A large figure beside a disc icon, with a two-line caption.
struct StatTile: View {
    var systemName: String
    var value: String
    var caption: String
    var tint: Color = Color.white.opacity(0.85)
    var body: some View {
        HStack(spacing: 14) {
            IconDisc(systemName: systemName, size: 42, tint: tint)
            Text(value).font(.system(size: 32, weight: .regular).monospacedDigit()).lineLimit(1)
            Text(caption).font(.system(size: 12)).foregroundStyle(PolishDesign.secondaryText).lineSpacing(1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The two things Polish needs before the first rewrite.
struct SetupChecklist: View {
    @ObservedObject var controller: AppController
    private var setup: SetupState { controller.setup }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FINISH SETTING UP").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(PolishDesign.tertiaryText)
                .padding(.bottom, 14)
            step(1, "Add your Gemini API key", done: setup.hasKey, detail: "Free to create in Google AI Studio.", action: "Add key") {
                controller.settingsSection = "Settings"
            }
            Rectangle().fill(PolishDesign.hairline).frame(height: 1).padding(.vertical, 14)
            step(2, "Allow Accessibility access", done: setup.access == .granted,
                 detail: setup.access == .stale ? "Remove Polish from the list, add it again, then reopen Polish." : "Lets Polish read and replace the text you select.",
                 action: "Open") { TextAccess.openAccessibilitySettings() }
        }
        .padding(22).darkCard()
    }
    private func step(_ number: Int, _ title: String, done: Bool, detail: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(done ? PolishDesign.green : PolishDesign.raised.opacity(0.6))
                if done { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.black) }
                else { Text("\(number)").font(.system(size: 12, weight: .semibold)) }
            }.frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(done ? PolishDesign.secondaryText : .white)
                Text(done ? "Done" : detail).font(.system(size: 12)).foregroundStyle(PolishDesign.secondaryText)
            }
            Spacer(minLength: 8)
            if !done { Button(action, action: perform).buttonStyle(PolishButtonStyle(primary: true)) }
        }
    }
}
