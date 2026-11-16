import SwiftUI
import SwiftData

/// Tab bar. Phase 1 has only "Rivals" and "Profile" (plan.md §3).
struct RootView: View {
    var body: some View {
        TabView {
            RivalsView()
                .tabItem { Label("Rivals", systemImage: "person.2") }

            // Placeholder until S9 Profile (Step 9).
            NavigationStack {
                Color.rvBackground
                    .navigationTitle("Profile")
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        // Active tab and system controls in accent green (design.md §2.2).
        .tint(Color.rvAccent)
    }
}

#Preview("With data") {
    RootView()
        .modelContainer(SampleData.container())
}

#Preview("Empty") {
    RootView()
        .modelContainer(SampleData.container(filled: false))
}
