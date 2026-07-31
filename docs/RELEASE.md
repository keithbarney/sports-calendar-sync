# App Store release pipeline

The release path keeps code validation automatic while leaving production
submission as an explicit human decision.

## Release flow

1. Open a pull request. GitHub Actions regenerates the project and performs an
   unsigned iOS device build with no signing credentials.
2. Merge only after CI, code review, and QA pass.
3. Update `MARKETING_VERSION` in `project.yml` when the public version changes.
4. Verify locally:

   ```sh
   ./scripts/release.sh verify
   ```

5. Archive without uploading:

   ```sh
   ./scripts/release.sh archive
   ```

6. When the verified change is ready for TestFlight/App Store Connect, run:

   ```sh
   ./scripts/release.sh upload
   ```

   The command asks for confirmation immediately before upload. For a
   non-interactive invocation, explicit approval is represented by
   `--confirm-upload`.

The upload command runs verification, creates a signed archive, and uploads it
to App Store Connect. It deliberately does **not** select the build for an App
Store version or submit it to App Review.

The upload confirmation is also the release-owner signoff that the privacy
answers, screenshots, release notes, export-compliance answers, and other App
Store metadata are current. In a non-interactive run, `--confirm-upload`
represents the same signoff.

## One-time credential setup

App Store Connect credentials stay outside the repository:

```sh
mkdir -p ~/.config/sports-calendar-sync
cp config/appstore.env.example \
  ~/.config/sports-calendar-sync/appstore.env
chmod 600 ~/.config/sports-calendar-sync/appstore.env
```

Edit the copied file and store the `.p8` key outside the repository as well.
The API key needs an App Store Connect role capable of uploading builds.
The Mac performing the archive also needs the Apple Distribution certificate
and its private key in the keychain.
Set `APPSTORE_ENV_FILE` only when using a different external location.
If the previous workflow left `.env.appstore` in the repository directory,
move that file to the external location before archiving:

```sh
mkdir -p ~/.config/sports-calendar-sync
mv .env.appstore ~/.config/sports-calendar-sync/appstore.env
chmod 600 ~/.config/sports-calendar-sync/appstore.env
```

The CI workflow intentionally has no App Store credentials and sets
`CODE_SIGNING_ALLOWED=NO`.

## Build and version numbers

`MARKETING_VERSION` is the user-visible version and remains an explicit product
decision in `project.yml`.

The release script automatically uses the current UTC epoch second as
`CURRENT_PROJECT_VERSION`, producing a numeric, increasing build identifier
without editing source files. To reproduce or override a build:

```sh
./scripts/release.sh archive --build-number 1785432100
```

Apple requires each uploaded build string to uniquely identify the build.

## Release gates

Before upload:

- Confirm the public version in `project.yml`.
- Confirm privacy answers, screenshots, release notes, export compliance, and
  App Store metadata still match the app.

Wait for App Store Connect processing, then complete these gates before asking
for production approval:

- Review upload warnings and export-compliance status.
- Test the processed build on a physical device through TestFlight.
- Confirm permissions, calendar sync, widget behavior, and offline behavior.
- Confirm age-rating answers still match the app.
- Obtain explicit approval to submit the selected build to App Review.

Submission remains manual in App Store Connect so an upload cannot
accidentally publish or enter App Review.

## Toolchain requirement

As of April 28, 2026, Apple requires iOS uploads to be built with Xcode 26 or
later using the iOS 26 SDK or later. The script enforces both minimums and uses
the toolchain selected by `xcode-select`. Override selection with
`DEVELOPER_DIR` when necessary.

- [Apple submission requirements](https://developer.apple.com/app-store/submitting/)
- [Apple build upload guidance](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
