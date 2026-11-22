import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// S0 / S9 logic: sport settings, own stats and "Reset All Data".
struct ProfileAndSettingsTests {

    private func freshDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func encodeDecode() {
        #expect(SportSettings.encode([.badminton, .pingPong]) == "badminton,pingPong")
        #expect(SportSettings.decode("badminton,pingPong") == [.badminton, .pingPong])
        #expect(SportSettings.decode("") == [])
        #expect(SportSettings.decode("badminton,unknown") == [.badminton])
    }

    @Test func entrySportsFavoritesFirstHiddenRemoved() {
        let sports = SportSettings.entrySports(favorites: [.pingPong, .boxing], hidden: [.tennis, .boxing])
        #expect(sports.first == .pingPong)
        #expect(!sports.contains(.tennis))
        #expect(!sports.contains(.boxing))
        #expect(sports.count == SportType.phase1Sports.count - 2)
        #expect(SportSettings.entrySports(favorites: [], hidden: []) == Sport.builtInSports)
    }

    @Test func defaultFormatSetting() {
        let defaults = freshDefaults()
        #expect(SportSettings.defaultBestOf(for: .pingPong, defaults: defaults) == 5)
        defaults.set(3, forKey: SportSettings.formatKey(.pingPong))
        #expect(SportSettings.defaultBestOf(for: .pingPong, defaults: defaults) == 3)
        // Not allowed for Badminton (decision 7): falls back to the plan's default.
        defaults.set(5, forKey: SportSettings.formatKey(.badminton))
        #expect(SportSettings.defaultBestOf(for: .badminton, defaults: defaults) == 3)
        #expect(SportSettings.defaultBestOf(for: .football, defaults: defaults) == nil)

        #expect(MatchDraft(sport: .pingPong, bestOf: 3).bestOf == 3)
        #expect(MatchDraft(sport: .badminton, bestOf: 5).bestOf == 3)
    }

    @Test func resetSettings() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: SportSettings.onboardedKey)
        defaults.set("badminton", forKey: SportSettings.favoritesKey)
        defaults.set(3, forKey: SportSettings.formatKey(.pingPong))
        defaults.set("all", forKey: "stats.123.mode")
        defaults.set("keep", forKey: "other")
        SportSettings.reset(defaults: defaults)
        #expect(!defaults.bool(forKey: SportSettings.onboardedKey))
        #expect(defaults.string(forKey: SportSettings.favoritesKey) == nil)
        #expect(defaults.object(forKey: SportSettings.formatKey(.pingPong)) == nil)
        #expect(defaults.string(forKey: "stats.123.mode") == nil)
        #expect(defaults.string(forKey: "other") == "keep")
    }

    @Test func profileStats() throws {
        let f = try Fixture()
        f.add(.badminton, wins: 3, losses: 1, vs: f.max)
        f.add(.pingPong, wins: 1, losses: 1, vs: f.tom)
        f.add(.badminton, .win, vs: [f.lukas])
        f.add(.badminton, .win, vs: [f.max], status: .pending)        // doesn't count
        f.add(.padel, .win, vs: [f.tom, f.lukas], partners: [f.max])  // team: not in the record

        let stats = Rivalry.profileStats(of: f.me, in: f.matches)
        #expect(stats.record == Record(wins: 5, losses: 2))
        #expect(stats.favoriteSport == .badminton)
        #expect(stats.biggestRival?.id == f.max.id)
    }

    @Test func profileStatsWithoutMatches() throws {
        let f = try Fixture()
        let stats = Rivalry.profileStats(of: f.me, in: [])
        #expect(stats.record == Record())
        #expect(stats.favoriteSport == nil)
        #expect(stats.biggestRival == nil)
    }

    @Test func resetAllData() throws {
        let f = try Fixture()
        f.add(.badminton, wins: 2, losses: 1, vs: f.max)
        f.add(.penaltyShootout, .win, vs: [f.tom])
        f.add(.boxing, .win, vs: [f.tom])
        try f.context.save()

        try Rivalry.resetAllData(in: f.context)
        #expect(try f.context.fetchCount(FetchDescriptor<Match>()) == 0)
        #expect(try f.context.fetchCount(FetchDescriptor<Player>()) == 0)
        #expect(try f.context.fetchCount(FetchDescriptor<SetScore>()) == 0)
        #expect(try f.context.fetchCount(FetchDescriptor<PenaltyShot>()) == 0)
        #expect(try f.context.fetchCount(FetchDescriptor<FightDetail>()) == 0)
        #expect(try f.context.fetchCount(FetchDescriptor<MatchParticipant>()) == 0)

        // Afterwards onboarding creates "me" again.
        let me = Player.ensureMe(in: f.context)
        #expect(me.isMe)
    }
}
