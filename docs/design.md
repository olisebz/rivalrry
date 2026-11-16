# RIVALRRY – Design Guide for Mockups

**Style in one sentence:** Black, white, grey – and green only where you're supposed to do something or where you're ahead.

> Belongs to `plan.md`. The screen numbers (S0, S1, S2a …) refer to the plan.

---

## 1. The 7 Ground Rules

1. **Less is more.** Every screen has exactly *one* main action. Everything else stays in the background.
2. **Green is rare.** At most 1–2 green elements per screen. If everything is green, nothing stands out.
3. **Numbers are the heroes.** The record (`12 – 9`) is the biggest thing on the screen, not images or decoration.
4. **Lots of white space.** More spacing rather than more content. When in doubt, leave something out.
5. **No decoration.** No gradients, no shadows (except on the "+" button), no borders around everything, no background images.
6. **Native iOS.** System font, SF Symbols, standard iOS gestures. The app should feel like an Apple app.
7. **No emojis.** Nowhere in the app – not for sports, avatars, streaks or in texts. Use SF Symbols and initials instead.

---

## 2. Colors

### 2.1 Color Palette

| Name | Usage | Light | Dark |
|---|---|---|---|
| `background` | Background of every screen | `#FFFFFF` | `#000000` |
| `surface` | Cards, tiles, input fields | `#F5F5F7` | `#1C1C1E` |
| `separator` | Divider lines | `#E5E5EA` | `#38383A` |
| `textPrimary` | Headings, numbers, normal text | `#111111` | `#F5F5F7` |
| `textSecondary` | Subtitles, dates, labels | `#6E6E73` | `#98989D` |
| `textTertiary` | Placeholders, disabled | `#AEAEB2` | `#636366` |
| **`accent`** | **Buttons, active selection, "you lead"** | **`#15803D`** | **`#22C55E`** |
| `accentSoft` | Background for selected elements | `accent` at 10 % opacity | `accent` at 15 % opacity |
| `onAccent` | Text on green button | `#FFFFFF` | `#000000` |
| `destructive` | **only** delete / reset | `#DC2626` | `#EF4444` |

> **Why two greens?** On white you need a darker green so white text stays readable. On black, a lighter green with black text looks more modern and is also easy to read.

### 2.2 Where Green Is Used – and Where Not

| Green | Not green |
|---|---|
| Main button (`"Save Match"`, `"Add Friend"`, `"Get Started"`) | Headings |
| `"+"` button (Quick Add) | Icons in lists |
| Selected sport tile (border + `accentSoft`) | Backgrounds of whole areas |
| Active tab in the tab bar | Friend names |
| Record when **you lead** | Record when the friend leads (→ `textPrimary`) |
| **Your** line/bars in charts | The friend's chart (→ grey) |
| Goal in penalties, winner marker | Normal links/text buttons (→ `textPrimary`, no underline needed) |

### 2.3 Win & Loss Without Red
To keep the app calm, there is **no red for losses**:

| State | Display |
|---|---|
| You lead / win | `accent` (green) |
| Tie / draw | `textSecondary` (grey) |
| Friend leads / loss | `textPrimary` (black or white) |

Red (`destructive`) appears **exclusively** for `"Delete"`, `"Reset All Data"` and `"Delete Account"`.

> **Change compared to `plan.md`:** S1 said "red = they lead". This is replaced by: **green = you lead, black = they lead, grey = tied.**

### 2.4 Friends' Colors
Each player has a "favorite color" in the plan. To keep things calm, it is used **only** in the round avatar: muted background (15 % opacity), initials in the full color. Nowhere else.

### 2.5 Avatars
- With photo: photo in a circle.
- Without photo: **initials** (1–2 letters, e.g. `MK` for Max Keller, `M` for a single name), `headline` or 22 pt Semibold for the large avatar, color as above.
- You yourself: same display as everyone else.

---

## 3. Typography

**Typeface:** SF Pro (iOS system font). For large numbers **SF Pro Rounded** – looks sporty and friendly.
Numbers always use **monospaced digits** (`monospacedDigit()`) so nothing jumps when values change.

| Style | Size / weight | Usage | SwiftUI |
|---|---|---|---|
| `scoreHero` | 56 pt, Bold, Rounded | Record in the S2 header | `.system(size: 56, weight: .bold, design: .rounded)` |
| `scoreLarge` | 34 pt, Bold, Rounded | Counters during entry, record on cards | `.system(size: 34, weight: .bold, design: .rounded)` |
| `largeTitle` | 34 pt, Bold | Screen titles (`"Rivals"`) | `.largeTitle.bold()` |
| `title` | 22 pt, Semibold | Section titles (`"Recent Matches"`) | `.title2.weight(.semibold)` |
| `headline` | 17 pt, Semibold | Names, button text | `.headline` |
| `body` | 17 pt, Regular | Normal text | `.body` |
| `subheadline` | 15 pt, Regular | Second line on cards | `.subheadline` |
| `caption` | 12 pt, Medium | Chart axes, small labels | `.caption.weight(.medium)` |

