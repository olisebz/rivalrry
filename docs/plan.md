# 🏆 RIVALRRY – Sports Tracker for Friends

**Goal:** An iOS app (SwiftUI, Xcode) where you log games against friends in different sports and use statistics to see who is better at what.

> This document and the app are in English. All texts in `"quotes"` are the exact texts shown in the app.

---

## 0. Decisions Made

| Topic | Decision |
|---|---|
| App name | **RIVALRRY** |
| App language | English |
| Platform | iPhone, **iOS 17** and later (required for SwiftData), light & dark mode |
| Start | Phases 1–2 run **only locally** on your phone, you enter everything yourself |
| Later | From Phase 3 all friends have the app, sync via **CloudKit** (everyone has an iPhone) |
| Confirmation | **Required, no automation**: A match only counts once *all* opponents have confirmed it. Unconfirmed matches never count. |
| Old local matches | Are carried over when linking to the real account; the friend confirms them once, in bulk |
| Singles vs. team | **Separate.** The record against a friend counts only direct duels by default (1v1 + races). Team matches are visible via the filter. |
| Rating | **Elo** is shown (in addition to the record) |

---

## 1. Terms

| Term | Meaning |
|---|---|
| **Match** | A logged game/race/fight |
| **Duel** | A direct comparison between exactly 2 players. A 1v1 match = 1 duel. A race with 4 players = 6 duels (everyone against everyone). |
| **Record** | Wins : losses (: draws) from all duels against one person |
| **Mode** | `1v1` (singles), `Team` (doubles / 2v2 / 3v3 / 5v5), `Race` (2–12 players with placement) |
| **Elo** | Rating per sport and mode. Starts at 1000. Higher = better. |
| **Status** | `Local` (Phases 1–2), `Pending` (waiting for confirmation), `Confirmed`, `Rejected` |

---

## 2. Sports & Rules

### 2.1 Overview

| Sport | App name | Category | Scoring type | Modes | Draw? |
|---|---|---|---|---|---|
| 🏸 Badminton | "Badminton" | Racket | `sets` | 1v1, Team (2v2) | No |
| 🎾 Padel | "Padel" | Racket | `sets` | 1v1, Team (2v2) | No |
| 🎾 Tennis | "Tennis" | Racket | `sets` | 1v1, Team (2v2) | No |
| 🏓 Table tennis | "Ping Pong" | Racket | `sets` | 1v1, Team (2v2) | No |
| ⚽ Football | "Football" | Ball | `points` | 1v1, Team (any size) | Yes |
| 🏀 Basketball | "Basketball" | Ball | `points` | 1v1, Team (2v2–5v5) | No |
| 🥅 Penalty shootout | "Penalty Shootout" | Ball | `penalties` | 1v1, Team (any size) | No |
| 🥊 Boxing | "Boxing" | Combat | `fight` | 1v1 only | Yes (only on points) |
| 🏎️ Go-kart | "Go-Kart" | Race | `placement` | Race only | No |
| 🏃 Running race | "Running" | Race | `time` | 1v1, Race | Yes (exactly the same time) |
| ➕ Custom sport | (free) | Custom | selectable | selectable | selectable |

### 2.2 Rules per Scoring Type

The app checks every result. If it is invalid, `"Save"` is greyed out and a short message explains why.

**`sets` – set-based sports**

| Sport | Format (selectable) | Default | Set is won when … |
|---|---|---|---|
| Badminton | Best of 1 / 3 | Best of 3 | 21 points with a 2-point lead; at 29:29 the 30th point wins (max. 30:29) |
| Ping Pong | Best of 1 / 3 / 5 | Best of 5 | 11 points with a 2-point lead (e.g. 11:9, 14:12) |
| Tennis | Best of 1 / 3 / 5 | Best of 3 | 6 games with a 2-game lead (6:4, 7:5) or 7:6 via tiebreak |
| Padel | Best of 1 / 3 | Best of 3 | same as Tennis |

- At 7:6 the tiebreak score must be entered (at least 7 points, 2-point lead, e.g. 7:5, 10:8).
- The match is over as soon as one side has the required sets (Best of 3 → 2 sets). No further sets can be added after that.
- **Retirement:** Toggle `"Match not finished"` + choose who gave up. Counts as a win for the other side.

**`points` – Football, Basketball**
- Two numbers ≥ 0.
- Football: a tie = draw.
- Basketball: a tie is not allowed (message: `"Basketball can't end in a tie"`).

