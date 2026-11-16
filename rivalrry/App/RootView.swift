import SwiftUI
import SwiftData

/// Onboarding on first launch, then the tab bar. Phase 1 has only "Rivals" and "Profile" (plan.md §3).
struct RootView: View {
    @AppStorage(SportSettings.onboardedKey) private var isOnboarded = false

    var body: some View {
        if isOnboarded {
            TabView {
                RivalsView()
                    .tabItem { Label("Rivals", systemImage: "person.2") }
                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
            // Active tab and system controls in accent green (design.md §2.2).
            .tint(Color.rvAccent)
        } else {
            OnboardingView()
        }
    }
}

#Preview("With data") {
    RootView()
        .modelContainer(SampleData.container())
        .defaultAppStorage(onboardedDefaults)
}

#Preview("Empty") {
    RootView()
        .modelContainer(SampleData.container(filled: false))
        .defaultAppStorage(onboardedDefaults)
}

#if DEBUG
/// Previews skip onboarding.
private let onboardedDefaults: UserDefaults = {
    let defaults = UserDefaults(suiteName: "preview.onboarded")!
    defaults.set(true, forKey: SportSettings.onboardedKey)
    return defaults
}()
#endif