**Rules:**
- At most **3 font sizes** per screen (numbers not counted).
- No all-caps text, except small labels above tiles (e.g. `WIN RATE`, 12 pt, Medium, 0.5 pt letter spacing, `textSecondary`).
- Support Dynamic Type: texts must also work with a larger system font.

---

## 4. Spacing, Corners, Sizes

### 4.1 Spacing (8-point grid)
All spacing is a multiple of 4 – usually of 8.

| Token | Value | Usage |
|---|---|---|
| `xs` | 4 pt | Between icon and text |
| `s` | 8 pt | Between related elements |
| `m` | 16 pt | Card padding, **left/right screen margin** |
| `l` | 24 pt | Between sections |
| `xl` | 32 pt | Top/bottom of empty states, before large numbers |
| `xxl` | 48 pt | S2 header top/bottom |

### 4.2 Corners (radius)

| Element | Radius |
|---|---|
| Cards, tiles | 16 pt |
| Buttons, input fields | 14 pt |
| Small chips (filters) | Capsule (fully round) |
| Avatars | Circle |

Always use **"continuous"** corners (`RoundedRectangle(cornerRadius: 16, style: .continuous)`) – those are the soft Apple corners.

### 4.3 Sizes

| Element | Size |
|---|---|
| Mockup frame | **iPhone 15/16: 393 × 852 pt** |
| Main button | full width (minus 2 × 16 pt), **52 pt high** |
| Minimum tap target | 44 × 44 pt |
| Small avatar (lists) | 40 pt |
| Large avatar (S2 header) | 64 pt |
| Sport tile | ~ 104 × 96 pt (3 per row) |
| `"+"` button | 56 pt circle, 16 pt from the edge, above the tab bar |
| Divider line | 0.5 pt |

---

## 5. Icons

- **Icons:** Only **SF Symbols**, weight *Regular*, color `textPrimary` or `textSecondary`. Active state: `accent`.
- **Tab bar:**

| Tab | Symbol (inactive / active) |
|---|---|
| `"Rivals"` | `person.2` / `person.2.fill` |
| `"Requests"` | `tray` / `tray.fill` |
| `"Rankings"` | `trophy` / `trophy.fill` |
| `"Profile"` | `person.crop.circle` / `person.crop.circle.fill` |

- **Other symbols:** Add friend `person.badge.plus`, menu `ellipsis`, Quick Add `plus`, filter `line.3.horizontal.decrease`, confirm `checkmark`, reject `xmark`, waiting `clock`.
- **Sports** (single color, like all icons; `accent` when selected):

| Sport | SF Symbol |
|---|---|
| Badminton | `figure.badminton` |
| Padel | `figure.racquetball` (there is no dedicated padel symbol) |
| Tennis | `figure.tennis` |
| Ping Pong | `figure.table.tennis` |
| Football | `figure.soccer` |
| Basketball | `figure.basketball` |
| Penalty Shootout | `soccerball` |
| Boxing | `figure.boxing` |
| Go-Kart | `steeringwheel` |
| Running | `figure.run` |
| Custom sport | Choice of about 20 symbols (e.g. `figure.golf`, `figure.bowling`, `figure.climbing`, `figure.volleyball`, `trophy`) |

- **Streaks:** `flame` (win streak, `accent`) or `arrow.down.right` (losing streak, `textSecondary`) instead of emojis.
- No illustrations in empty states – instead a large SF Symbol (48 pt) in `textTertiary`.
- In Figma: install Apple's **SF Symbols** app (free), copy symbols from it and paste them into Figma as text.

---

## 6. Components

### 6.1 Buttons

| Type | Appearance | Example |
|---|---|---|
| **Primary** | Background `accent`, text `onAccent`, `headline`, 52 pt high, full width | `"Save Match"` |
| **Secondary** | Background `surface`, text `textPrimary` | `"Add Set"`, `"Review"` |
| **Text** | No background, text `textPrimary`, `headline` | `"See all"`, `"Cancel"` |
| **Destructive** | No background, text `destructive` | `"Delete Match"` |
| **Disabled** | Background `surface`, text `textTertiary` | `"Save Match"` with an invalid result |

**At most one Primary button per screen.** Pressed: 96 % scale + light haptics.

### 6.2 Friend Card (S1)
```
┌──────────────────────────────────────────┐
│  (MK)  Max                      12 – 9   │  ← name headline, record scoreLarge
│        Badminton · 2 days ago   [flame] 4│  ← subheadline, textSecondary
└──────────────────────────────────────────┘
```
- Background `surface`, radius 16, padding 16, spacing between cards 8.
- No arrow (`chevron`) needed – the whole card is tappable.