**`penalties` – Penalty shootout**
- Number of shots per side selectable: 3 / 5 / 10, default 5.
- For each shot, tap ✅ goal or ❌ miss, alternating A, B, A, B …
- If it's tied after all shots → automatic `"Sudden Death"`: rounds are added in pairs until one side scores and the other doesn't.
- Early end: if one side can no longer catch up, the match is over automatically.

**`fight` – Boxing**
- Choose the winner or `"Draw"`.
- Method of victory: `"KO"`, `"TKO"`, `"Points"`, `"Retirement"` (gave up).
- Total number of rounds (default 3) and the round it ended (for KO/TKO/Retirement).
- `"Draw"` is only possible together with `"Points"`.
- Optional: score card per round (10:9 system).

**`placement` – Go-kart**
- 2–12 participants.
- Drag & drop participants into finishing order. Each place appears exactly once.
- Optional per participant: fastest lap (mm:ss.SSS) and `"DNF"` (did not finish → automatically last place).

**`time` – Running race**
- Choose distance: 60 m, 100 m, 200 m, 400 m, 1 km, 5 km, 10 km or a custom distance in meters.
- Time per participant (h:mm:ss.SS). Placement is calculated automatically (fastest time = 1st place).
- Exactly the same time = same placement = draw in that duel.
- Optional `"DNF"`.
- With 2 participants the mode is called `1v1`, with 3 or more `Race`.

**Custom sport (from Phase 2)**
- Name, emoji, scoring type: `"Win / Loss"`, `"Points"`, `"Sets"` (then custom points per set + lead), `"Placement"` or `"Time"`.
- Configurable: draws allowed, team mode allowed.

### 2.3 How Matches Count Toward the Record

| Mode | Record against friend X |
|---|---|
| `1v1` | Win/loss/draw against X |
| `Race` | Duel: whoever finishes ahead of X has won against X. Same placement = draw. Both DNF = draw. |
| `Team` | Does **not** count toward the default record. Visible with the filter `"Team"` or `"All"`: a win against each opponent on the other team. If X was your **partner**, it appears in X's section under `"Together"`. |

**Example go-kart:** You finish 2nd, Max 1st, Tom 3rd, Lukas 4th → vs. Max: loss. vs. Tom: win. vs. Lukas: win.

### 2.4 Elo Calculation

- Each player has **one Elo per sport and mode group**: `Singles` (1v1 + Race) and `Team`. Start: **1000**.
- Formula: expectation `E = 1 / (1 + 10^((Elo_opponent − Elo_me) / 400))`, new Elo = `Elo + K × (result − E)`, with result 1 = win, 0.5 = draw, 0 = loss.
- **K = 40** for the first 10 matches in a sport (quick settling), after that **K = 24**.
- **Team:** team Elo = average of the players. Every player on the team gets the same change.
- **Race:** each duel is calculated separately with `K / (participants − 1)`, the changes are added up.
- Elo is **not stored**, but always calculated from all counting matches in chronological order (and cached). That way everything stays correct automatically when a match is edited or deleted.
- An Elo is only shown from **3 matches** on, before that it says `"Unranked"`.
- **Note Phases 1–2:** Since only you enter matches, your friends' Elo is based only on games against or with you.

---

## 3. Navigation

```
First launch → Onboarding (S0)

Tab bar:
├── "Rivals"     (S1)  Home: friends & groups
│     ├── Friend Detail (S2) with 3 tabs:
│     │     ├── "Overview"   (S2a)
│     │     ├── "Add Match"  (S2b)
│     │     └── "Stats"      (S2c)
│     ├── Add Friend (S4)
│     └── Group Detail (S8)          from Phase 4
├── "Requests"   (S6)                from Phase 3
├── "Rankings"   (S7)                from Phase 4
└── "Profile"    (S9)

Reachable everywhere:
├── "+" button → Quick Add (S5)     from Phase 2
└── Match Detail (S3)                by tapping a match
```

**Phase 1** has only 2 tabs: `"Rivals"` and `"Profile"`. The other tabs appear once their phase is done.

---

## 4. Screens in Detail

Each screen is described like this: **Purpose → Contents → Actions → Empty state → Rules.**

---

### S0 – Onboarding · from Phase 1

**Purpose:** Create your own profile on first launch.

