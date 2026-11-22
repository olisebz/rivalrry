import SwiftUI
import SwiftData
import Charts

/// "Elo" in Profile: your rating per sport and mode group. Tapping a row opens `EloDetailView`.
struct EloTableSection: View {
    let entries: [EloEntry]

    private let eloWidth: CGFloat = 76
    private let numberWidth: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Elo")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)

            if entries.isEmpty {
                Text("Play a match to get your first Elo.")
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
            } else {
                VStack(spacing: 0) {
                    header
                    ForEach(entries) { entry in
                        Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                        NavigationLink(value: entry) { row(entry) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.m)
                .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.s) {
            Text("Sport").frame(maxWidth: .infinity, alignment: .leading)
            Text("Elo").frame(width: eloWidth, alignment: .trailing)
            Text("Matches").frame(width: numberWidth, alignment: .trailing)
            Text("30 days").frame(width: numberWidth, alignment: .trailing)
        }
        .font(.caption.weight(.medium))
        .kerning(0.5)
        .textCase(.uppercase)
        .foregroundStyle(Color.rvTextSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.vertical, Spacing.s)
    }

    private func row(_ entry: EloEntry) -> some View {
        HStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Image(systemName: entry.sport.symbolName)
                    .foregroundStyle(Color.rvTextPrimary)
                    .frame(width: 24)
                Text(entry.title)
                    .foregroundStyle(Color.rvTextPrimary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Elo.text(entry.rating))
                .fontWeight(entry.rating == nil ? .regular : .semibold)
                .foregroundStyle(entry.rating == nil ? Color.rvTextSecondary : Color.rvTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: eloWidth, alignment: .trailing)
            Text("\(entry.matches)")
                .foregroundStyle(Color.rvTextPrimary)
                .frame(width: numberWidth, alignment: .trailing)
            Text(Elo.recentText(entry.recentChange))
                .foregroundStyle(EloChangeStyle.color(entry.recentChange.map(Double.init)))
                .frame(width: numberWidth, alignment: .trailing)
        }
        .font(.body.monospacedDigit())
        .padding(.vertical, Spacing.s + Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.title), Elo \(Elo.text(entry.rating)), \(entry.matches) matches, "
                            + "last 30 days \(Elo.recentText(entry.recentChange))")
        .accessibilityAddTraits(.isButton)
    }
}

/// Gains in green, everything else grey (no red: decision 5).
enum EloChangeStyle {
    static func color(_ change: Double?) -> Color {
        guard let change, change.rounded() > 0 else { return .rvTextSecondary }
        return .rvAccent
    }
}

/// Your Elo in one sport and group: current value, "Elo History" chart, then every match newest first.
struct EloDetailView: View {
    let entry: EloEntry
    let me: Player

    @Query private var matches: [Match]
    @State private var selectedDate: Date?

    var body: some View {
        let points = Elo.table(for: matches).history(of: me, sport: entry.sport, group: entry.group)
        let ranked = points.count >= Elo.minimumMatches

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                summary(points: points, ranked: ranked)
                if !points.isEmpty { chart(points) }
                history(points)
            }
            .padding(Spacing.m)
        }
        .background(Color.rvBackground)
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    private func summary(points: [EloPoint], ranked: Bool) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(ranked ? "\(Int((points.last?.rating ?? Elo.start).rounded()))" : "Unranked")
                .font(ranked ? .rvScoreHero : .rvScoreLarge)
                .foregroundStyle(Color.rvTextPrimary)
            Text(ranked ? "\(points.count) matches" : unrankedHint(points.count))
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.m)
    }

    /// "2 more matches to get ranked"
    private func unrankedHint(_ played: Int) -> String {
        let missing = max(1, Elo.minimumMatches - played)
        return missing == 1 ? "1 more match to get ranked" : "\(missing) more matches to get ranked"
    }

    // MARK: - Chart

    private func chart(_ points: [EloPoint]) -> some View {
        let selected = selectedDate.flatMap { date in points.last { $0.date <= date } ?? points.first }

        return ChartCard(title: "Elo History", friendName: "",
                         selectionText: selected.map {
                             "\(MatchDate.text(for: $0.date)): \(Int($0.rating.rounded()))"
                         },
                         showsPlayers: false) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Date", point.date), y: .value("Elo", point.rating))
                        .foregroundStyle(Color.rvAccent)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    // A single match has no line: show it as a point.
                    if points.count == 1 {
                        PointMark(x: .value("Date", point.date), y: .value("Elo", point.rating))
                            .foregroundStyle(Color.rvAccent)
                    }
                }
                RuleMark(y: .value("Start", Elo.start))
                    .foregroundStyle(Color.rvSeparator)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                if let selected {
                    RuleMark(x: .value("Date", selected.date))
                        .foregroundStyle(Color.rvSeparator)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: Date.FormatStyle(locale: Locale(identifier: "en_US"))
                        .month(.abbreviated).day())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.rvTextSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.rvSeparator)
                    AxisValueLabel()
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.rvTextSecondary)
                }
            }
            .chartLegend(.hidden)
            .chartXSelection(value: $selectedDate)
        }
    }

    // MARK: - History

    private func history(_ points: [EloPoint]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("History")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)
            VStack(spacing: 0) {
                ForEach(Array(points.reversed().enumerated()), id: \.offset) { index, point in
                    if index > 0 { Rectangle().fill(Color.rvSeparator).frame(height: 0.5) }
                    if let match = point.match {
                        NavigationLink {
                            MatchDetailView(match: match, me: me)
                        } label: {
                            historyRow(point, match: match)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func historyRow(_ point: EloPoint, match: Match) -> some View {
        let outcome = match.outcome(for: me)
        return HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(match.opponentsText(for: me))
                    .font(.body)
                    .foregroundStyle(Color.rvTextPrimary)
                    .lineLimit(1)
                Text(MatchDate.text(for: match.date))
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
            }
            Spacer(minLength: Spacing.s)
            Text(match.scoreText(for: me))
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(outcome == .win ? Color.rvAccent : Color.rvTextPrimary)
                .lineLimit(1)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Elo.changeText(point.change))
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(EloChangeStyle.color(point.change))
                Text("\(Int(point.rating.rounded()))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.rvTextSecondary)
            }
            .frame(minWidth: 52, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rvTextTertiary)
        }
        .padding(.vertical, Spacing.s + Spacing.xs)
        .contentShape(Rectangle())
    }
}

#Preview("Elo table") {
    let container = SampleData.container()
    let me = SampleData.player("Alex Morgan", in: container)
    let matches = (try? container.mainContext.fetch(FetchDescriptor<Match>())) ?? []
    return NavigationStack {
        ScrollView {
            EloTableSection(entries: Elo.table(for: matches).entries(of: me))
                .padding(Spacing.m)
        }
        .navigationDestination(for: EloEntry.self) { EloDetailView(entry: $0, me: me) }
    }
    .modelContainer(container)
}
