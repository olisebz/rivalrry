import Foundation

/// A sport as you see it: built in (`SportType`) or your own (`CustomSport`, Phase 2).
/// Two sports are the same if their `key` is: built-in by raw value, custom by ID.
/// Record, Elo, filters and "By Sport" all group by this, so every custom sport counts on its own.
struct Sport: Hashable, Identifiable {
    enum Key: Hashable {
        case builtIn(SportType)
        case custom(UUID)
    }

    let key: Key
    /// `nil` for custom sports.
    let builtIn: SportType?
    /// `nil` for built-in sports.
    let custom: CustomSport?

    init(_ type: SportType) {
        key = .builtIn(type)
        builtIn = type
        custom = nil
    }

    init(_ custom: CustomSport) {
        key = .custom(custom.id)
        builtIn = nil
        self.custom = custom
    }

    static func == (lhs: Sport, rhs: Sport) -> Bool { lhs.key == rhs.key }
    func hash(into hasher: inout Hasher) { hasher.combine(key) }

    /// Stable text form for UserDefaults: "badminton", "custom.<UUID>".
    var id: String {
        switch key {
        case .builtIn(let type): type.rawValue
        case .custom(let id): "custom.\(id.uuidString)"
        }
    }

    var isCustom: Bool { custom != nil }

    /// `SportType` stored on a match: the built-in type, or `.custom`.
    var storedType: SportType { builtIn ?? .custom }

    // MARK: - Configuration

    var displayName: String { custom?.name ?? storedType.displayName }
    var symbolName: String { custom?.symbolName ?? storedType.symbolName }
    var scoringType: ScoringType { custom?.scoringType ?? storedType.scoringType }

    var allowsDraw: Bool {
        guard let custom else { return storedType.allowsDraw }
        switch custom.scoringType {
        case .winLoss, .points: return custom.allowsDraw
        // Same time is always a draw (like Running); sets can't end in a draw.
        case .time: return true
        default: return false
        }
    }

    /// Players per team in `Team` mode, `nil` without a team mode. Custom: any size like Football.
    var teamSizes: ClosedRange<Int>? {
        guard let custom else { return storedType.teamSizes }
        return custom.allowsTeams && CustomSport.teamScoringTypes.contains(custom.scoringType) ? 2...11 : nil
    }

    var bestOfOptions: [Int] {
        guard isCustom else { return storedType.bestOfOptions }
        return scoringType == .sets ? [1, 3, 5] : []
    }

    var defaultBestOf: Int? {
        guard isCustom else { return storedType.defaultBestOf }
        return scoringType == .sets ? 3 : nil
    }

    /// Custom sets: own points per set and lead, no cap, no tiebreak (plan.md §2.2).
    var setRules: SetRules? {
        guard let custom else { return storedType.setRules }
        guard custom.scoringType == .sets else { return nil }
        return SetRules(pointsToWin: custom.pointsPerSet ?? CustomSport.defaultPointsPerSet,
                        winBy: custom.winBy ?? CustomSport.defaultWinBy, maxPoints: nil, tiebreak: nil)
    }

    /// Only Running has fixed distances; custom time sports just compare times.
    var usesDistance: Bool { builtIn == .running }

    /// Go-Kart's fastest lap field.
    var usesLaps: Bool { builtIn == .goKart }

    // MARK: - Built-in sports

    static let badminton = Sport(.badminton)
    static let padel = Sport(.padel)
    static let tennis = Sport(.tennis)
    static let pingPong = Sport(.pingPong)
    static let football = Sport(.football)
    static let basketball = Sport(.basketball)
    static let penaltyShootout = Sport(.penaltyShootout)
    static let boxing = Sport(.boxing)
    static let goKart = Sport(.goKart)
    static let running = Sport(.running)

    static let builtInSports = SportType.phase1Sports.map(Sport.init)
}

extension Match {
    /// The sport of this match. A match whose custom sport is gone shows as "Custom".
    var sport: Sport { customSport.map(Sport.init) ?? Sport(sportType) }
}