**Flow (3 steps):**
1. Welcome: `"Settle it once and for all."` + button `"Get Started"`
2. Own profile: name (required, 1–20 characters), emoji or photo, favorite color
3. Pick favorite sports (at least 1). These appear at the top when logging later.

**Rules:** Shown only once. Everything can be changed later in the profile (S9).

---

### S1 – Rivals (Home) · from Phase 1

**Purpose:** See at a glance where you stand against whom.

**Contents:**
- Title `"Rivals"`
- One **card** per friend with:
  - Emoji/photo + name
  - Record (default record, see 2.3), e.g. `"12 – 9"` from your point of view
  - Color of the record: **green** = you lead, **red** = they lead, **grey** = tied
  - Line below: `"Last match: Badminton · 2 days ago"`
  - Streak, if ≥ 3: `"🔥 4 wins in a row"` or `"🥶 3 losses in a row"` *(from Phase 2)*
  - Small ⏳ icon if matches are waiting for confirmation *(from Phase 3)*
- Section `"Groups"` below the friends *(from Phase 4)*
- Sort menu top right: `"Recently played"` (default), `"Name"`, `"Most matches"`

**Actions:**
- Tap card → **S2 Friend Detail**
- Button top right `"Add Friend"` (person icon with +) → **S4**
- Swipe left → `"Archive"` (friend is hidden, data stays). Archived friends at the bottom under `"Archived"`, can be restored there.

**Empty state:** Illustration + `"No rivals yet. Add a friend to start keeping score."` + button `"Add Friend"`.

---

### S2 – Friend Detail · from Phase 1

**Header (always visible above all 3 tabs):**
- Left: you (emoji + name), right: the friend
- Large in the middle: the record `"12 – 9"` (default record, all sports)
- Below it a bar showing who leads (share of wins)
- Menu `"…"` top right: `"Edit Friend"`, `"Archive"`, `"Delete Friend"` (with warning; deletes only matches no other friends took part in; other matches keep them as `"Deleted Player"`)

Below that a segmented control with 3 tabs: `"Overview"` · `"Add Match"` · `"Stats"`.

---

### S2a – Tab "Overview" · from Phase 1

**Purpose:** The rivalry with this person, summarized.

**Contents (top to bottom):**
1. **One row per sport** (only sports played, sorted by number of matches):
   - `"🏸 Badminton   5 – 3   Elo 1240 vs 1180"`
   - For races, additionally instead of Elo: `"Avg. place 1.8 vs 2.6"`
   - Elo only from Phase 2
2. **Highlights** *(from Phase 2)*, horizontally scrolling tiles:
   - `"Current streak"`, `"Longest streak"`, `"Closest win"`, `"Biggest win"`
3. **`"Recent Matches"`**: the last 5 matches (sport emoji, result, date, status icon). Below it `"See all"` → full list of all matches with this friend (filterable by sport).
4. **`"Together"`** *(from Phase 2)*: record when you played on the same team, e.g. `"As partners: 6 – 2"`.

**Actions:**
- Tap sport row → tab **Stats**, pre-filtered to that sport
- Tap match → **S3 Match Detail**

**Empty state:** `"No matches yet. Who's first?"` + button `"Add Match"` (switches to the Add Match tab).

---

### S2b – Tab "Add Match" · from Phase 1

**Purpose:** Log a match quickly and unambiguously. Goal: under 15 seconds.

**Step 1 – Sport:** Grid with large tiles (emoji + name). At the top `"Recent"` (the 4 most recently used), below by category: `"Racket"`, `"Ball"`, `"Combat"`, `"Race"`, `"Custom"`.

**Step 2 – Mode & participants:**
- Only show modes the sport allows (see 2.1). If there is only one, the step is skipped.
- `1v1`: you vs. this friend, already filled in.
- `Team` *(from Phase 2)*: two columns `"Team A"` / `"Team B"`. You and the friend are already entered (as opponents); add more players from the friends list. A player can't be on both teams. Both teams must be the same size.
- `Race` *(from Phase 2)*: you + friend are set, add more participants (max. 12).

**Step 3 – Result:** Input depending on scoring type (rules see 2.2):
- `sets`: choose format (`"Best of 3"` …), then two number fields per set with +/– stepper. Button `"Add Set"`. At 7:6 the tiebreak field appears.
- `points`: two large counters with +/–, number can also be typed directly.
- `penalties`: grid with circles per shot, tapping toggles ✅/❌.
- `fight`: tap the winner, method of victory as segmented control, round picker.
- `placement`: list sorted via drag & drop, place numbers on the left.
- `time`: distance picker, then a time field per participant.

