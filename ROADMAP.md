# Pickleball Genie — Product Roadmap

**Status:** proposal for discussion · **Scope:** iOS client (`pickleball-training-genie-ios`) · **Last updated:** 2026-08-01

---

## 1. The mission test

Pickleball Genie exists for players who **can't afford a coach, or can't get to one**. That gives us one bar to measure every feature against:

> **Can a player with no coach, no partner, and no money get meaningfully better using only this app?**

Today the honest answer is *partly*. We are very good at **telling a player what to practice**. We do not yet **run the practice**, **tell them how it went**, or **serve the level most of them are actually at**.

A human coach does five things. Here's where we stand on each:

| What a coach does | Genie today |
|---|---|
| Tells you what to work on | ✅ Drill library, recommendations, AI workouts |
| Meets you at your level | ⚠️ **Only if you're already 3.0+** |
| Paces the session — "three more minutes, go" | ❌ We render a checklist |
| Watches and corrects your form | ❌ Nothing |
| Tells you if you're improving | ⚠️ We count minutes, not skill |

Sections 3–5 attack those gaps in priority order.

---

## 2. What already works

This roadmap is additive. The foundation is solid and shouldn't be disturbed:

| Area | State |
|---|---|
| **Auth** | Email, Google, and Apple sign-in; JWT in Keychain; account deletion (App Store 5.1.1(v) compliant) — `AuthViewModel.swift` |
| **Onboarding** | 4-step flow: name/ZIP → ratings → preferences → avatar, with ZIP→city matching — `OnboardingViewModel.swift` |
| **Drill library** | Browse, search, filter by 10 categories and by level — `DrillsListView.swift` |
| **Personalization** | Server-side recommendations keyed to the player's DUPR |
| **AI workouts** | Generated plan with warm-up, sequenced drills with coaching notes, and cool-down — `WorkoutView.swift` |
| **History** | Completed sessions and mastered drills in one timeline, with volume stats — `WorkoutHistoryView.swift:89` |
| **Tournaments** | City-based listings and detail via a second API — `TournamentsAPIClient.swift` |
| **Design system** | Consistent synthwave theme, reusable button styles and badges — `Theme/AppTheme.swift` |