### 6.3 Friend Detail Header (S2)
```
        (AM)                         (MK)
         You                          Max

                    12 – 9                    ← scoreHero, "12" green if you lead
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━      ← bar: green (you) | grey (Max)
```
- No box, no card – directly on `background`.
- Bar: 6 pt high, capsule shape, left `accent`, right `separator`.

### 6.4 Segmented Control (tabs in S2, filters)
- Native iOS `Picker(.segmented)` – don't style it yourself.

### 6.5 Filter Chips (S2c)
```
( All ) ( Badminton ) ( Padel ) ( Ping Pong )   → horizontally scrollable
```
- Inactive: `surface` + `textPrimary`. Active: `textPrimary` as background + `background` as text (i.e. black/white inverted – **not green**, so green stays reserved for actions).

### 6.6 Key Figure Tile
```
┌──────────────┐
│ WIN RATE     │  ← caption, all caps, textSecondary
│ 57 %         │  ← scoreLarge
└──────────────┘
```
- 2 tiles per row, `surface`, radius 16.

### 6.7 Sport Tile (S2b)
- `surface`, SF Symbol 28 pt at the top (`textPrimary`), name `subheadline` below.
- When selected, the symbol also turns `accent`.
- Selected: 2 pt `accent` border + `accentSoft` background.

### 6.8 Counter / Stepper (result entry)
```
        You                    Max
   ( – )  21  ( + )      ( – )  19  ( + )
```
- Number `scoreLarge`, round 44 pt buttons, `surface`, symbol `minus`/`plus`.
- Tap the number → keyboard for direct input.

### 6.9 List Row (match)
```
[ic] Badminton                    2 – 1   [checkmark]
     Nov 12 · Best of 3
─────────────────────────────────────────── ← separator, indented from the text
```
- Result in `accent` if you won, otherwise `textPrimary`.
- Status on the right: `checkmark` (confirmed, `textSecondary`), `clock` (waiting, `textSecondary`).

### 6.10 Empty State
- Centered: SF Symbol 48 pt in `textTertiary` (e.g. `person.2` for S1, `sportscourt` for Overview, `chart.xyaxis.line` for Stats) → text `body` in `textSecondary` (max. 2 lines) → Primary button.

### 6.11 Live Preview While Logging (S2b)
- Above the button: `"You win 2–1"` in `headline`, `accent` if you win; otherwise `textPrimary`.

### 6.12 Head to Head (S2c, one sport selected)
```
┌──────────────────────────────────────────┐
│ You           HEAD TO HEAD           Max │  ← headline / caption caps, textSecondary
│                  5 – 3                   │  ← scoreLarge, record colors (§2.3)
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │  ← win share bar (§6.3)
│ 11            Sets won                 8 │
│ 372          Points won              381 │  ← label subheadline, textSecondary
└──────────────────────────────────────────┘
```
- Box `surface`, radius 16, padding 16; rows separated by `separator` lines.
- Values `body`, monospaced digits. The better value is bold: `accent` if it's yours, `textPrimary` if it's the friend's. Tied values and shared values (e.g. draws) in `textSecondary`.
- Like the record, the green here is data, not an action. Keep everything else on the Stats screen neutral.

---

## 7. Charts (Swift Charts)

| Rule | Implementation |
|---|---|
| Only 2 colors | **You = `accent`**, **friend = `textTertiary`** (grey) |
| Draws (donut) | `separator` |
| No grid lines | Only very thin horizontal lines (`separator`, 0.5 pt), no vertical ones |
| Axes | `caption`, `textSecondary`, at most 4–5 labels |
| Lines | 2.5 pt, rounded caps, smooth curve (`.interpolationMethod(.catmullRom)`) |
| Bars | 4 pt radius at the top, gap between bars at least half a bar wide |
| Legend | No separate legend – put the names directly in the chart title instead: `"You"` (green) `vs` `"Max"` (grey) |
| Tapping | Value is shown above the chart (`chartXSelection`), no pop-up |
| Height | 200 pt, in a `surface` box with 16 pt padding |

---

## 8. Motion & Haptics

- **Animations:** short and soft – `.spring(duration: 0.3)`. No effects longer than 0.4 s.
- **Numbers:** animate counting up when they change (`.contentTransition(.numericText())`).
- **Haptics:**
  - Stepper +/– → light tap (`.selection`)
  - `"Save Match"` → success (`.success`)
  - Tapping with an invalid result → warning (`.warning`)
- **No confetti**, no sounds. Only exception later (Phase 5): a short animation when unlocking a badge.

---

## 9. Creating Mockups – Step by Step

