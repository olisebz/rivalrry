import SwiftUI
import Charts

/// Chart box: title, "You vs Max" instead of a legend, 200 pt chart on `surface` (design.md §7).
struct ChartCard<Content: View>: View {
    let title: String
    let friendName: String
    /// Value of the tapped point, shown above the chart instead of a pop-up.
    var selectionText: String? = nil
    /// "You vs Max"; off for charts about both of you together ("Activity").
    var showsPlayers = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.rvTextPrimary)
            HStack(spacing: Spacing.xs) {
                if showsPlayers {
                    Text("You").foregroundStyle(Color.rvAccent)
                    Text("vs").foregroundStyle(Color.rvTextSecondary)
                    Text(friendName).foregroundStyle(Color.rvTextTertiary)
                }
                if let selectionText {
                    Spacer()
                    Text(selectionText)
                        .foregroundStyle(Color.rvTextPrimary)
                        .monospacedDigit()
                }
            }
            .font(.caption.weight(.medium))

            content()
                .frame(height: 200)
        }
        .padding(Spacing.m)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        // Month names etc. always in English.
        .environment(\.locale, Locale(identifier: "en_US"))
    }
}

/// Only very fine horizontal grid lines, small labels (design.md §7).
private struct QuietAxes: ViewModifier {
    func body(content: Content) -> some View {
        content
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
    }
}

// MARK: - Record over Time

/// Two lines: cumulative wins of both players.
struct RecordOverTimeChart: View {
    let points: [CumulativePoint]
    let friendName: String
    @State private var selectedDate: Date?

    /// "Oct 5" for up to ~3 months, otherwise "Oct", so labels don't repeat.
    private var axisFormat: Date.FormatStyle {
        let english = Locale(identifier: "en_US")
        guard let first = points.first?.date, let last = points.last?.date,
              last.timeIntervalSince(first) > 90 * 86_400 else {
            return Date.FormatStyle(locale: english).month(.abbreviated).day()
        }
        return Date.FormatStyle(locale: english).month(.abbreviated)
    }

    var body: some View {
        let selected = selectedDate.flatMap { Rivalry.point(at: $0, in: points) }

        ChartCard(title: "Record over Time", friendName: friendName,
                  selectionText: selected.map {
                      "\(MatchDate.text(for: $0.date)): \($0.myWins) – \($0.theirWins)"
                  }) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Date", point.date), y: .value("Wins", point.myWins),
                             series: .value("Player", "You"))
                        .foregroundStyle(Color.rvAccent)
                    LineMark(x: .value("Date", point.date), y: .value("Wins", point.theirWins),
                             series: .value("Player", friendName))
                        .foregroundStyle(Color.rvTextTertiary)
                }
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if let selected {
                    RuleMark(x: .value("Date", selected.date))
                        .foregroundStyle(Color.rvSeparator)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: axisFormat)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.rvTextSecondary)
                }
            }
            .modifier(QuietAxes())
            .chartXSelection(value: $selectedDate)
        }
    }
}

// MARK: - Elo History

/// Two lines: the Elo of both players after each of their matches in one sport (plan.md §4 S2c).
struct EloHistoryChart: View {
    let mine: [EloPoint]
    let theirs: [EloPoint]
    let friendName: String
    @State private var selectedDate: Date?

    private var axisFormat: Date.FormatStyle {
        let english = Locale(identifier: "en_US")
        let dates = (mine + theirs).map(\.date)
        guard let first = dates.min(), let last = dates.max(),
              last.timeIntervalSince(first) > 90 * 86_400 else {
            return Date.FormatStyle(locale: english).month(.abbreviated).day()
        }
        return Date.FormatStyle(locale: english).month(.abbreviated)
    }

    /// Rating on or before `date`, "–" if the player hadn't played yet.
    private func value(at date: Date, in points: [EloPoint]) -> String {
        points.last { $0.date <= date }.map { "\(Int($0.rating.rounded()))" } ?? "–"
    }

    var body: some View {
        ChartCard(title: "Elo History", friendName: friendName,
                  selectionText: selectedDate.map {
                      "\(MatchDate.text(for: $0)): \(value(at: $0, in: mine)) – \(value(at: $0, in: theirs))"
                  }) {
            Chart {
                ForEach(Array(mine.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Date", point.date), y: .value("Elo", point.rating),
                             series: .value("Player", "You"))
                        .foregroundStyle(Color.rvAccent)
                }
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                ForEach(Array(theirs.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Date", point.date), y: .value("Elo", point.rating),
                             series: .value("Player", friendName))
                        .foregroundStyle(Color.rvTextTertiary)
                }
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if let selectedDate {
                    RuleMark(x: .value("Date", selectedDate))
                        .foregroundStyle(Color.rvSeparator)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: axisFormat)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.rvTextSecondary)
                }
            }
            .modifier(QuietAxes())
            .chartXSelection(value: $selectedDate)
        }
    }
}

