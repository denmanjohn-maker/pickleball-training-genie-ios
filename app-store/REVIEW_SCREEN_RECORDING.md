# App Review screen recording — how to produce and submit it

App Review rejected the first submission and asked for:

> A screen recording captured on a physical device, running the latest operating
> system, demonstrating the app's functionality. The recording must begin with
> launching the app and show the typical user flow through its core features.
> Include: account registration, login, and account deletion flows; paid content
> or purchase flows; user-generated content with reporting/blocking; any prompts
> requesting access to sensitive data or device capabilities.

This is an **asset and process item, not a code change**. Nothing in the app
needs to be modified. This document is the reusable recipe: pre-flight checks,
how to record, the exact shot list, and where the file goes in App Store Connect.
Paste-ready text for the reply and the review notes is in
[`APP_REVIEW_NOTES.md`](APP_REVIEW_NOTES.md).

## The "App Clip" section is unrelated — ignore it

App Store Connect shows an **App Clip** section on the version page that says
"To provide metadata for your app clip, you must first upload a build that
contains a clip." An App Clip is a separate lightweight-app *product type* (a
second Xcode target). Pickleball Genie has one app target and no App Clip, so
that section will always show that message. It has nothing to do with the
screen-recording request. **Do not add an App Clip target to satisfy it.**

## Where the recording goes

Two places. Do both.

1. **Reply to the rejection** (this is what clears item 1):
   App Store Connect → *Apps* → Pickleball Genie → click the banner about
   unresolved issues → in *In Progress*, click **Resolve** on the submission →
   **Reply to App Review** → paste the reply text from `APP_REVIEW_NOTES.md` →
   **Attach File** → choose the `.mp4` → **Reply**.
   Attachments are accepted until you resubmit. Reply text is limited to
   4000 characters.
2. **App Review Information on the version page** (so it travels with every
   future submission): scroll to **App Review Information** → fill *Sign-In
   Information* with the reviewer demo account → paste the notes text from
   `APP_REVIEW_NOTES.md` into **Notes** (4000-byte limit) → add the `.mp4`
   under **Attachment** → Save.

**Fallback if the upload is refused (for example, file too large):** host the
`.mp4` somewhere that serves the raw file and paste a *direct file URL* (ending
in `.mp4`) into the reply and the Notes. Apple explicitly prefers a direct file
link over a link to a hosting page or a player. Do not put the video in `docs/`
of this repo; that folder is the public marketing site.

## Pre-flight checklist

Do every item before pressing record. Most re-takes come from skipping one.

- [ ] **Device and OS.** Use an iPhone (primary device family) updated to the
      current public iOS release: Settings → General → Software Update. The
      rejection says "latest operating system"; a beta is fine only if it is
      the current public build.
- [ ] **Install the review build, not a debug build.** Install from TestFlight
      the same build number that is in the submission. A debug build from Xcode
      may carry an `API_BASE_URL` override; the recording must hit production
      (`https://thepickleballgenie.com/`).
- [ ] **Dry-run account deletion first.** Create a throwaway account, then
      Profile → scroll to bottom → **Delete Account** → confirm. It must return
      you to the login screen. If instead you see *"Account deletion isn't
      available yet. Please try again later."*, the production API is returning
      404/405 for `DELETE api/Users/profile` (see
      `AuthViewModel.deleteAccount()`); that must be fixed in the backend repo
      before you record. Recording a failing delete will draw a second
      rejection under Guideline 5.1.1(v).
- [ ] **Two accounts.** Prepare a *fresh, never-used email* for the on-camera
      registration (it gets deleted at the end of the take). Keep the
      *reviewer demo account* separate and never delete it; its credentials go
      in App Review Information → Sign-In Information.
- [ ] **Reset the permission prompts so they fire on camera.** Delete the app
      from the phone and reinstall it from TestFlight. That clears the camera,
      microphone and notification grants and the first-launch tutorial flag.
      (Alternative: Settings → General → Transfer or Reset iPhone → Reset →
      Reset Location & Privacy, then also toggle the app's notifications off in
      Settings.)
- [ ] **Recording format.** Settings → Camera → Formats → **Most Compatible**.
      Screen recordings then come out as H.264 `.mp4`, which App Store Connect
      accepts as an attachment without conversion.
- [ ] **Quiet the phone.** Enable a Focus / Do Not Disturb so no banners land
      in the take. Charge above 50 percent. Remove any other test accounts
      from the login form's autofill if you do not want them visible.
- [ ] **Control Center.** Settings → Control Center → add **Screen Recording**.
- [ ] **Sanity-check network.** Open the app once, log in with the demo
      account, confirm Drills, For You and Tournaments load. Then sign out
      before the take.

## How to record

### Option A — on the iPhone itself (recommended)

1. Go to the Home Screen. Open Control Center, long-press the Screen Recording
   button, make sure the microphone is **off** (no narration needed), tap
   **Start Recording**.
2. Swipe Control Center away during the 3-second countdown so the take starts
   on the Home Screen, then tap the Pickleball Genie icon. That satisfies
   "must begin with launching the app".