**Step 4 – Optional (collapsed under `"More details"`):**
- Date & time (default: now, no future allowed)
- Note (max. 200 characters)
- Location and photo *(from Phase 5)*

**Saving:**
- At the top a **live preview**: `"You win 2–1"` / `"Max wins"` / `"Draw"`.
- Button `"Save Match"`, greyed out while the result is invalid.
- Afterwards: short confirmation (haptics + `"Match saved"`), switch to Overview.
- Phases 1–2: status `Local`, counts immediately.
- From Phase 3: status `Pending`, all opponents get a push notification.

**Cancel:** If something has already been entered, the app asks `"Discard match?"`.

---

### S2c – Tab "Stats" · from Phase 1

**Purpose:** Use charts to show who is really better.

**Filters (at the top, saved per friend):**
- `"Sport"`: `"All"` + every sport played
- `"Period"`: `"1M"`, `"3M"`, `"1Y"`, `"All"` (default: `"All"`)
- `"Mode"`: `"1v1 & Race"` (default), `"Team"`, `"All"`

**Key figure tiles (at the top):**
`"Matches"` · `"Win rate"` (in %) · `"Current streak"` · `"Longest streak"` *(streaks from Phase 2)*

**Charts (Swift Charts):**

| Chart | Type | Shows | Visible when | Phase |
|---|---|---|---|---|
| `"Wins by Sport"` | Grouped bars | Your vs. their wins per sport | Sport = All | 1 |
| `"Record over Time"` | 2 lines | Cumulative wins of both players over time | always | 1 |
| `"Win Rate"` | Donut | Share of wins / losses / draws | always | 1 |
| `"Elo History"` | 2 lines | Elo history of both players | one sport selected | 2 |
| `"Score Margin"` | Bar per match | Point/set/goal margin of each match (above 0 = you win) | `sets`/`points`/`penalties` | 2 |
| `"Activity"` | Calendar heatmap | Days you played | always | 2 |

**`"Head to Head"`** (only when exactly one sport is selected, from Phase 1):
Shows who is better in this sport. At the top the record for this sport (e.g. `"5 – 3"`) with the win share bar, below it one row per stat: your value left, label in the middle, the friend's value right. The better value is green if it's yours, normal text color if it's the friend's, grey if tied. All S2c filters (period, mode) apply. Tapping a row in `"By Sport"` selects that sport.

| Sport | Rows |
|---|---|
| Badminton, Ping Pong | `"Wins"`, `"Sets won"`, `"Points won"`, `"Avg. points per set"`, `"Set win rate"`, `"Deuce sets won"` (sets that went past 21 or 11) |
| Tennis, Padel | `"Wins"`, `"Sets won"`, `"Games won"`, `"Avg. games per set"`, `"Set win rate"`, `"Tiebreaks won"` |
| Football | `"Wins"`, `"Draws"`, `"Goals"`, `"Avg. goals per match"`, `"Biggest win"` |
| Basketball | `"Wins"`, `"Points"`, `"Avg. points per match"`, `"Biggest win"` |
| Penalty Shootout | `"Wins"`, `"Goals"`, `"Conversion rate"`, `"Sudden death wins"` |
| Boxing | `"Wins"`, `"Wins by KO/TKO"`, `"Wins by points"`, `"Draws"` |
| Running | `"Wins"`, `"Draws"`, `"Best 100 m"` etc. (best time per distance, lower is better) |

**More sport-specific tiles** (only when exactly this sport is selected, from Phase 2):

| Sport | Tiles |
|---|---|
| Tennis, Padel | `"Tiebreaks won"`, `"Set win rate"` |
| Badminton, Ping Pong | `"Avg. points per set"`, `"Deuce sets won"` (sets that went into extra points) |
| Football, Basketball | `"Avg. score"`, `"Biggest win"` |
| Penalty Shootout | `"Conversion rate"` (scoring rate), `"Sudden death record"` |
| Boxing | `"Wins by KO/TKO"`, `"Wins by points"`, `"Avg. rounds"` |
| Go-Kart | `"Avg. place"`, `"Podiums"`, `"Best lap"` |
| Running | `"Personal best"` per distance + line chart of times (best times marked) |

**Empty state:** `"Play a few matches to see stats."` (visible from the 1st match; Elo only from 3 matches).

---

### S3 – Match Detail · from Phase 1

