import SwiftUI
import SwiftData

@main
struct RivalrryApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Schema(AppSchema.models))
        } catch {
            fatalError("Could not open the database: \(error)")
        }
        // Placeholder "You" until onboarding (Step 9).
        Player.ensureMe(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
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
