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
- Phase 1, Phase 2 and Phase 3 are done. 303 tests pass (`PhaseTwoDoneTests` / `PhaseThreeDoneTests`
  check the "Done when" criteria of plan.md §8).
- No paid Apple Developer account yet (the user is getting one). All online features run behind the
  `OnlineBackend` protocol (`Online/OnlineBackend.swift`) on `InMemoryBackend`; there is no CloudKit yet.
  Everything that needs the account (signing, `CloudKitBackend`, push notifications incl. "Remind", S9
  "Notifications", Universal Links, "Delete Account", TestFlight) is **Phase 3b** in plan.md §8. It
  starts only when the user says the account is active.
- Not checked visually in the simulator yet: most Phase 2 and Phase 3 screens (rendered as previews only:
  Elo table, S4 Add Friend, S6 Requests with a friend request). Suggest a quick simulator check to the
  user before or during Phase 4.

## Phase 3: what exists (keep these decisions)
- Files: `Online/` = `OnlineBackend` + `InMemoryBackend`, `ProfileSync`, `OnlineFriends` (friend requests),
  `Invite` (link + QR), `MatchRecord` (online match, `MatchResponse`, `MatchConfirmation`, `PendingChange`,
  `DeletionRequest`), `MatchSync`, `AccountLinking`, `Outbox` (+ `PendingAction` model), `Connectivity`.
  `Logic/Match+Online.swift` = status texts, rights, `MatchRequests` (S6 sections). Views: `Views/AddFriend/`,
  `Views/Requests/`, `Views/FriendDetail/LinkAccountView.swift`, `Views/Profile/UsernameFormView.swift`.
- Tabs: "Rivals", "Requests" (S6, badge), "Profile". "Rankings" (S7) comes in Phase 4.
- Username (3–20, a–z 0–9 _) is chosen in S9; without a username nothing goes online.
- Invite link `rivalrry://invite/<username>` (Universal Links in Phase 3b). S4 = search, own QR code,
  "Share Invite Link", "Scan QR Code" on top, row "Add Local Friend" below. Accepted online friends become
  local `Player`s with `cloudUserID`/`username`.
- Status: a match is online (`Pending`) only if every participant has a `cloudUserID`, otherwise `Local`.
  Only opponents confirm (team partners don't). `Pending`/`Rejected` don't count (`countsTowardRecord`).
  Custom sports travel with the match. Matches with non-friends are not downloaded.
- S6 sections: "To confirm", "Imported matches", "Deletion requests", "Friend requests",
  "Waiting for others". Reject needs a reason. Remind once per 24 h (`remindedAt`).
- Editing a `Confirmed` match = proposed change (`MatchRecord.proposedChange` / `Match.pendingChange`);
  the old result counts until confirmed. Answers are kept per version. "Request deletion": creator or any
  confirming opponent asks, everyone else of them approves, one "Decline" ends it.
- "Link to Account" (plan.md §6.3): merges the online player into the local friend. First to link imports;
  "Who imports?" only if both linked with old matches and nobody imported. Rejected imports go back to
  `Local` (`localOnly = .rejectedImport`, still count for you); copies the friend imported get
  `localOnly = .duplicate` (don't count, nothing deleted). Matches with unlinked players wait.
- Offline: answers, deletions, profile and link changes are queued in the `Outbox`; matches and Remind wait
  via `Match.needsUpload`. Username, search, friend requests and linking need a connection. Offline note
  only in Requests.
- Debug test users in `InMemoryBackend.withTestUsers()`: Max, Tom, Lukas accept your friend requests; Jonas
  sends you one and has logged a Badminton match with you. Max confirms your matches/changes and approves
  deletions, Tom rejects/declines ("It was 21–19, not 21–17"), Lukas never answers.

## Next: Phase 4 ("Groups & Rankings", plan.md §8, S7, S8)
- Start Phase 4 now. Before step 1, clarify with the user (ask, don't guess):
  1. Are groups only on your phone, or shared online with the members (plan.md S8 has "Leave Group",
     which suggests shared)? If shared: through `OnlineBackend` like friends/matches.
  2. Rankings should include "matches between friends without you" (plan.md S7 note). That needs a new
     `OnlineBackend` call (today `fetchMatches()` only returns matches you take part in). OK to add?
  3. Group "emoji" (plan.md §5) → SF Symbol picker like custom sports (decision 4: no emojis)?
  4. plan.md has no "Done when" for Phase 4; propose one and confirm it.
- Step proposal (confirm with the user first): 1 `Group` model + S1 section "Groups" + "New Group" ·
  2 S8 Group Detail (members, rename, "Leave Group", recent matches) · 3 S8 "Add Match" with participants
  only from the group · 4 ranking logic (Elo per player for "All Friends"/group, sport, "Singles"/"Team",
  "Unranked" under 3 matches, 30-day trend) + tests · 5 S7 "Rankings" tab with filters, you highlighted ·
  6 "Best Duos" + "Your Best Partner" · 7 Phase 4 done-when test.
- Reuse `Logic/Elo.swift` (already per sport + mode group, `Elo.table`) and the S9 Elo table views.

## Way of working
- Small steps. After each step: build the project, run the tests, summarize briefly, then STOP and wait
  for an OK.
- All texts in the app in English and exactly as in plan.md. Texts not in plan.md: list them in the
  summary so the user can change them.
- If something is unclear or you want to deviate from the plan: ask first. Write agreed decisions into
  this file (like the Phase 2 and Phase 3 sections above).
- Sample data for previews: design.md §9.4 (Max, Tom, Lukas, Jonas).
- Tests run in the `rivalrry` scheme (the test target depends on the app in `project.xcproj`).
  Use a simulator as run destination (e.g. "iPhone 17 Pro"): on the user's iPhone the test target fails
  signing (it has no development team).
- Done steps: Phase 1: 1 project/tokens/model · 2 result rules + validation · 3 record/duel logic ·
  4 S1 Rivals · 5 S2 header + Overview · 6 S2b Add Match · 7 S2c Stats · 8 S3, S4 · 9 S0, S9 · 10 Head to Head.
  Phase 2: 1 Team mode + "Together" · 2 Races · 3 Elo + "Elo History" · 4 Streaks & Highlights ·
  5 "Score Margin", "Activity", sport tiles · 6 S5 Quick Add · 7 Custom sports · extra: "Elo" in Profile.
  Phase 3: 1 username, profile sync · 2 invite friends + friend requests · 3 match sync, `MatchResponse`,
  status · 4 S6 Requests · 5 "Link to Account" + import · 6 Offline mode (push moved to Phase 3b).

## Commits
- Never commit or push yourself. After each step, give the user a copy-paste command, run from the
  repo root:
  ```sh
  git add <changed files or folders>
  git commit -m 'Phase 4 step N: short title' -m '- what changed
  - what changed'
  ```
- List the changed files/folders explicitly in `git add` (no `git add .`).
- No `Co-Authored-By` or other AI attribution lines.
- Leave out `rivalrry.xcodeproj/project.xcproj` (the user's own signing change) unless the user says otherwise.