**Purpose:** View and manage a single match.

**Contents:**
- Sport, mode, date
- Participants/teams and the complete result (all sets incl. tiebreak, every penalty, race list with times, etc.)
- Winner highlighted
- Elo change per player, e.g. `"+14"` / `"−14"` *(from Phase 2)*
- Note, location, photo (if present)
- Status banner *(from Phase 3)*: `"Waiting for Max to confirm"`, `"Confirmed"`, `"Rejected by Max: It was 21–19"`

**Actions:**

| Action | Phases 1–2 | From Phase 3 |
|---|---|---|
| `"Edit"` | any time | Creator: while `Pending` or `Rejected`. When `Confirmed`: the change becomes a new request, the old result keeps counting until confirmed. |
| `"Delete"` | any time (with confirmation) | `Pending`/`Rejected`: creator any time. `Confirmed`: only if all opponents agree (`"Request deletion"`). |
| `"Remind"` | – | Creator can send a reminder once every 24 h while `Pending` |

---

### S4 – Add Friend · from Phase 1

**Phases 1–2 (local):**
- Name (required, 1–20 characters, must be unique), emoji or photo, color
- Button `"Add"`

**From Phase 3 (online):**
- Own QR code + `"Share Invite Link"` (iOS share sheet)
- `"Scan QR Code"`
- Search by username
- The friend must accept the request in **S6**.
- **Link a local friend:** A local friend's menu has `"Link to Account"` → see section 6.3.

---

### S5 – Quick Add ("+" button) · from Phase 2

**Purpose:** Log right after the game without opening the friend first.

**Flow:** Floating `"+"` button bottom right on S1 → sheet opens:
1. Sport (the most recently played one is preselected)
2. Opponent (most recent opponents first)
3. Continue as in S2b steps 2–4

---

### S6 – Requests · from Phase 3

**Purpose:** Manage open confirmations. Badge number on the tab = number of things *you* need to handle.

**Sections:**
1. **`"To confirm"`**: matches others logged with you. Each entry has a result preview and buttons:
   - `"Confirm"` ✅ → counts (once all opponents have confirmed)
   - `"Reject"` ❌ → required field reason (e.g. `"It was 21–19, not 21–17"`). The creator can then edit and resend the match, or delete it.
2. **`"Imported matches"`**: bulk request for old local matches (see 6.3): `"Alex imported 12 matches with you"` → `"Confirm All"` or `"Review"` (go through one by one).
3. **`"Deletion requests"`**: `"Approve"` / `"Decline"`.
4. **`"Friend requests"`**: `"Accept"` / `"Decline"`.
5. **`"Waiting for others"`**: your matches still waiting for confirmation (with `"Remind"`).

**Rule:** No automation. Unconfirmed matches stay `Pending` until someone responds, and don't count until then.

**Empty state:** `"All caught up."`

---

### S7 – Rankings · from Phase 4

**Purpose:** Who is the best among friends or in a group?

**Filters:** `"All Friends"` or a group · sport · `"Singles"` / `"Team"`

**Contents:**
- Ranking by Elo: place, name, Elo, record, trend arrow ↑↓ (change over the last 30 days). You are highlighted.
- Players with `"Unranked"` (fewer than 3 matches) are at the bottom, greyed out.
- `"Best Duos"` (for team sports): partnerships with at least 3 matches together, sorted by win rate.
- `"Your Best Partner"`: who you have the highest win rate with.

**Note:** Rankings only count matches recorded in the app, including matches between friends without you (they log those themselves from Phase 3).

---

### S8 – Group Detail · from Phase 4

**Purpose:** Regular groups like "Padel every Thursday".

**Contents:** Name, emoji, members, group ranking (like S7, filtered to the group), the group's recent matches.

**Actions:**
- `"Add Match"` → like S2b, participants only from the group
- Add/remove members, rename group, `"Leave Group"`
- Create via S1 → `"New Group"`

---

### S9 – Profile & Settings · from Phase 1

**Contents:**
- **Profile:** emoji/photo, name, color; from Phase 3 username
- **Own stats:** total matches, overall win rate, best sport (highest Elo), favorite sport (most matches), biggest rival (most matches)
- **`"Sports"`:** show/hide sports, default format per sport (e.g. Ping Pong `"Best of 3"`), create custom sports *(from Phase 2)*
- **`"Notifications"`** *(from Phase 3)*: new matches, confirmations, reminders
- **`"Export Data"`** *(from Phase 5)*: CSV
- **`"Reset All Data"`** (double confirmation)
- From Phase 3: `"Delete Account"`

