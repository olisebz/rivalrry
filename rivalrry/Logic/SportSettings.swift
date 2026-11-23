import Foundation
import SwiftData

/// Per-device sport settings (S0 favorites, S9 "Sports"). Stored in UserDefaults, not in the database.
enum SportSettings {
    static let favoritesKey = "sports.favorites"
    static let hiddenKey = "sports.hidden"
    /// Hidden custom sports, as comma-separated IDs.
    static let hiddenCustomKey = "sports.hiddenCustom"
    static let onboardedKey = "onboarding.done"

    static func formatKey(_ sport: SportType) -> String { "sports.bestOf.\(sport.rawValue)" }

    /// Stored as comma-separated raw values, e.g. "badminton,padel".
    static func decode(_ raw: String) -> [SportType] {
        raw.split(separator: ",").compactMap { SportType(rawValue: String($0)) }
    }

    static func encode(_ sports: [SportType]) -> String {
        sports.map(\.rawValue).joined(separator: ",")
    }

    static func decodeIDs(_ raw: String) -> Set<UUID> {
        Set(raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    static func encodeIDs(_ ids: Set<UUID>) -> String {
        ids.map(\.uuidString).sorted().joined(separator: ",")
    }

    /// Sports for the S2b grid: hidden ones removed, favorites first (plan.md §4 S0), otherwise fixed order.
    /// Custom sports come after the built-in ones, by name.
    static func entrySports(favorites: [SportType], hidden: [SportType],
                            custom: [CustomSport] = [], hiddenCustom: Set<UUID> = []) -> [Sport] {
        let visible = SportType.phase1Sports.filter { !hidden.contains($0) }
        let builtIn = visible.filter { favorites.contains($0) } + visible.filter { !favorites.contains($0) }
        let own = custom
            .filter { !hiddenCustom.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return builtIn.map(Sport.init) + own.map(Sport.init)
    }

    /// Default "Best of" for a sport: the S9 setting if valid, otherwise plan.md §2.2. Custom sets: Best of 3.
    static func defaultBestOf(for sport: Sport, defaults: UserDefaults = .standard) -> Int? {
        guard let type = sport.builtIn else { return sport.defaultBestOf }
        let stored = defaults.integer(forKey: formatKey(type))
        return type.bestOfOptions.contains(stored) ? stored : type.defaultBestOf
    }

    /// "Reset All Data": back to a fresh install.
    static func reset(defaults: UserDefaults = .standard) {
        for key in [favoritesKey, hiddenKey, hiddenCustomKey, onboardedKey] { defaults.removeObject(forKey: key) }
        for sport in SportType.allCases { defaults.removeObject(forKey: formatKey(sport)) }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("stats.") {
            defaults.removeObject(forKey: key)
        }
    }
}

/// S9 "own stats" across all friends (plan.md §4 S9).
struct ProfileStats: Equatable {
    let record: Record
    /// Most matches played.
    let favoriteSport: Sport?
    /// Friend with the most matches.
    let biggestRival: Player?

    static func == (lhs: ProfileStats, rhs: ProfileStats) -> Bool {
        lhs.record == rhs.record && lhs.favoriteSport == rhs.favoriteSport
            && lhs.biggestRival?.id == rhs.biggestRival?.id
    }
}

extension Rivalry {

    /// Overall record (default record: 1v1 & Race), favorite sport and biggest rival of `me`.
    static func profileStats(of me: Player, in matches: [Match]) -> ProfileStats {
        var record = Record()
        var sportCounts: [Sport: Int] = [:]
        var rivalCounts: [UUID: (player: Player, count: Int)] = [:]

        for match in matches where match.countsTowardRecord && match.includes(me) {
            let duels = match.duels(for: me)
            guard !duels.isEmpty else { continue }
            sportCounts[match.sport, default: 0] += 1
            // The overall record uses the default filter (1v1 & Race), like every record.
            if DuelFilter().includes(match) {
                for duel in duels { record.add(duel.outcome) }
            }
            // Count each opponent once per match.
            var seen = Set<UUID>()
            for duel in duels {
                guard let opponent = duel.opponent, seen.insert(opponent.id).inserted else { continue }
                rivalCounts[opponent.id, default: (opponent, 0)].count += 1
            }
        }

        let favorite = sportCounts.max {
            $0.value != $1.value ? $0.value < $1.value : $0.key.displayName > $1.key.displayName
        }?.key
        let rival = rivalCounts.values.max {
            $0.count != $1.count ? $0.count < $1.count : $0.player.name > $1.player.name
        }?.player
        return ProfileStats(record: record, favoriteSport: favorite, biggestRival: rival)
    }

    /// "Reset All Data": deletes every match, player and custom sport.
    static func resetAllData(in context: ModelContext) throws {
        // One by one instead of a batch delete: batch deletes fail on the relationships.
        // Deleting a match cascades to its sets, shots, fight and participants.
        for match in try context.fetch(FetchDescriptor<Match>()) { context.delete(match) }
        for player in try context.fetch(FetchDescriptor<Player>()) { context.delete(player) }
        for sport in try context.fetch(FetchDescriptor<CustomSport>()) { context.delete(sport) }
        for pending in try context.fetch(FetchDescriptor<PendingAction>()) { context.delete(pending) }
        try context.save()
    }
}
