# RIVALRRY

iOS app (SwiftUI, SwiftData, iOS 17). Sources:
- `docs/plan.md` → features, rules, data model, phases
- `docs/design.md` → colors, typography, spacing, components (§11 = ready-made SwiftUI code)
- `docs/mockups/` → screenshots of the finished screens (light + dark)

## What applies in case of conflicts
- Logic, rules, data model → plan.md
- Appearance → design.md and the screenshots
- These decisions apply even if plan.md says otherwise:
  1. "Add Match" is NOT a tab. It is an "Add Match" button in S2 that opens a sheet.
     The segmented control in S2 only has "Overview" and "Stats".
  2. The per-sport rows are only in Stats ("By Sport"), not in Overview.
     Overview = header + "Recent Matches" + "Add Match" button.
  3. The sport picker is a simple 3-column grid, without "Recent" and without categories.
  4. No emojis in the app. Instead of emojis: initials in the avatar and SF Symbols (see design.md §5).
  5. Red only for deleting. Friend leads = normal text color, tie = grey.
  6. Phase 1 has only 2 tabs: "Rivals" and "Profile".
  7. Formats per sport exactly as in plan.md 2.2 (Badminton only Best of 1/3, Ping Pong default Best of 5).
  8. Stats has a "Head to Head" card per sport (plan.md S2c, design.md §6.12): who won more, sets/points/goals
     combined and sport-specific comparisons. This is Phase 1, pulled forward from the Phase 2 sport tiles.
  9. Phase 2 keeps decision 2: Overview stays header + "Recent Matches" + "Add Match". Elo goes into
     "By Sport" and "Head to Head"; "Highlights" and "Together" are sections in Stats.

## Way of working
- Phase 1 is done. Now: ONLY Phase 2, in small steps. After each step: build the project, run the tests,
  summarize briefly, then STOP and wait for an OK.
- Phase 1 steps (done): 1 project/tokens/model · 2 result rules + validation · 3 record/duel logic ·
  4 S1 Rivals · 5 S2 header + Overview · 6 S2b Add Match · 7 S2c Stats · 8 S3, S4 · 9 S0, S9 · 10 Head to Head
- Phase 2 steps: 1 Team mode + "Together" · 2 Races (Go-Kart, Running 3+) · 3 Elo + "Elo History" ·
  4 Streaks & Highlights · 5 "Score Margin", "Activity", sport tiles · 6 S5 Quick Add ("+" button) ·
  7 Custom sports
- All texts in the app in English and exactly as in plan.md.
- If something is unclear or you want to deviate from the plan: ask first.
- Sample data for previews: design.md §9.4 (Max, Tom, Lukas, Jonas).
- Tests run in the `rivalrry` scheme (the test target depends on the app in `project.xcproj`).