---

## 5. Data Model (SwiftData)

Built-in sports are a Swift `enum` with fixed configuration (not in the database), custom sports are their own model.

```swift
// MARK: - Sports (fixed in code)
enum SportType: String, Codable {
    case badminton, padel, tennis, pingPong, football,
         basketball, penaltyShootout, boxing, goKart, running, custom
}
// Configuration per SportType: emoji, displayName, category,
// scoringType (.sets | .points | .penalties | .fight | .placement | .time | .winLoss),
// allowedModes, allowsDraw, defaultFormat, set rules

// MARK: - Database (SwiftData @Model)
Player        { id, name, emoji?, photo?, colorHex, isMe: Bool,
                isArchived: Bool, cloudUserID: String?, createdAt }

CustomSport   { id, name, emoji, scoringType, allowsDraw, allowsTeams,
                pointsPerSet?, winBy? }

Match         { id, sportType, customSport?, mode: .oneVsOne | .team | .race,
                date, bestOf?, note?, location?, photo?,
                status: .local | .pending | .confirmed | .rejected,
                createdBy: Player, createdAt, updatedAt, version: Int,
                isImported: Bool,
                participants: [MatchParticipant],
                sets: [SetScore], penalties: [PenaltyShot],
                fight: FightDetail?, distanceMeters: Int?,
                retiredSide: Side? }

MatchParticipant { player, side: .a | .b | nil,   // nil for races
                   place: Int?, timeMs: Int?, fastestLapMs: Int?, dnf: Bool }

SetScore      { index, scoreA, scoreB, tiebreakA?, tiebreakB? }
PenaltyShot   { index, side: .a | .b, scored: Bool, isSuddenDeath: Bool }
FightDetail   { winnerSide: Side?, method: .ko | .tko | .points | .retirement,
                endRound?, totalRounds, roundScores: [RoundScore] }

Group         { id, name, emoji, members: [Player] }        // from Phase 4
```

**Important:**
- **Winner and Elo are not stored**, but calculated from the data (one `MatchResult` function per scoring type). That way there is never contradictory data.
- **Duels** are derived from a match (`match.duels(for: player)`); record, streaks and stats are based on them.
- Times are stored in **milliseconds** (Int), not as text.

---

## 6. Online Features (from Phase 3)

### 6.1 Technology: CloudKit
- **Account:** Automatically via the iCloud account, no separate login. On the first online launch you choose a **username** (3–20 characters, a–z, 0–9, `_`, unique).
- **Database:** CloudKit **Public Database** for profiles, friendships, matches. SwiftData remains the local store (cache) so the app works offline.
- **Permissions:** In the Public Database only the creator can change a record. That's why the confirmation is stored as a **separate record**:
  - `Match` belongs to the creator
  - `MatchResponse { matchID, matchVersion, player, response: .confirm | .reject | .approveDelete, reason? }` belongs to the opponent
  - A match is `Confirmed` when every opponent has a `.confirm` response for the current `version`. If the creator edits the match, the `version` goes up and everyone must confirm again.
- **Push notifications:** CloudKit subscriptions (new matches with me, new responses to my matches).
- **Offline:** Entries are saved locally and uploaded automatically as soon as there is internet again.
- **Privacy:** Profiles and matches are technically readable by other app users, but only what concerns friends is shown. Only username, name, emoji/photo and matches are stored.

### 6.2 Who Can Log What?
- Everyone can log matches **they take part in themselves** (including team and race with other friends).
- Matches **without yourself** can't be logged.
- Friends without the app can continue to exist as **local players**. Matches with them only count locally for you (not in shared rankings) until they are linked.

### 6.3 Carrying Over Old Local Matches
1. Max installs the app, you become friends online.
2. On your local friend "Max" you tap `"Link to Account"` and choose the real Max.
3. All your local matches with Max are uploaded (`isImported = true`, status `Pending`).
4. Max gets **one** bulk request: `"Confirm All"` or `"Review"`.
5. Confirmed matches count for both from then on. Rejected ones stay only with you as `"Local only"` and don't count in the shared stats.
6. Matches with several local players (e.g. go-kart) are only uploaded once **all** participants are linked. Until then: note `"Waiting for 2 more players to join"`.
7. **Avoid duplicate entries:** If Max also has local matches with you, only **one** of you can import. When linking, the app asks: `"Max also has local matches with you. Who imports?"`.

