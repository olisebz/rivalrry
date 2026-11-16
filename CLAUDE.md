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

## Way of working
- ONLY Phase 1, in small steps. After each step: build the project, run the tests,
  summarize briefly, then STOP and wait for an OK.
- Steps: 1 project/tokens/model · 2 result rules + validation (sets, points, penalties, fight) + tests ·
  3 record/duel logic + tests · 4 S1 Rivals · 5 S2 header + Overview · 6 S2b Add Match (sheet) ·
  7 S2c Stats · 8 S3 Match Detail, S4 Add Friend · 9 S0 Onboarding, S9 Profile
- All texts in the app in English and exactly as in plan.md.
- If something is unclear or you want to deviate from the plan: ask first.
- Sample data for previews: design.md §9.4 (Max, Tom, Lukas, Jonas).
- Tests run in the `rivalrry` scheme (the test target depends on the app in `project.xcproj`).
