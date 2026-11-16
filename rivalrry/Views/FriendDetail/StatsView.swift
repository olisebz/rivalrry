import SwiftUI
import SwiftData

/// S2c – Stats (plan.md §4 S2c, Phase 1). Per-sport rows live here as "By Sport" (decision 2).
struct StatsView: View {
    let me: Player
    let friend: Player
    let allMatches: [Match]

    // Filters stay saved per friend (plan.md §4 S2c).
    @AppStorage private var sportRaw: String
    @AppStorage private var periodRaw: String
    @AppStorage private var modeRaw: String

    init(me: Player, friend: Player, allMatches: [Match]) {
        self.me = me
        self.friend = friend
        self.allMatches = allMatches
        let key = "stats.\(friend.id.uuidString)"
        _sportRaw = AppStorage(wrappedValue: "", "\(key).sport")
        _periodRaw = AppStorage(wrappedValue: StatsPeriod.all.rawValue, "\(key).period")
        _modeRaw = AppStorage(wrappedValue: "singles", "\(key).mode")
    }

    private var sport: SportType? { SportType(rawValue: sportRaw) }
    private var period: StatsPeriod { StatsPeriod(rawValue: periodRaw) ?? .all }
    private var mode: ModeFilter {
        switch modeRaw {
        case "team": .team
        case "all": .all
        default: .singles
        }
    }

    var body: some View {
        let sports = Rivalry.sportsPlayed(of: me, with: friend, in: allMatches)
        let filter = DuelFilter(sport: sport, mode: mode, since: period.since())
        let duels = Rivalry.duels(of: me, against: friend, in: allMatches, filter: filter)
        let record = Rivalry.record(of: me, against: friend, in: allMatches, filter: filter)
        let bySport = Rivalry.recordsBySport(of: me, against: friend, in: allMatches, filter: filter)

        VStack(alignment: .leading, spacing: Spacing.l) {
            filters(sports: sports)

            if duels.isEmpty {
                EmptyStateView(symbol: "chart.xyaxis.line", message: "Play a few matches to see stats.")
            } else {
                VStack(spacing: Spacing.m) {
                    HStack(spacing: Spacing.s) {
                        StatTile(title: "Win rate", value: Rivalry.percentText(record.winRate))
                        StatTile(title: "Matches", value: "\(record.matches)")
                    }

                    RecordOverTimeChart(points: Rivalry.cumulativeWins(duels), friendName: friend.shortName)

                    if sport == nil {
                        WinsBySportChart(records: bySport, friendName: friend.shortName)
                    }

                    WinRateChart(record: record, friendName: friend.shortName)
                }
                .padding(.horizontal, Spacing.m)

                if sport == nil {
                    BySportList(records: bySport) { selected in
                        withAnimation(.spring(duration: 0.3)) { sportRaw = selected.rawValue }
                    }
                    .padding(.horizontal, Spacing.m)
                }
            }
        }
    }

    // MARK: - Filters

    private func filters(sports: [SportType]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if sports.count > 1 {
                FilterChips(options: [(value: "", title: "All")] + sports.map { (value: $0.rawValue, title: $0.displayName) },
                            selection: $sportRaw)
            }

            HStack(spacing: Spacing.s) {
                Picker("Period", selection: $periodRaw) {
                    ForEach(StatsPeriod.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)

                Menu {
                    Picker("Mode", selection: $modeRaw) {
                        Text(ModeFilter.singles.title).tag("singles")
                        Text(ModeFilter.team.title).tag("team")
                        Text(ModeFilter.all.title).tag("all")
                    }
                } label: {
                    Label("Mode: \(mode.title)", systemImage: "line.3.horizontal.decrease")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.rvTextPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, Spacing.s + Spacing.xs)
                        .frame(minHeight: 32)
                        .background(Color.rvSurface, in: Capsule())
                }
                .fixedSize()
            }
            .padding(.horizontal, Spacing.m)
        }
    }
}

/// "By Sport": one row per sport with record and win share bar. Tapping filters by that sport.
struct BySportList: View {
    let records: [(sport: SportType, record: Record)]
    let select: (SportType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("By Sport")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)

            ForEach(records, id: \.sport) { entry in
                Button {
                    select(entry.sport)
                } label: {
                    VStack(spacing: Spacing.s) {
                        HStack {
                            Text(entry.sport.displayName)
                                .font(.body)
                                .foregroundStyle(Color.rvTextPrimary)
                            Spacer()
                            RecordText(record: entry.record, font: .body.weight(.semibold).monospacedDigit())
                        }
                        WinShareBar(share: entry.record.winShare)
                    }
                    .padding(.vertical, Spacing.s)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
