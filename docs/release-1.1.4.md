# Sports Calendar Sync 1.1.4

- Simplify Calendar Sync settings with one action to refresh and repair your events.
- Keep calendar sync active for followed teams whenever Calendar access is allowed.
- Improve feedback when Calendar access is unavailable or no teams are followed yet.

## Release validation

- The calendar settings changes passed 76 unit tests and a focused native Simulator UI test; two opt-in physical-device notification checks were skipped.
- Keith reviewed the updated local app and approved the changes.
- Production bundle: `com.keithbarney.sportssync`; local development bundle: `com.keithbarney.sportssync.local`.
- Production calendar: Sports; local development calendar: Sports (L).
- Release build: `1790809115`.

## Submission record

- Production archive completed from the clean release snapshot `5fa34ad`.
- Build `1790809115` uploaded successfully, processed as VALID/App Store eligible, and attached to the 1.1.4 draft.
- Export compliance: no non-exempt encryption. Existing review contact and app metadata are present.
- Release mode remains automatic after Apple approval (`AFTER_APPROVAL`).
- All 24 core screenshots refreshed and validated across iPhone/iPad × Light/Dark. App Store selection: six Light cards per device. The 12 selected screenshots processed successfully; exact order and MD5 checksums were verified in App Store Connect.

- Submitted to App Review September 30, 2026 at 4:38 PM PDT. Both version and review submission states verified as `WAITING_FOR_REVIEW`.
- App Store version ID: `1b517d4d-571d-4c0d-8b54-2d05b509692d`.
- Build ID: `b1c26094-b6d1-4a79-a7a5-ec9f73b7fefb`.
- Review submission ID: `79864f5d-12b6-4962-8d3d-356adcc24c44`.
- Source files for the production app/widget matched the archived snapshot after screenshot work (223 files checked).

## Signing recovery

Xcode automatic export selected a newer installed distribution certificate than the Xcode-managed profiles contained. Created App Store profiles for the existing app and widget bundle IDs using that installed certificate, then exported this same archive with manual signing. No production capabilities were removed. Keep profile/certificate files and API credentials outside Git.

For future matched-profile exports, `APPSTORE_EXPORT_OPTIONS_PLIST` can point to an external plist without putting profiles or credentials in the repository. `scripts/release.sh` passed Bash syntax validation after adding this override.
