# Apple App Review Reply — Sports Calendar Sync v1.0

Submission ID: `d948944a-bab0-4d76-8dc0-88fb7228dec4`
Rejection: Guideline 2.1 — Information Needed (boilerplate request for new app)

---

## What Keith needs to do

1. **Record a screen recording on the iPhone** (see shot list below) → save the .mov.
2. Go to App Store Connect → Sports Calendar Sync → App Review → the rejected submission → click **"Reply to App Review"**.
3. **Paste the reply text below** into the message body.
4. **Attach the .mov** to the reply.
5. Send. Then click **"Resubmit to App Review"**.

---

## Reply text (copy-paste into App Review reply)

> Hi App Review team — thanks for the feedback. Below is the requested information. A screen recording of v1.0 running on a physical iPhone is attached.
>
> **1. Screen recording.** Attached. Recorded on a physical iPhone running iOS 18. Demonstrates the full core flow: launching the app, browsing leagues, following a team, granting calendar access, and seeing fixtures populate Apple Calendar.
>
> **2. App purpose, problem solved, and value.**
> Sports Calendar Sync is a free iPhone app for soccer fans who want to keep their team's upcoming match schedules visible alongside the rest of their life — directly inside the native Apple Calendar — without checking ESPN or any other app every day. The user follows their favorite teams across MLS, the English Premier League, La Liga, Bundesliga, Serie A, and Ligue 1, and the app automatically writes upcoming matches (date, time, opponent, venue, broadcast info) to a dedicated "Sports" calendar in iCloud. When ESPN updates a fixture (e.g., kickoff time changes or a match is postponed), the app updates the corresponding calendar event so the user's calendar stays accurate without manual work.
>
> **3. Instructions for accessing the app's main features.**
> No account, login, or test credentials are required. The full app is available immediately on first launch. To exercise every feature:
> 1. Launch Sports Calendar Sync.
> 2. Tap the **Discover** tab in the floating bottom tab bar.
> 3. Tap any league (e.g., "Premier League") to see its teams.
> 4. Tap any team (e.g., "Arsenal") to view its detail screen with crest, league, recent form, and upcoming fixtures.
> 5. Tap the **Follow** button. The app prompts for Calendar access via the standard EventKit permission dialog. Grant access.
> 6. The app creates a "Sports" calendar in the system Calendar database and writes every upcoming Arsenal fixture as a timed event (kickoff time + 2-hour duration, with venue and broadcast info in the event notes).
> 7. Open the native iOS Calendar app — the "Sports" calendar appears in the calendar list and the Arsenal fixtures appear on the relevant dates.
> 8. Tap the **Upcoming** tab in Sports Calendar Sync to see all followed-team fixtures grouped by date.
> 9. Tap the **Profile** tab to view followed teams, manage notification preferences, and unfollow any team. Unfollowing a team removes its fixtures from the Sports calendar.
>
> **4. External services, tools, and platforms used by the app.**
> - **ESPN public sports data API** (`site.api.espn.com`) — unauthenticated public endpoints used to fetch league lists, team rosters, team crests, and match schedules. No user data is sent to ESPN.
> - **Apple EventKit framework** — used to create the dedicated "Sports" calendar and write match events to the user's local Calendar database. All calendar data stays on-device / in the user's iCloud.
> - **Apple Push Notification service (APNs)** — used to deliver local match-reminder notifications before kickoff. No remote push server is involved.
>
> The app does **not** use: any authentication provider (no sign-in / no accounts), any payment processor (the app is free with no in-app purchases or subscriptions), any analytics SDK, any advertising SDK, any AI service, or any third-party backend. There is no server component — the app talks directly to ESPN's public API and to the on-device Calendar database.
>
> **5. Regional differences.**
> None. The app behaves identically in every region and locale. Match data comes from ESPN's global soccer endpoints, kickoff times are converted to the device's local timezone, and there is no geo-fenced content, region-locked content, or legal/regulatory variation by country.
>
> **6. Regulated industry.**
> Not applicable. Sports Calendar Sync is a personal scheduling/utility app and does not operate in finance, gambling, healthcare, or any other regulated category. There is no betting, no money movement, no medical data, and no government-restricted content.
>
> **Notes on the boilerplate items in the rejection that do not apply to this app:**
> - **Account registration / login / deletion** — not applicable; the app has no accounts.
> - **Paid content, in-app purchase, or subscription flows** — not applicable; the app is fully free with no IAP/subscriptions.
> - **User-generated content / reporting / blocking** — not applicable; there is no UGC.
> - **Sensitive permission prompts** — the only system permissions requested are (a) Calendar access (EventKit) — required to write match events to the user's calendar, the core feature of the app; and (b) Notifications — optional, requested when the user enables match reminders. Both purpose strings clearly describe usage in `Info.plist`. No location, contacts, camera, microphone, photo library, HealthKit, or HomeKit access is used.
>
> Thanks again — happy to provide anything else you need.

---

## Screen recording shot list (~45 seconds)

Record on the physical iPhone (NOT the simulator — Apple specifically requires a real device).

**How to record:** Settings → Control Center → add "Screen Recording" if not already there. Then swipe down from the top-right to open Control Center, tap the record button, wait 3 seconds, open Sports Calendar Sync.

**What to show, in order:**

| Sec | Action |
|-----|--------|
| 0:00 | Home screen — tap "Sports Sync" app icon |
| 0:03 | App launches — show the empty Upcoming tab briefly |
| 0:06 | Tap **Discover** tab in bottom bar |
| 0:08 | Tap **Premier League** (or any league) |
| 0:11 | Scroll briefly through the team list |
| 0:14 | Tap **Arsenal** (or any team) |
| 0:17 | Show team detail — crest, league chip, upcoming fixtures |
| 0:20 | Tap the **Follow** button |
| 0:21 | Calendar permission prompt appears — tap **Allow Full Access** (or "OK") |
| 0:24 | Button changes to "Following" — fixtures begin syncing |
| 0:27 | Tap back to feed, tap **Upcoming** tab — show Arsenal fixtures grouped by date |
| 0:32 | Press home / swipe up — exit to home screen |
| 0:34 | Open native **Calendar** app |
| 0:37 | Show the **Sports** calendar in the calendar list and the Arsenal fixtures on the schedule |
| 0:42 | Stop recording (Control Center → tap red record icon → Stop) |

**Tips:**
- Toggle the device to **silent** before recording so no notification dings.
- Make sure a few real fixtures will appear — Arsenal/Real Madrid/LAFC are reliable test teams.
- If the recording is choppy, plug the phone in (recording is GPU-heavy on older models).
- Trim the start/end in Photos if it looks ugly. Don't add captions or music — Apple wants raw footage.
- Keep it under 60 seconds and under ~50 MB so the upload doesn't time out.

---

## After Apple accepts

Paste sections 2–6 above into **App Store Connect → Sports Calendar Sync → App Information → App Review Information → Notes** so future submissions don't trip the same boilerplate.