**Constraint for everything below:** this document plans **iOS-client work only**. Each item is designed to ship against the API that exists today. Where a feature would be materially better with server support, that ask is collected separately in [§6](#6-backend-asks).

---

## 3. The five structural gaps

### Gap 1 — We don't serve beginners 🔴

The lowest skill level offered **anywhere in the app is 3.0**:

- `ViewModels/OnboardingViewModel.swift:58` — signup rating picker
- `Views/ProfileView.swift:471` — edit-ratings picker
- `ViewModels/DrillsViewModel.swift:27` — drill level filter
- `Views/DrillsListView.swift:128` — filter labels

A 3.0 player already has a third-shot drop and a kitchen game. They've usually *had* coaching. The player in our mission statement — just bought a paddle, plays at the rec center, can't afford a pro — is a **2.0 to 2.5**, and we open by asking them to self-identify on a scale that starts above their head.

This is the single biggest gap between our mission and our product. **It's also the cheapest to close.**

### Gap 2 — No solo-vs-partner distinction 🔴

`Drill` (`API/PickleballTrainingGenieClient.swift:7`) carries `title`, `description`, `targetDUPRLevel`, `category`, `videoUrl`, `sourceUrl`. Nothing says whether the drill needs a second person.

This matters more than it first appears. **A player who can't get coaching usually can't get a drilling partner either.** They have a wall, a bucket of balls, and an hour. If half our recommendations silently require a partner, half our value evaporates at the exact moment the player is standing on a court trying to use us.

### Gap 3 — The workout doesn't actually run 🟠

`WorkoutView.swift` produces a beautiful plan and then… renders it as a list with checkboxes. There's no timer, no pacing, no audio cue, no "next up."

The difference between a training *plan* and a training *session* is someone keeping time and telling you when to switch. That's most of what an in-person coach physically does for you. We already fetch all the content needed — `WorkoutDrillItem` includes `durationMinutes` — we just don't drive it.

### Gap 4 — No feedback loop 🟠

`completeDrill(id:)` records **that** you did a drill. Nothing records **how it went**.

Two consequences:
1. **The player can't see improvement.** Our stats are volume — workouts, minutes, drills mastered (`WorkoutHistoryView.swift:89`). "You trained 340 minutes" is not "your dinking got better."
2. **The AI can't adapt.** Every workout is generated from the same static DUPR number. A coach adjusts based on what they saw last session; we have nothing to adjust from.

Volume metrics reward showing up, which is genuinely worth something. But they can't tell a player whether the last six weeks worked.

### Gap 5 — No habit loop, and no offline 🟠

- **No streaks, no goals, no reminders.** `UNUserNotificationCenter` appears nowhere in the codebase. Self-directed training lives or dies on habit, and we do nothing to build one.
- **Nothing is cached.** Every drill and workout is fetched live. Outdoor courts have bad signal — **the player cannot open their workout at the place they train.** This is a real, physical failure mode, not a nice-to-have.

---

## 4. Tier 1 — The beginner on-ramp 🔴 *(next up)*

Three changes that together make the app usable by the audience it was built for.

### 4a. Add 2.0 and 2.5 levels

**The refactor first.** The level scale is currently declared in **six** places, three of which are near-duplicates:

| Location | What it holds |
|---|---|
| `ViewModels/OnboardingViewModel.swift:58` | `duprOptions` — value + label |
| `Views/ProfileView.swift:471` | `duprOptions` — **the same list, duplicated** |
| `ViewModels/DrillsViewModel.swift:27` | `duprLevels` — values only |
| `Views/DrillsListView.swift:128` | `duprLabel(_:)` — value → label |
| `Theme/AppTheme.swift:186` | `DUPRBadge` — value → label and color |
| `Views/ProfileView.swift:386` | `duprInfo` — value → title + description |

Adding two levels to six lists invites drift. **Introduce one source of truth first** — a `SkillLevel` type (suggested: new `Models/SkillLevel.swift`) holding value, short label, description, and badge color — then have all six call sites read from it. Adding 2.0/2.5 becomes a two-line change, and `DUPRBadge` stops re-deriving what the model already knows.

**Proposed scale:**

| Level | Label | Description |
|---|---|---|
| 2.0 | New to the game | Learning to serve and return, still learning the rules |
| 2.5 | Advanced beginner | Can sustain short rallies, knows the basic rules |
| 3.0 | Beginner | Learning basic strokes, court positioning |
| 3.5 | Intermediate | Third shot drop, kitchen game, transitions |
| 4.0 | Advanced | Pattern recognition, speed-up/reset sequences |
| 5.0 | Pro | ATP, Erne, tournament-level tactics |

> Note the awkwardness of DUPR's own naming — 3.0 is labeled "Beginner" but is nothing of the sort for our audience. Consider leading with the plain-language label and showing the number secondarily.

**Two iOS-only risks, and how to handle them honestly:**

1. **The backend may reject sub-3.0 ratings.** `PUT api/Users/profile/ratings` could 400. The 400 path already exists and surfaces a clear message (`OnboardingViewModel.swift:186`) — reuse it rather than adding a new error surface.
2. **There may be no 2.0/2.5 drills to show.** `GET api/Drills?level=2.0` will return an empty array until content is tagged. **Never show an empty screen to a brand-new user** — that's the worst possible first impression for exactly the person we're trying to win. Fall back to the nearest populated level with a visible "showing 3.0 drills — closest to your level" note.

Both risks are ultimately resolved server-side; see [§6](#6-backend-asks). Neither blocks shipping the client work.

### 4b. Skill self-assessment

**Most beginners don't know their DUPR.** Asking for it on the second onboarding screen is asking a question they can't answer, and a wrong guess poisons every recommendation that follows.

Add an optional branch on the ratings step: **"Not sure? Take a 60-second check."** Eight to ten plain-language questions, no jargon:

- Can you get your serve in most of the time?
- Do you know what the kitchen is and when you can stand in it?
- Can you keep a dink rally going for 10 shots?
- Do you know what a third-shot drop is? Do you use one?
- Can you return a serve deep on purpose?
- Do you keep score confidently without help?

**It produces two things:**
1. **An estimated level** (2.0–4.0), which maps directly onto the existing `singlesDUPR` / `doublesDUPR` / `targetDUPR` fields in `UpdateProfileRequest` — **no new data goes to the server**, so this ships against today's API unchanged.
2. **A per-category strength profile** across the ten existing `drillCategories` (`DrillsViewModel.swift:22`) — the genuinely new signal, and the seed of real personalization.

**Storage:** persist the profile in `UserDefaults`. There's precedent — `tournaments.lastCityId` is stored this way at `ContentView.swift:122`. Use it to **client-side re-rank** `RecommendationsView` so weak categories surface first, and to preselect filters on the Drills tab.

**Be clear about the limit:** the server's `GET api/Drills/recommendations` still only knows the player's DUPR. Until it accepts a focus parameter, this is client-side re-ranking of a server-chosen list — better than nothing, but not true personalization.

### 4c. A "Learn" section

Beginners don't only lack technique. They lack **the rules**. Scoring alone stops people from playing — it's genuinely confusing, and there's no dignified way to ask a stranger at open play for the fourth time.

Ship a bundled reference — **no network at all** — following the existing pattern of `Resources/ZipPrefixCentroids.json`:

- How to keep score (singles and doubles)
- Serving rules and the two-bounce rule
- The non-volley zone, in plain language
- Common faults and how to avoid them
- Where to stand, and when to move up
- Choosing a paddle without overspending
- A glossary: dink, drop, ATP, Erne, stacking, reset, speed-up

Because it's bundled, **this is also the first content in the app that works with zero signal** — a small down payment on Gap 5.

**⚠️ Open decision — where does it go?** The tab bar is already at five (`ContentView.swift:82`), which is the practical iOS limit before the system collapses everything into a "More" list. Options:

| Option | Trade-off |
|---|---|
| **Learn nested under Drills** *(recommended)* | Segmented control or toolbar entry. No tab-bar cost. Conceptually right: "practice this" and "understand this" belong together. |
| Learn under Profile | Cheapest, but buries the content beginners need most behind an account screen |
| Merge Tournaments into Profile, free a tab | Cleanest information architecture long-term, but demotes a shipped feature — a product call, not a technical one |

**This one needs a decision before implementation.**

---

## 5. Tier 2+ — Everything else, by impact ÷ cost

### 🟠 Guided Session Mode — *client-only, high impact*
A full-screen runner over the `WorkoutPlanResponse` we **already fetch**: per-drill countdown, audio and haptic cues on transitions, next-up preview, pause/skip, and auto-checkoff that feeds the existing `completeWorkout(completedIndices:)` (`DrillsViewModel.swift:93`). `WorkoutDrillItem.durationMinutes` is already in the payload and currently only displayed as a label.

**This is the highest-leverage item in Tier 2** — it changes the app from something you read into something that trains you, using content we already have and endpoints we already call.

### 🟠 The feedback loop — *client-only to start*
After a session, one tap per drill: *how did that go?* (1–5, or simply nailed it / getting there / struggled). Store locally, use to re-rank. This is the missing half of `completeDrill` and the foundation of any real progress tracking — **until we know how a drill went, "improvement" is unmeasurable.** Server persistence is the natural follow-up ([§6](#6-backend-asks)).

### 🟠 Habit loop — *client-only, cheap*
Streaks and a weekly training goal, computable **entirely from data we already receive** — `workoutSessions` returns `completedAt` on every session (`PickleballTrainingGenieClient.swift:86`). Add opt-in reminder notifications via `UNUserNotificationCenter`; this needs runtime authorization only, **no Info.plist key**. Low cost, disproportionate retention impact for a self-directed training product.

### 🟠 Offline cache
Persist the drill list, the current workout, and Learn content to disk (`Codable` → Application Support). Fixes the "no signal at the court" failure described in Gap 5. Should ship alongside or before Guided Session Mode — a session runner that dies when the signal drops is worse than no session runner.

### 🟡 Video self-review
Record your stroke, scrub it in slow motion against a per-skill rubric ("paddle back early? contact out front? follow through to target?"), save the clip, and compare against the same stroke a month later. **This is the closest we can get to a coach's eye without server-side AI**, and side-by-side progress comparison is a genuinely compelling reason to keep the app.

⚠️ Requires `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` — **both currently absent from `Info.plist`**. Clips must stay on-device by default; recording yourself is sensitive and the privacy story has to be airtight before this ships.

### 🟡 Inline video playback
`DrillDetailView.swift:58` currently hands the video to Safari, which drops the player out of the app mid-session. `LoopingVideoPlayerView.swift` shows AVKit is already integrated. Small change, meaningful polish.

### 🟡 Favorites and a session journal
Save drills to a personal list; jot a note after a session ("backhand dink felt better standing closer"). Cheap, and the journal pairs naturally with the feedback loop.

### 🟢 Multi-week programs
"6 weeks to 3.0" — structured progression instead of one-off workouts. This is what a coach actually sells: a *plan*, not a drill. Mostly a backend concern; parked until the feedback loop exists to drive progression.

### 🟢 Community, partner finding, court finder
Real demand, especially the partner problem from Gap 2. But it needs backend, moderation, and safety review. **Explicitly out of near-term scope** — noted so it isn't mistaken for an oversight.

### ⚙️ Engineering debt worth naming
- **No test target exists.** Not one. The DUPR consolidation in §4a is a natural first candidate — pure logic, easy to cover.
- **No accessibility or Dynamic Type pass.** An app for people locked out of coaching shouldn't lock out anyone else.
- `Color(.systemGray5)` hardcoded at `WorkoutView.swift:162` bypasses the theme system.

---

## 6. Backend asks

Not iOS work — collected here so the API owner has a single list. Roughly in order of how much client value each unlocks.

**Unblocks Tier 1:**
1. **Accept ratings below 3.0** on `PUT api/Users/profile/ratings` and registration.
2. **Tag drill content at 2.0 and 2.5.** Without this, §4a ships a level filter with nothing behind it.

**Unblocks Gap 2 (the partner problem):**

3. **Extend the `Drill` model.** The highest-value single change on this list:
   - `requiresPartner` / `playerCount` — **lets us filter to solo-friendly drills**
   - `equipment[]` — wall, ball machine, cones, just a paddle
   - `durationMinutes` — the library drill has no duration; only AI-generated drills do
   - `steps[]` — structured instructions instead of one prose blob
   - `skillTags[]` — finer-grained than the 10 categories
   - `targetScore` / `reps` — gives the drill a pass/fail, which makes progress measurable

**Unblocks real personalization:**

4. `POST api/workouts/generate` to accept `focusCategories[]`, `soloOnly`, and available `equipment` — currently it takes only `durationMinutes` (`GenerateWorkoutRequest`).
5. `GET api/Drills/recommendations` to accept the same focus signal, so §4b becomes true personalization rather than client-side re-ranking.
6. **Persist per-drill self-ratings** and expose a skill trend over time — turns Tier 2's feedback loop from a local convenience into the engine behind adaptive workouts.
7. **Program endpoints** for multi-week structured plans.

---

## 7. Suggested sequencing

**Release 1 — Meet beginners where they are**
§4a levels + `SkillLevel` consolidation · §4b self-assessment · §4c Learn section.
*Closes the widest mission gap, and the only one where our floor sits above our audience.*

**Release 2 — Make it train you**
Guided Session Mode · offline cache · habit loop and streaks.
*Turns existing content into an actual coached session that works at the court.*

**Release 3 — Close the loop**
Per-drill feedback · progress that measures skill instead of minutes · video self-review.
*The part that tells a player whether any of it worked.*

Backend items from §6 should be scheduled alongside — items 1 and 2 gate Release 1's content, and item 3 is what finally makes solo training a first-class path.

---

## Summary

The app is a strong drill *library* with AI plan generation. To be a **complete coaching solution** it needs to serve beginners (§4), run the session (§5), and measure skill rather than volume (§5). Release 1 is entirely client-side except for the two content asks — that's the cheapest, highest-impact place to start.
