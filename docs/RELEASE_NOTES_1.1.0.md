# Sports Calendar Sync 1.1.0

## What’s new

- Refreshed the app with native iOS tabs, lists, search, filters, and Settings pickers.
- Added a full-height competition management sheet for supported clubs.
- Made followed teams easier to recognize with a checkmark and Following button.
- Improved calendar repair and refresh behavior while preserving existing events.

## Validation

- All 27 unit tests passed on iOS 26.5 Simulator.
- Reviewed the native controls, competition selection, search, reminders, appearance, and Following button in Simulator and on Keith’s iPhone.
- Unsigned Release verification, signed archive, and App Store Connect upload succeeded.
- CI passed after aligning its XcodeGen version with the generated project.

App Store version: 1.1.0. Build: 1788986129. Bundle: com.keithbarney.sportssync.

The archive contains app source from bd3776dd3983895e48693d0e1a2918cd4d91c30d. The subsequent change only aligns CI’s XcodeGen version; PR #1 merged as 0ca0def1dbc83d38973100f21bb10416763fd2f5.