### 9.1 Tool
Recommendation: **Figma** (free).
1. Create a new file `RIVALRRY Mockups`.
2. Duplicate Apple's community file **"iOS 18 UI Kit"** (contains tab bar, segmented control, keyboard etc.).
3. Create the colors from section 2 as **color styles** (`background`, `surface`, `accent` …), each with a light and a dark variant.
4. Create the type styles from section 3 as **text styles**.
5. Build the components from section 6 once and save them as **Figma components**, then reuse them everywhere.

### 9.2 File Structure

| Page in Figma | Contents |
|---|---|
| `0 – Foundations` | Colors, type, spacing, icons |
| `1 – Components` | Buttons, cards, tiles, steppers, chips, list row |
| `2 – Phase 1 Screens` | all screens for Phase 1 |
| `3 – Phase 2+ Screens` | later |

### 9.3 Mockup Order (Phase 1)
Always **light first, then dark**, and for every screen also the **empty state**.

| # | Screen | Variants |
|---|---|---|
| 1 | S1 Rivals | with 4 friends · empty |
| 2 | S2a Overview | with data (you lead) · friend leads · empty |
| 3 | S2b Add Match – choose sport | — |
| 4 | S2b Add Match – result | Badminton (sets) · Football (counter) · Penalty Shootout · Boxing |
| 5 | S2b – invalid result | `"Save Match"` disabled + hint |
| 6 | S2c Stats | filter "All" · one sport selected |
| 7 | S3 Match Detail | — |
| 8 | S4 Add Friend | — |
| 9 | S0 Onboarding | 3 steps |
| 10 | S9 Profile | — |

### 9.4 Sample Data for the Mockups
Always use the same data so the mockups feel real and consistent:

| Player | Initials | Record against you | Last |
|---|---|---|---|
| You (Alex Morgan) | AM | – | – |
| Max Keller | MK | 12 – 9 (you lead) | Badminton · 2 days ago |
| Tom Berger | TB | 5 – 7 (Tom leads) | Padel · yesterday |
| Lukas Huber | LH | 3 – 3 (tied) | Ping Pong · 1 week ago |
| Jonas Weber | JW | 8 – 2 (you lead) | Go-Kart · 3 weeks ago |

Against Max: Badminton 5 – 3 · Ping Pong 4 – 2 · Football 2 – 3 · Penalty Shootout 1 – 1.

---

## 10. Checklist for Every Screen

Check before finishing a mockup:

- [ ] At most **one** Primary button?
- [ ] At most **1–2 green** elements?
- [ ] Red only for deleting?
- [ ] **No emojis?**
- [ ] At most **3 font sizes** (excluding numbers)?
- [ ] 16 pt screen margin, all spacing on the 4/8 grid?
- [ ] Everything tappable at least 44 × 44 pt?
- [ ] Works in **dark mode**?
- [ ] Is there an **empty state**?
- [ ] All texts in **English** and exactly as in `plan.md`?
- [ ] Can something be left out? → Then leave it out.

---

## 11. Colors & Fonts as SwiftUI Code

So that mockup and app later look exactly the same:

```swift
import SwiftUI

extension Color {
    // Create each one in Assets.xcassets with a light/dark variant
    static let rvBackground    = Color("Background")     // #FFFFFF / #000000
    static let rvSurface       = Color("Surface")        // #F5F5F7 / #1C1C1E
    static let rvSeparator     = Color("Separator")      // #E5E5EA / #38383A
    static let rvTextPrimary   = Color("TextPrimary")    // #111111 / #F5F5F7
    static let rvTextSecondary = Color("TextSecondary")  // #6E6E73 / #98989D
    static let rvTextTertiary  = Color("TextTertiary")   // #AEAEB2 / #636366
    static let rvAccent        = Color("Accent")         // #15803D / #22C55E
    static let rvOnAccent      = Color("OnAccent")       // #FFFFFF / #000000
    static let rvDestructive   = Color("Destructive")    // #DC2626 / #EF4444
    static let rvAccentSoft    = Color("Accent").opacity(0.12)
}

extension Font {
    static let rvScoreHero  = Font.system(size: 56, weight: .bold, design: .rounded).monospacedDigit()
    static let rvScoreLarge = Font.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()
}

enum Spacing {
    static let xs: CGFloat = 4,  s: CGFloat = 8,  m: CGFloat = 16
    static let l: CGFloat = 24,  xl: CGFloat = 32, xxl: CGFloat = 48
}

enum Radius {
    static let card: CGFloat = 16, button: CGFloat = 14
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(isEnabled ? Color.rvOnAccent : Color.rvTextTertiary)
            .background(isEnabled ? Color.rvAccent : Color.rvSurface,
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.3), value: configuration.isPressed)
    }
}
```

Also set the **AccentColor** in the Xcode asset catalog to `#15803D` / `#22C55E`. Then the tab bar, toggles and system elements automatically get the matching color.
