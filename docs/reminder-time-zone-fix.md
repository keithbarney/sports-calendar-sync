# Reminder timing after travel

## Cause and fix

The former notification trigger extracted local year/month/day/hour/minute values without including a time zone. A September reminder scheduled in Mexico City (UTC−6) and later evaluated in Wisconsin (UTC−5) moved one hour earlier. A 30-minute reminder consequently became a 90-minute reminder. Calendar events use the kickoff `Date` and are separate from these app notifications.

`NotificationService` now constructs notification triggers with a Gregorian calendar and an explicit UTC time zone, including seconds. The scheduled instant is kickoff plus the selected reminder offset, regardless of subsequent travel or daylight-saving changes.

On launch, foreground activation, and refresh, the app awaits notification authorization and repairs pending legacy calendar triggers that lack a time zone. Repair uses stored fixture kickoff dates and the current reminder setting; it does not reinterpret the old local components in the new time zone. This runs before the fixture-fetch throttle and requires no ESPN request or Calendar write. Already fixed requests and unrelated notifications are left alone. Off, postponed/cancelled fixtures, and elapsed reminder times remove the legacy request. A failed replacement remains eligible for retry on the next refresh/foreground pass, with the failure reported through sync health.

## Verification

- Source: `9c5d8aa` plus the existing working tree and this fix; version/build unchanged at 1.1.3 (1789570067).
- Saved Sports iPhone 17 Pro Max simulator, iOS 26.5, `B8CD88B2-D876-49ED-8CB8-303A0C59FEC5`.
- All 76 unit tests passed, including 8 new notification timing/repair tests. These cover the original 90-minute failure and corrected 30-minute result, additional travel zones, all active reminder offsets, seconds/year boundaries, autumn daylight-saving transition, upgrade repair inside the fetch throttle, retry/idempotency, Off/cancellation/past events, denied permission, and mock isolation.
- Debug app/widget test build and unsigned Release app/widget build passed. Release validation uses the same unsigned device-build configuration as the repository verifier; no commit or release was performed. The existing StoreService actor-isolation warning remains.
- Unit results: `/private/tmp/sports-reminder-timezone/UnitTests.xcresult`.
- Both native UI tests passed in isolated mock mode: changing Reminder to Off, then selecting 30 minutes, relaunching, and confirming the saved value and selected picker row. The initial walkthrough assertions were corrected to handle tapping an already-selected option and to read the Picker's accessibility value separately from its label. The final screenshot was inspected. The installed app's debug library hash matches the new build; Settings was left open on the saved simulator.
- UI results: `/private/tmp/sports-reminder-timezone/ReminderUI-Final.xcresult`; screenshot: `/private/tmp/sports-reminder-timezone/FinalUIAttachments/D983F88B-5013-4DC0-89AA-DB2C88D9998C.png`.
- Build logs: `/private/tmp/sports-reminder-timezone-tests.log` and `/private/tmp/sports-reminder-timezone-release.log`.

## Delivery limits

This change has not been uploaded to App Store Connect. After receiving the fixed version, existing users need to open the app to repair pending legacy reminders. Notifications already delivered cannot be undone.

## Opt-in physical-device match check

On September 16, the fixed Debug app, version 1.1.3 (1789570067), was installed on Keith's connected iPhone 16 Pro. `LiveReminderDeliveryTests.testScheduleRealMatchNotification` passed using the real UserNotifications center and production reminder builder. The iPhone reported one pending test request with an explicit GMT time zone and next trigger `2026-09-16T22:30:00Z` (3:30 p.m. Pacific / 5:30 p.m. Chicago).

The fixture is Columbus Crew–Orlando City SC in the U.S. Open Cup, ESPN event `401874270`, kickoff `2026-09-16T23:00:00Z`. Sources: ESPN's `usa.open/scoreboard?dates=20260916` endpoint and the Columbus Crew's official semifinal announcement. The test request identifier is `game-delivery-check-401874270`; no followed teams or calendar events were added. Device reports include only this dedicated request. The temporary test-run configuration removes the scheme's `-seed-data` argument.

Keith kept the phone's time zone unchanged because he was working and needed his schedule unaffected. The physical test therefore checks real notification delivery at the scheduled instant; the travel/time-zone regression remains covered by the automated tests above.

Result: passed at the screenshot's minute-level precision. Keith supplied a September 16 Lock Screen screenshot showing 3:32 p.m. and the Columbus Crew–Orlando City SC notification marked “2m ago,” with subtitle “U.S. Open Cup (reminder test)” and body “Kickoff — 30 min before.” This is consistent with the expected 3:30 p.m. Pacific delivery, 30 minutes before the confirmed 4:00 p.m. kickoff. The screenshot does not establish the exact delivery second, and no post-delivery device query was performed. No phone time-zone change or calendar modification was required.

The two `LiveReminderDeliveryTests` cases skip unless `SPORTS_REMINDER_CHECK_PAYLOAD` supplies an explicitly authorized match as JSON (`eventID`, `home`, `away`, `league`, `kickoff` with ISO8601 seconds). They schedule or inspect only the dedicated test notification. To inspect delivery, run only `testInspectRealMatchNotification`, preserving the existing request, and inspect `Documents/reminder-delivery-check.json`. A notification cleared by the user may no longer appear in delivered notifications.

Temporary configuration: `/private/tmp/sports-reminder-device/DerivedData/Build/Products/SportsReminderLiveCheck.xctestrun`. Schedule result: `/private/tmp/sports-reminder-device/ScheduleLiveMatch.xcresult`. Build/scheduling logs: `/private/tmp/sports-reminder-device-build.log`, `/private/tmp/sports-reminder-device-schedule.log`.