3. Follow the shot list below.
4. Stop by tapping the red status pill at the top → **Stop**. The file is saved
   to Photos as an `.mp4`.
5. AirDrop it to a Mac (or upload from the phone via Safari). If you trim the
   dead time at the start or end in Photos, keep the app launch in the clip.

### Option B — Mac + QuickTime Player

1. Connect the iPhone by USB, trust the Mac if prompted.
2. QuickTime Player → File → **New Movie Recording** → click the dropdown next
   to the record button → pick the iPhone as camera and set microphone to
   *None*.
3. Record the same shot list. QuickTime saves a `.mov`.
4. Convert to `.mp4` before attaching (App Store Connect's attachment picker
   lists `.mp4`, not `.mov`):

   ```sh
   ffmpeg -i review.mov -c:v libx264 -crf 23 -pix_fmt yuv420p -c:a aac -movflags +faststart review.mp4
   ```

Either way: one continuous take, portrait orientation, three to six minutes.
Pause for a beat on each permission prompt so the reviewer can read it.

## Shot list

Scene numbers double as the timestamps you will fill into the reply text.
Button labels are the exact strings in the app.

| # | Scene | What to do on screen |
|---|-------|----------------------|
| 1 | **Launch** | From the Home Screen tap the app icon. Let the splash play into the login screen. |
| 2 | **Registration** | Tap **Create Account**. Enter the fresh email, a password (6+ characters), confirm it, tap **Create Account**. On the success sheet tap **Set Up My Profile**. |
| 3 | **Onboarding 1 – About You** | First name, last name, a 5-digit ZIP (e.g. `75201`). Wait for "Finding the closest tournament city…" to resolve to a city. Tap **Continue**. |
| 4 | **Onboarding 2 – Your DUPR** | Pick Singles, Doubles and Target DUPR (target must be ≥ current). Optionally tap **Not sure? Take the 60-second skill check**, answer a couple of questions, return. Tap **Continue**. |
| 5 | **Onboarding 3 – Preferences** | Set session length, handedness, play style. Tap **Continue**. |
| 6 | **Onboarding 4 – Pick an Avatar** | Pick a built-in avatar, then tap **Use a Photo Instead** to show the system photo picker opens with **no permission prompt** (it is an out-of-process picker). Cancel it, tap **Finish**. |
| 7 | **App tutorial** | Swipe through the five tutorial pages, tap **Get Started 🎾**. |
| 8 | **Drills tab** | Type in **Search drills…**, change a category / level filter, open a drill to show the detail screen, tap the heart to favorite it, go back. |
| 9 | **For You tab** | Show "Your Training Plan" recommendations. Tap the "New to pickleball?" card to open **Learn the Basics**, scroll one topic, go back. |
| 10 | **Workout tab** | Pick a **Session Duration**, tap **Generate My Workout**, wait for the plan, tap **Start Guided Session**. Run one drill (skip the timer forward if available), tap **Finish Session**, rate the drills, tap **Save to History**, dismiss the "Workout Saved! 💪" alert. |
| 11 | **Tournaments tab** | If prompted, tap **Choose City** and pick the onboarding city. Scroll the list, open one tournament, go back. |
| 12 | **Profile – history** | Open Profile. Tap **Training History**; the session from scene 10 is listed. Go back. |
| 13 | **Camera + microphone prompts** | Tap **Video Self-Review** → **Record a Clip** → choose a skill → **Open Camera**. iOS shows the **Camera** prompt, then the **Microphone** prompt; tap **Allow** on both. Record a 2–3 second clip, tap *Use Video*, show it in the list. Go back. |
| 14 | **Notifications prompt** | Scroll to **Training Habits**, toggle **Training reminders** on. iOS shows the notifications prompt; tap **Allow**. |
| 15 | **Edit Profile** | Tap **Edit Profile**, change one field, save, show the header updated. |
| 16 | **Sign out and log in** | Scroll to the bottom, tap **Sign Out**, confirm. On the login screen sign back in with the same email/password. (Optional: instead tap **Continue with Apple**, then sign out and sign in with the password so the reviewer sees both.) |
| 17 | **Account deletion** | Profile → bottom → tap the red **Delete Account** → read the confirmation → tap **Delete Account**. The app returns to the login screen. Try logging in with the deleted credentials to show it fails. |
| 18 | **End** | Stop recording. |

Things the rejection lists that this app does **not** have, and therefore are
not in the recording (stated in the reply text so the reviewer does not go
looking): in-app purchases or subscriptions, user-generated content visible to
other users (so no report/block UI), location access, and App Tracking
Transparency.

## After recording

1. Fill the scene timestamps into the reply text in `APP_REVIEW_NOTES.md`.
2. Attach in the reply *and* in App Review Information (see "Where the
   recording goes").
3. Make sure the demo account in Sign-In Information still logs in and was
   not the account deleted in scene 17.
4. Resubmit.

## Re-use

Re-record whenever a flow shown in the video changes materially (login,
onboarding, deletion, permission prompts). Attachments are per version, so
re-attach the current recording under App Review Information on each new
version even when nothing changed.
