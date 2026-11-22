import Foundation
import SwiftData

/// The form for creating or editing a custom sport (plan.md §2.2 "Custom sport", §4 S9).
struct CustomSportForm: Equatable {
    var name = ""
    var symbolName = CustomSport.symbols[0]
    var scoringType: ScoringType = .winLoss
    var allowsDraw = false
    var allowsTeams = false
    var pointsPerSet = CustomSport.defaultPointsPerSet
    var winBy = CustomSport.defaultWinBy

    static let nameLimit = 30

    init() {}

    init(sport: CustomSport) {
        name = sport.name
        symbolName = sport.symbolName
        scoringType = sport.scoringType
        allowsDraw = sport.allowsDraw
        allowsTeams = sport.allowsTeams
        pointsPerSet = sport.pointsPerSet ?? CustomSport.defaultPointsPerSet
        winBy = sport.winBy ?? CustomSport.defaultWinBy
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// "Draws allowed" only where a draw can be entered; "Team mode allowed" only for non-races.
    var showsDraws: Bool { CustomSport.drawScoringTypes.contains(scoringType) }
    var showsTeams: Bool { CustomSport.teamScoringTypes.contains(scoringType) }
    var showsSetRules: Bool { scoringType == .sets }

    /// Why the form can't be saved, `nil` if it can. Names must be unique, also against built-in sports.
    func issue(otherNames: [String]) -> String? {
        let name = trimmedName
        if name.isEmpty { return "Enter a name." }
        if name.count > Self.nameLimit { return "Use at most \(Self.nameLimit) characters." }
        let taken = (SportType.phase1Sports.map(\.displayName) + otherNames)
            .contains { $0.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        if taken { return "You already have a sport called \(name)." }
        if showsSetRules {
            if !CustomSport.pointsPerSetRange.contains(pointsPerSet) || !CustomSport.winByRange.contains(winBy) {
                return "Choose the points per set and the lead."
            }
        }
        return nil
    }

    /// Writes the form into `sport`. The scoring type only changes while the sport has no matches.
    func apply(to sport: CustomSport, canChangeScoring: Bool) {
        sport.name = trimmedName
        sport.symbolName = symbolName
        if canChangeScoring { sport.scoringType = scoringType }
        let scoring = sport.scoringType
        sport.allowsDraw = CustomSport.drawScoringTypes.contains(scoring) && allowsDraw
        sport.allowsTeams = CustomSport.teamScoringTypes.contains(scoring) && allowsTeams
        sport.pointsPerSet = scoring == .sets ? pointsPerSet : nil
        sport.winBy = scoring == .sets ? winBy : nil
    }

    func makeSport() -> CustomSport {
        let sport = CustomSport(name: trimmedName)
        apply(to: sport, canChangeScoring: true)
        return sport
    }
}

enum CustomSports {

    /// All matches of a custom sport, any status.
    static func matches(of sport: CustomSport, in matches: [Match]) -> [Match] {
        matches.filter { $0.customSport?.id == sport.id }
    }

    /// "Delete Sport": deletes the sport and all its matches.
    static func delete(_ sport: CustomSport, in context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<Match>())
        for match in matches(of: sport, in: all) { context.delete(match) }
        context.delete(sport)
        try context.save()
    }

    /// "Deletes 3 matches." for the confirmation.
    static func deleteWarning(matchCount: Int) -> String {
        switch matchCount {
        case 0: "This can't be undone."
        case 1: "Deletes 1 match. This can't be undone."
        default: "Deletes \(matchCount) matches. This can't be undone."
        }
    }
}