---

## 7. Technology Overview

| Area | Technology |
|---|---|
| UI | SwiftUI |
| Charts | Swift Charts |
| Local data | SwiftData |
| Sync & account | CloudKit (Public Database) + iCloud account |
| Push | CloudKit Subscriptions + APNs |
| Haptics | `sensoryFeedback` (SwiftUI) |
| Minimum version | iOS 17 |
| Tests | Swift Testing for result rules, record and Elo calculation |

**Project structure (proposal):**
```
RIVALRRY/
├── App/            RivalrryApp.swift, tab navigation
├── Models/         Player, Match, SetScore, … (SwiftData)
├── Sports/         SportType + configuration, rules & validation per scoring type
├── Logic/          MatchResult, Duels, Record, Elo, Streaks
├── Views/
│   ├── Onboarding/
│   ├── Rivals/         S1
│   ├── FriendDetail/   S2, S2a, S2b, S2c
│   ├── MatchEntry/     input views per scoring type
│   ├── MatchDetail/    S3
│   ├── Profile/        S9
│   └── Components/     cards, tiles, steppers, charts
└── Tests/
```

---

## 8. Implementation in Phases

Every phase ends with an app you can actually use.

### Phase 1 – MVP: local, 1v1
- [ ] Create project, data model (SwiftData), `SportType` configuration
- [ ] Result rules & validation for `sets`, `points`, `penalties`, `fight` + tests
- [ ] S0 Onboarding
- [ ] S1 Rivals with friend cards, sorting, archive
- [ ] S4 Add Friend (local)
- [ ] S2 Friend Detail with header
- [ ] S2a Overview (sport rows without Elo, Recent Matches, See all)
- [ ] S2b Add Match for all duel sports in 1v1 mode (Badminton, Padel, Tennis, Ping Pong, Football, Basketball, Penalty Shootout, Boxing, Running 1v1)
- [ ] S2c Stats: key figures, `"Wins by Sport"`, `"Record over Time"`, `"Win Rate"`, filters
- [ ] S2c `"Head to Head"` per sport: who won more, sets/points/goals combined, sport-specific comparisons
- [ ] S3 Match Detail with edit & delete
- [ ] S9 Profile (profile, show/hide sports, reset)

✅ **Done when:** You can log a badminton match against Max in under 15 seconds and the record + charts are correct.

### Phase 2 – More Sports & Better Stats (still local)
- [ ] Team mode (doubles/2v2 etc.) incl. `"Together"` section
- [ ] Races: Go-Kart (`placement`) and Running with 3+ participants, conversion into duels
- [ ] Elo calculation + tests, Elo in Overview, `"Elo History"` chart
- [ ] Streaks & highlights
- [ ] `"Score Margin"`, `"Activity"` and the remaining sport-specific tiles (beyond `"Head to Head"`)
- [ ] S5 Quick Add
- [ ] Custom sports

✅ **Done when:** A padel doubles match and a go-kart race with 4 people show up correctly in record and Elo.

### Phase 3 – Online with Friends
- [ ] Set up CloudKit, username, profile sync
- [ ] Invite friends (link, QR code, search) + friend requests
- [ ] Match sync, `MatchResponse`, status `Pending`/`Confirmed`/`Rejected`
- [ ] S6 Requests (confirm, reject with reason, remind, deletion requests)
- [ ] Push notifications
- [ ] `"Link to Account"` + import of old matches (6.3)
- [ ] Offline mode

✅ **Done when:** You log a match, Max gets a push notification, confirms it, and it appears in both your stats.

### Phase 4 – Groups & Rankings
- [ ] Groups (S8)
- [ ] S7 Rankings incl. `"Best Duos"` and `"Your Best Partner"`

### Phase 5 – Extras
- [ ] Photos & locations for matches
- [ ] Achievements/badges (e.g. `"10 wins vs Max"`, `"First KO"`, `"Hat-trick"` = 3 wins in one day)
- [ ] Home screen widget: current score against your biggest rival
- [ ] CSV export
- [ ] App Store release (app icon, screenshots, privacy policy)

---

## 9. Deliberately NOT Planned (for now)
- Android version (not needed, everyone has an iPhone)
- Live scoring during the game (point by point)
- Logging matches between friends without taking part yourself
- Chat / comments
- Public rankings with strangers
