import SwiftUI
import Charts

/// Chart box: title, "You vs Max" instead of a legend, 200 pt chart on `surface` (design.md §7).
struct ChartCard<Content: View>: View {
    let title: String
    let friendName: String
    /// Value of the tapped point, shown above the chart instead of a pop-up.
    var selectionText: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.rvTextPrimary)
            HStack(spacing: Spacing.xs) {
                Text("You").foregroundStyle(Color.rvAccent)
                Text("vs").foregroundStyle(Color.rvTextSecondary)
                Text(friendName).foregroundStyle(Color.rvTextTertiary)
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

// MARK: - Wins by Sport

/// Bars side by side: your vs. their wins per sport.
struct WinsBySportChart: View {
    let records: [(sport: SportType, record: Record)]
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