// MARK: - Score Margin

/// One bar per match: above 0 = you win (plan.md §4 S2c). Your wins green, the rest grey.
struct ScoreMarginChart: View {
    let points: [MarginPoint]
    let friendName: String
    @State private var selectedIndex: Int?

    var body: some View {
        let selected = selectedIndex.flatMap { points.indices.contains($0) ? points[$0] : nil }

        ChartCard(title: "Score Margin", friendName: friendName,
                  selectionText: selected.map {
                      "\(MatchDate.text(for: $0.match.date)): \($0.margin > 0 ? "+" : "")\($0.margin)"
                  }) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    BarMark(x: .value("Match", index), y: .value("Margin", point.margin))
                        .foregroundStyle(point.outcome == .win ? Color.rvAccent : Color.rvTextTertiary)
                        .cornerRadius(4)
                        .opacity(selectedIndex == nil || selectedIndex == index ? 1 : 0.5)
                }
                RuleMark(y: .value("Margin", 0))
                    .foregroundStyle(Color.rvSeparator)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .chartXAxis(.hidden)
            .chartXScale(domain: -0.5...Double(max(points.count, 1)) - 0.5)
            .modifier(QuietAxes())
            .chartXSelection(value: $selectedIndex)
        }
    }
}

// MARK: - Activity

/// Calendar heatmap: one column per week, one cell per day; stronger green = more matches.
struct ActivityChart: View {
    let weeks: [[ActivityDay?]]
    let friendName: String

    private var daysPlayed: Int {
        weeks.joined().compactMap { $0 }.filter { $0.matches > 0 }.count
    }

    var body: some View {
        let days = daysPlayed
        ChartCard(title: "Activity", friendName: friendName,
                  selectionText: days == 1 ? "1 day played" : "\(days) days played",
                  showsPlayers: false) {
            GeometryReader { proxy in
                let spacing: CGFloat = weeks.count > 26 ? 2 : 4
                let columns = CGFloat(max(weeks.count, 1))
                let byWidth = (proxy.size.width - spacing * (columns - 1)) / columns
                let byHeight = (proxy.size.height - spacing * 6) / 7
                let cell = max(2, min(byWidth, byHeight, 24))

                HStack(alignment: .top, spacing: spacing) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { index in
                                RoundedRectangle(cornerRadius: min(4, cell / 4), style: .continuous)
                                    .fill(color(week[index]))
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(days == 1 ? "1 day played" : "\(days) days played")
        }
    }

    private func color(_ day: ActivityDay?) -> Color {
        guard let day else { return .clear }
        switch day.matches {
        case 0: return Color.rvSeparator.opacity(0.5)
        case 1: return Color.rvAccent.opacity(0.4)
        case 2: return Color.rvAccent.opacity(0.7)
        default: return Color.rvAccent
        }
    }
}

// MARK: - Running times

/// Times of both runners at one distance, chips to switch distances; best times marked.
struct RunTimesChart: View {
    let runs: [Int: [RunPoint]]
    let friendName: String
    @State private var distance: Int?
    @State private var selectedDate: Date?

    var body: some View {
        let distances = Rivalry.distancesByRuns(runs)
        let current = distance.flatMap { distances.contains($0) ? $0 : nil } ?? distances.first
        let points = current.flatMap { runs[$0] } ?? []
        let bestMine = points.compactMap(\.mine).min()
        let bestTheirs = points.compactMap(\.theirs).min()
        let selected = selectedDate.flatMap { date in points.last { $0.date <= date } ?? points.first }

        VStack(alignment: .leading, spacing: Spacing.s) {
            if distances.count > 1 {
                FilterChips(options: distances.map { (value: $0, title: TimeText.distance($0)) },
                            selection: Binding(get: { current ?? 0 }, set: { distance = $0 }))
                    .padding(.horizontal, -Spacing.m)
            }

            ChartCard(title: current.map { "Times · \(TimeText.distance($0))" } ?? "Times",
                      friendName: friendName,
                      selectionText: selected.map {
                          "\(MatchDate.text(for: $0.date)): \(time($0.mine)) – \(time($0.theirs))"
                      }) {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        if let mine = point.mine {
                            LineMark(x: .value("Date", point.date), y: .value("Time", mine),
                                     series: .value("Player", "You"))
                                .foregroundStyle(Color.rvAccent)
                            if mine == bestMine {
                                PointMark(x: .value("Date", point.date), y: .value("Time", mine))
                                    .foregroundStyle(Color.rvAccent)
                                    .symbolSize(80)
                            }
                        }
                        if let theirs = point.theirs {
                            LineMark(x: .value("Date", point.date), y: .value("Time", theirs),
                                     series: .value("Player", friendName))
                                .foregroundStyle(Color.rvTextTertiary)
                            if theirs == bestTheirs {
                                PointMark(x: .value("Date", point.date), y: .value("Time", theirs))
                                    .foregroundStyle(Color.rvTextTertiary)
                                    .symbolSize(80)
                            }
                        }
                    }
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

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
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.rvSeparator)
                        AxisValueLabel {
                            if let ms = value.as(Int.self) {
                                Text(TimeText.text(milliseconds: ms))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.rvTextSecondary)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXSelection(value: $selectedDate)
            }
        }
    }

    private func time(_ ms: Int?) -> String {
        ms.map { TimeText.text(milliseconds: $0) } ?? "–"
    }
}

// MARK: - Wins by Sport

/// Bars side by side: your vs. their wins per sport.
struct WinsBySportChart: View {
    let records: [(sport: Sport, record: Record)]
    let friendName: String
    @State private var selectedSport: String?

