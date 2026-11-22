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
        // A saved sport filter for a sport that's no longer played falls back to "All".
        let sport = sports.first { $0.id == sportRaw }
        let filter = DuelFilter(sport: sport, mode: mode, since: period.since())
        let duels = Rivalry.duels(of: me, against: friend, in: allMatches, filter: filter)
        let record = Rivalry.record(of: me, against: friend, in: allMatches, filter: filter)
        let bySport = Rivalry.recordsBySport(of: me, against: friend, in: allMatches, filter: filter)
        // Partners, not opponents: independent of the "Mode" filter (decision 9).
        let together = Rivalry.togetherRecord(of: me, with: friend, in: allMatches,
                                              filter: DuelFilter(sport: sport, mode: .team, since: period.since()))
        // Always the current rating from all matches; "Period" only limits "Elo History" (plan.md §2.4).
        let elo = Elo.table(for: allMatches)
        let group = EloGroup(mode)

        VStack(alignment: .leading, spacing: Spacing.l) {
            filters(sports: sports)

            if duels.isEmpty {
                EmptyStateView(symbol: "chart.xyaxis.line", message: "Play a few matches to see stats.")
            } else {
                VStack(spacing: Spacing.m) {
                    HStack(spacing: Spacing.s) {
                        StatTile(title: "Matches", value: "\(record.matches)")
                        StatTile(title: "Win rate", value: Rivalry.percentText(record.winRate))
                    }
                    HStack(spacing: Spacing.s) {
                        StatTile(title: "Current streak", value: Rivalry.currentStreak(duels)?.shortText ?? "–")
                        StatTile(title: "Longest streak", value: Rivalry.longestWinStreak(duels)?.shortText ?? "–")
                    }

                    // Margins only compare within one sport with a score.
                    if let sport, Rivalry.hasMargin(sport) {
                        HighlightsRow(closest: Rivalry.closestWin(duels, me: me),
                                      biggest: Rivalry.biggestWin(duels, me: me),
                                      me: me)
                    }

                    // Who is better in this sport, in detail (decision 8).
                    if let sport {
                        let eloRow = Elo.comparisonRow(mine: elo.rating(of: me, sport: sport, group: group),
                                                       theirs: elo.rating(of: friend, sport: sport, group: group))
                        HeadToHeadCard(sport: sport, record: record,
                                       rows: [eloRow] + SportComparison.rows(for: sport, duels: duels, me: me),
                                       friendName: friend.shortName)
                    }

                    RecordOverTimeChart(points: Rivalry.cumulativeWins(duels), friendName: friend.shortName)

                    // Elo only from 3 matches: shown once one of you is ranked.
                    if let sport, elo.isRanked(me, sport: sport, group: group)
                        || elo.isRanked(friend, sport: sport, group: group) {
                        let since = period.since()
                        let window = { (points: [EloPoint]) in
                            points.filter { point in since.map { point.date >= $0 } ?? true }
                        }
                        EloHistoryChart(mine: window(elo.history(of: me, sport: sport, group: group)),
                                        theirs: window(elo.history(of: friend, sport: sport, group: group)),
                                        friendName: friend.shortName)
                    }

                    if let sport, Rivalry.hasMargin(sport) {
                        ScoreMarginChart(points: Rivalry.margins(duels, me: me), friendName: friend.shortName)
                    }

                    if sport == .running {
                        let runs = Rivalry.runTimes(duels, me: me, friend: friend)
                        if !runs.isEmpty {
                            RunTimesChart(runs: runs, friendName: friend.shortName)
                        }
                    }

                    if sport == nil {
                        WinsBySportChart(records: bySport, friendName: friend.shortName)
                    }

                    WinRateChart(record: record, friendName: friend.shortName)

                    ActivityChart(weeks: Rivalry.activityWeeks(duels, from: Rivalry.activityStart(for: period)),
                                  friendName: friend.shortName)
                }
                .padding(.horizontal, Spacing.m)

                if sport == nil {
                    BySportList(records: bySport, eloText: { sport in
                        Elo.summary(mine: elo.rating(of: me, sport: sport, group: group),
                                    theirs: elo.rating(of: friend, sport: sport, group: group))
                    }) { selected in
                        withAnimation(.spring(duration: 0.3)) { sportRaw = selected.id }
                    }
                    .padding(.horizontal, Spacing.m)
                }
            }

            if together.matches > 0 {
                TogetherCard(record: together, friendName: friend.shortName)
                    .padding(.horizontal, Spacing.m)
            }
        }
    }

    // MARK: - Filters

    private func filters(sports: [Sport]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            // Also keep the chips while a sport is selected, so "All" is always reachable.
            if sports.count > 1 || sports.contains(where: { $0.id == sportRaw }) {
                FilterChips(options: [(value: "", title: "All")] + sports.map { (value: $0.id, title: $0.displayName) },
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
    let records: [(sport: Sport, record: Record)]
    /// "Elo 1240 vs 1180" below the sport name, `nil` to leave it out.
    var eloText: (Sport) -> String? = { _ in nil }
    let select: (Sport) -> Void

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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.sport.displayName)
                                    .font(.body)
                                    .foregroundStyle(Color.rvTextPrimary)
                                if let elo = eloText(entry.sport) {
                                    Text(elo)
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(Color.rvTextSecondary)
                                }
                            }
                            Spacer()
                            RecordText(record: entry.record, font: .body.weight(.semibold).monospacedDigit())
                            // Tapping opens the sport's "Head to Head".
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.rvTextTertiary)
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

/// "Highlights": horizontally scrolling tiles "Closest win", "Biggest win" (plan.md §4 S2a, decision 9).
struct HighlightsRow: View {
    let closest: WinHighlight?
    let biggest: WinHighlight?
    let me: Player

    var body: some View {
        if closest != nil || biggest != nil {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Highlights")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.rvTextPrimary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s) {
                        if let closest { tile("Closest win", closest) }
                        if let biggest { tile("Biggest win", biggest) }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private func tile(_ title: String, _ highlight: WinHighlight) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.caption.weight(.medium))
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.rvTextSecondary)
            Text(highlight.match.scoreText(for: me))
                .font(.rvScoreLarge)
                .foregroundStyle(Color.rvTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(MatchDate.text(for: highlight.match.date))
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
        }
        .frame(width: 160, alignment: .leading)
        .padding(Spacing.m)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// "Together": your record when you and the friend were on the same team (plan.md §4 S2a, decision 9).
struct TogetherCard: View {
    let record: Record
    let friendName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Together")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)
            HStack {
                Text("As partners")
                    .font(.body)
                    .foregroundStyle(Color.rvTextPrimary)
                Spacer()
                RecordText(record: record, font: .body.weight(.semibold).monospacedDigit())
            }
            WinShareBar(share: record.winShare)
            Text("You and \(friendName) on the same team")
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
