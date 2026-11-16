import SwiftUI
import SwiftData

@main
struct RivalrryApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: AppSchema.models)
    }
}

enum AppSchema {
    /// All SwiftData models. Related models would be found automatically,
    /// but listing them keeps the schema explicit.
    static let models: [any PersistentModel.Type] = [
        Player.self, CustomSport.self, Match.self, MatchParticipant.self,
        SetScore.self, PenaltyShot.self, FightDetail.self,
    ]
}