    var body: some View {
        let selected = records.first { $0.sport.displayName == selectedSport }

        ChartCard(title: "Wins by Sport", friendName: friendName,
                  selectionText: selected.map { "\($0.sport.displayName): \($0.record.wins) – \($0.record.losses)" }) {
            Chart {
                ForEach(records, id: \.sport) { entry in
                    BarMark(x: .value("Sport", entry.sport.displayName), y: .value("Wins", entry.record.wins))
                        .position(by: .value("Player", "You"))
                        .foregroundStyle(Color.rvAccent)
                        .cornerRadius(4)
                    BarMark(x: .value("Sport", entry.sport.displayName), y: .value("Wins", entry.record.losses))
                        .position(by: .value("Player", friendName))
                        .foregroundStyle(Color.rvTextTertiary)
                        .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.rvTextSecondary)
                }
            }
            .modifier(QuietAxes())
            .chartXSelection(value: $selectedSport)
        }
    }
}

// MARK: - Win Rate

/// Donut: wins (green) / losses (grey) / draws (separator), win rate in the middle.
struct WinRateChart: View {
    let record: Record
    let friendName: String

    var body: some View {
        ChartCard(title: "Win Rate", friendName: friendName) {
            HStack(spacing: Spacing.l) {
                Chart(Rivalry.outcomeShares(record), id: \.outcome) { share in
                    SectorMark(angle: .value("Count", share.count), innerRadius: .ratio(0.62), angularInset: 1.5)
                        .cornerRadius(4)
                        .foregroundStyle(color(share.outcome))
                }
                .chartLegend(.hidden)
                .chartBackground { _ in
                    Text(Rivalry.percentText(record.winRate))
                        .font(.rvScoreLarge)
                        .foregroundStyle(Color.rvTextPrimary)
                        .minimumScaleFactor(0.6)
                        .padding(Spacing.l)
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    row("Wins", record.wins, .win)
                    row("Losses", record.losses, .loss)
                    if record.draws > 0 { row("Draws", record.draws, .draw) }
                }
                .font(.subheadline)
                .frame(maxWidth: 120, alignment: .leading)
            }
        }
    }

    private func color(_ outcome: DuelOutcome) -> Color {
        switch outcome {
        case .win: .rvAccent
        case .loss: .rvTextTertiary
        case .draw: .rvSeparator
        }
    }

    private func row(_ title: String, _ count: Int, _ outcome: DuelOutcome) -> some View {
        HStack(spacing: Spacing.s) {
            Circle().fill(color(outcome)).frame(width: 8, height: 8)
            Text(title).foregroundStyle(Color.rvTextSecondary)
            Spacer()
            Text("\(count)").foregroundStyle(Color.rvTextPrimary).monospacedDigit()
        }
    }
}

/// Key figure tile (design.md §6.6): small caps label, big number.
struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.caption.weight(.medium))
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.rvTextSecondary)
            Text(value)
                .font(.rvScoreLarge)
                .foregroundStyle(Color.rvTextPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

#Preview("Win Rate + By Sport") {
    ScrollView {
        VStack(spacing: Spacing.l) {
            WinRateChart(record: Record(wins: 12, losses: 9, draws: 1), friendName: "Max")
            BySportList(records: [(sport: .badminton, record: Record(wins: 5, losses: 3)),
                                  (sport: .pingPong, record: Record(wins: 4, losses: 2)),
                                  (sport: .football, record: Record(wins: 2, losses: 3, draws: 1)),
                                  (sport: .penaltyShootout, record: Record(wins: 1, losses: 1))]) { _ in }
        }
        .padding(Spacing.m)
    }
    .background(Color.rvBackground)
}
