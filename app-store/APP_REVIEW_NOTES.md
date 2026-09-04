# Paste-ready text for App Store Connect

Two blocks. Replace every `<placeholder>` before pasting. Never commit real
credentials to this file; the demo account password lives only in App Store
Connect → App Review Information → Sign-In Information.

Both blocks are well under the 4000-character / 4000-byte limits.

---

## 1. Reply to App Review (Resolution Center)

Use with the `.mp4` attached via **Attach File**.

```text
Thank you for the review. Attached is a screen recording captured on an
<iPhone model> running iOS <version>, recorded in a single take on the
submitted build (<build number>). It begins at app launch and walks the
typical user flow through the core features.

Timestamps:
<0:00>  App launch (splash) to the sign-in screen
<m:ss>  Account registration (Create Account) and profile onboarding
        (name/ZIP, DUPR ratings, preferences, avatar) and first-launch tutorial
<m:ss>  Drills library: search, filters, drill detail, favorite
<m:ss>  For You recommendations and Learn the Basics
<m:ss>  AI Workout: generate, guided session, rate drills, save to history
<m:ss>  Tournaments near the user's chosen city
<m:ss>  Profile: Training History
<m:ss>  Camera and Microphone permission prompts (Video Self-Review >
        Record a Clip). Clips are stored only on the device and never uploaded.
<m:ss>  Notifications permission prompt (Training reminders toggle)
<m:ss>  Edit Profile
<m:ss>  Sign out, then sign in with email and password
<m:ss>  Account deletion: Profile > Delete Account > confirm. The account is
        deleted server-side and all on-device data is erased; the app returns
        to the sign-in screen.

Regarding the other items listed in the request, none apply to this app:
- No paid content, in-app purchases, or subscriptions. The app is free.
- No user-generated content that is visible to other users, so there is no
  reporting or blocking mechanism. The only content a user creates is their
  own avatar and private, on-device practice clips.
- No location access is requested. Tournament proximity is derived from a
  ZIP code the user types, matched against a bundled table.
- No App Tracking Transparency prompt; the app does not track users.

The only system permission prompts are Camera, Microphone (both for the
optional Video Self-Review feature) and Notifications (opt-in training
reminders), all shown in the recording.

A reviewer demo account is provided under App Review Information > Sign-In
Information. Sign in with Apple and Google are also offered on the sign-in
screen.

Please let me know if anything else is needed.
```

---

## 2. App Review Information → Notes (version page)

Keep this on the version so it accompanies every future submission. Attach
the same `.mp4` under **Attachment**.

```text
Pickleball Genie is a free training coach for pickleball players: a drill
library, DUPR-based recommendations, AI-generated guided workouts, tournament
listings near a chosen city, and a personal profile with training history.

Demo account: use the Sign-In Information above. It has a completed profile;
registering a new account instead shows the onboarding flow (name/ZIP, DUPR
ratings, preferences, avatar) followed by a short tutorial.

Where to find the flows App Review asks about:
- Registration: sign-in screen > Create Account.
- Login: email/password, Sign in with Apple, or Continue with Google.
- Account deletion (Guideline 5.1.1(v)): Profile tab > scroll to the bottom >
  Delete Account > confirm. Deletes the account on the server and erases all
  on-device data, then returns to the sign-in screen.
- Camera + Microphone prompts: Profile > Video Self-Review > Record a Clip >
  choose a skill > Open Camera. Clips are saved only on the device and are
  never uploaded.
- Notifications prompt: Profile > Training Habits > Training reminders toggle.
- Photo library: the avatar picker uses the system photo picker, so no
  permission prompt is shown.

Not applicable to this app: in-app purchases or subscriptions; user-generated
content visible to other users (so no report/block UI); location services
(tournament proximity comes from a typed ZIP code); App Tracking Transparency
(no tracking).

The attached screen recording (physical iPhone, current iOS) starts at launch
and shows every flow above, including registration, login and account
deletion.

Backend: the app talks to https://thepickleballgenie.com/ over HTTPS.
```
