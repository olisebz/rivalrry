import Testing
@testable import rivalrry

/// Checks the SportType configuration against plan.md §2.1 and §2.2.
struct SportTypeTests {

    @Test func displayNamesMatchPlan() {
        #expect(SportType.pingPong.displayName == "Ping Pong")
        #expect(SportType.football.displayName == "Football")
        #expect(SportType.penaltyShootout.displayName == "Penalty Shootout")
        #expect(SportType.goKart.displayName == "Go-Kart")
    }

    @Test func formatsPerSport() {
        #expect(SportType.badminton.bestOfOptions == [1, 3])
        #expect(SportType.badminton.defaultBestOf == 3)
        #expect(SportType.pingPong.bestOfOptions == [1, 3, 5])
        #expect(SportType.pingPong.defaultBestOf == 5)
        #expect(SportType.tennis.bestOfOptions == [1, 3, 5])
        #expect(SportType.tennis.defaultBestOf == 3)
        #expect(SportType.padel.bestOfOptions == [1, 3])
        #expect(SportType.padel.defaultBestOf == 3)
    }

    @Test(arguments: SportType.allCases)
    func defaultFormatIsSelectable(sport: SportType) {
        if let bestOf = sport.defaultBestOf {
            #expect(sport.bestOfOptions.contains(bestOf))
            #expect(sport.scoringType == .sets)
        } else {
            #expect(sport.bestOfOptions.isEmpty)
        }
    }

    @Test(arguments: SportType.allCases)
    func setRulesOnlyForSetSports(sport: SportType) {
        #expect((sport.setRules != nil) == (sport.scoringType == .sets))
    }

    @Test func setRules() {
        #expect(SportType.badminton.setRules == SetRules(pointsToWin: 21, winBy: 2, maxPoints: 30, tiebreak: nil))
        #expect(SportType.pingPong.setRules == SetRules(pointsToWin: 11, winBy: 2, maxPoints: nil, tiebreak: nil))
        #expect(SportType.tennis.setRules?.tiebreak == TiebreakRules(pointsToWin: 7, winBy: 2))
        #expect(SportType.padel.setRules == SportType.tennis.setRules)
    }

    @Test func scoringTypes() {
        #expect(SportType.football.scoringType == .points)
        #expect(SportType.basketball.scoringType == .points)
        #expect(SportType.penaltyShootout.scoringType == .penalties)
        #expect(SportType.boxing.scoringType == .fight)
        #expect(SportType.goKart.scoringType == .placement)
        #expect(SportType.running.scoringType == .time)
    }

    @Test func modesAndDraws() {
        #expect(SportType.boxing.allowedModes == [.oneVsOne])
        #expect(SportType.goKart.allowedModes == [.race])
        #expect(SportType.running.allowedModes == [.oneVsOne, .race])
        #expect(SportType.badminton.allowedModes == [.oneVsOne, .team])

        let drawSports = SportType.allCases.filter(\.allowsDraw)
        #expect(Set(drawSports) == [.football, .boxing, .running])
    }

    @Test(arguments: SportType.allCases)
    func symbolIsNotEmpty(sport: SportType) {
        #expect(!sport.symbolName.isEmpty)
    }
}
