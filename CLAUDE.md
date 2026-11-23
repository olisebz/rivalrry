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
  10. Decisions made during Phase 2 (agreed with the user, keep them):
      - Elo: Stats mode filter "All" shows the Singles Elo. The Period filter only limits the "Elo History"
        chart; the Elo shown is always the current rating. Team K = average K of the team members.
        "Elo" is the first row in "Head to Head". S3 shows the Elo change per player.
      - Profile (S9) has an "Elo" section: table per sport + mode (Elo, matches, change in 30 days, highest
        first); tapping a row opens a page with the "Elo History" chart and the match history. Not in plan.md.
      - Streaks: a draw ends a streak. Stats tiles = Matches, Win rate, Current streak, Longest streak (2x2).
        "Highlights" = only "Closest win" / "Biggest win", only when one sport with a score margin is selected.
      - "Score Margin": sets = point difference over all sets; only when one sport is selected.
        "Activity": follows the Period filter, "All" = last 12 months. Running chart: distance chips.
      - Sport tiles: no duplicate tiles; missing values are extra "Head to Head" rows ("Avg. rounds").
      - Quick Add: "+" floating bottom right on S1; sport and opponent on one screen; sport preselected,
        opponent not.
      - Custom sports: every custom sport counts on its own (type `Sport` in `Sports/Sport.swift`:
        built-in by `SportType` or custom by ID; use `match.sport`, not `match.sportType`, for grouping).
        Created in S9 and via a "New Sport" tile in the grid. Teams 2–11. Scoring is locked once there are
        matches; deleting a sport deletes its matches.

## Where we stand
- Phase 1 and Phase 2 are done (incl. the extra "Elo" section in Profile). 214 tests pass
  (`PhaseTwoDoneTests` checks the Phase 2 "Done when" criterion).
- Everything is still local (SwiftData, status `.local`). No CloudKit yet.
- Not checked visually in the simulator yet: most Phase 2 screens (only the Elo table preview was rendered).

## Way of working
- Now: Phase 3 ("Online with Friends", plan.md §8), in small steps. After each step: build the project,
  run the tests, summarize briefly, then STOP and wait for an OK.
- No paid Apple Developer account yet (user is getting one). Until then: build everything behind the
  `OnlineBackend` protocol (`Online/OnlineBackend.swift`) with `InMemoryBackend`. Everything that needs the
  account (signing, CloudKit backend, push, S9 "Notifications", Universal Links, "Delete Account",
  TestFlight) is Phase 3b in plan.md §8; it starts when the account is active.
- Phase 3 steps done: 1 username + profile sync (backend-agnostic) · 2 invite friends + friend requests ·
  3 match sync, `MatchResponse`, status · 4 S6 Requests (confirm, reject, remind, deletion, changes)
- Phase 3 decisions (agreed with the user): invite link = `rivalrry://invite/<username>` until there is a
  domain for Universal Links. "Requests" tab (S6) exists since step 2 with only "Friend requests"; step 4
  adds the rest. S4 = online part on top (search, QR, "Share Invite Link", "Scan QR Code"), row
  "Add Local Friend" below. Debug builds seed `InMemoryBackend` with Max/Tom/Lukas/Jonas (Jonas sends
  you a request; the others accept yours automatically).
- Step 3 decisions: a match is online (`Pending`) only if every participant has a `cloudUserID`; otherwise
  `Local`. Only opponents confirm (team partners don't). Custom sports travel with the match and are added
  on the other device. Matches with people who aren't your friends are not downloaded. Test users: Max
  confirms, Tom rejects ("It was 21–19, not 21–17"), Lukas never answers, Jonas logged a Badminton match.
- Step 4 decisions: editing a `Confirmed` match stores a proposed change next to it (`MatchRecord.proposedChange`,
  local `Match.pendingChange`); the old result counts until all opponents confirm the change, then the
  creator's sync merges it. Answers are kept per version. "Request deletion": the creator or any confirming
  opponent can ask, everyone else of them must approve, one "Decline" ends it. "Remind" works now (once per
  24 h, stored as `remindedAt`); Phase 3b turns it into a push. Badge = friend requests + "To confirm" +
  "Deletion requests". Test users: Max also confirms changes and approves deletions, Tom rejects/declines.
- Phase 1 steps (done): 1 project/tokens/model · 2 result rules + validation · 3 record/duel logic ·
  4 S1 Rivals · 5 S2 header + Overview · 6 S2b Add Match · 7 S2c Stats · 8 S3, S4 · 9 S0, S9 · 10 Head to Head
- Phase 2 steps (done): 1 Team mode + "Together" · 2 Races (Go-Kart, Running 3+) · 3 Elo + "Elo History" ·
  4 Streaks & Highlights · 5 "Score Margin", "Activity", sport tiles · 6 S5 Quick Add ("+" button) ·
  7 Custom sports · extra: "Elo" section in Profile
- Phase 3 steps: 1 username, profile sync · 2 Invite friends (link, QR code, search) + friend requests ·
  3 Match sync, `MatchResponse`, status `Pending`/`Confirmed`/`Rejected` · 4 S6 Requests (confirm, reject
  with reason, remind, deletion requests) + "Requests" tab · 5 "Link to Account" + import of old
  matches (plan.md §6.3) · 6 Offline mode. Push notifications moved to Phase 3b (agreed with the user).
- All texts in the app in English and exactly as in plan.md.
- If something is unclear or you want to deviate from the plan: ask first.
- Sample data for previews: design.md §9.4 (Max, Tom, Lukas, Jonas).
- Tests run in the `rivalrry` scheme (the test target depends on the app in `project.xcproj`).
  Use a simulator as run destination (e.g. "iPhone 17 Pro"): on the user's iPhone the test target fails
  signing (it has no development team).

## Commits
- Never commit or push yourself. After each step, give the user a copy-paste command, run from the
  repo root:
  ```sh
  git add <changed files or folders>
  git commit -m 'Phase 3 step N: short title' -m '- what changed
  - what changed'
  ```
- No `Co-Authored-By` or other AI attribution lines.
- Leave out `rivalrry.xcodeproj/project.xcproj` (the user's own signing change) unless the user says otherwise.
