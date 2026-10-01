# Sports Calendar Sync organic search experiment

Prepared September 30, 2026. Status: reviewable preparation; not launched. Experiment release date: **not yet released**. No App Store metadata, build, review submission, ads, or purchases changed in this task.

September 30 execution update: Keith approved proceeding with this experiment (“ok do it”). Discovery found another active, user-authorized release in the chat “Fix duplicate calendar events,” preparing 1.1.4 (1790809115) in `/private/tmp/sports-appstore-release-1.1.4`. Do not create a competing release or mutate its snapshot. Coordination authorization is pending. The subtitle should be applied to that release if coordinated before submission; its app changes and refreshed screenshots are known confounders and must be recorded in the comparison. The earlier metadata-only release assumption is superseded by this concurrent release discovery.

## One hypothesis and exact change

For US English users looking for soccer schedules and kickoff reminders, a specific subtitle will communicate relevance more clearly than the current generic fixture-sync subtitle, and may improve search acquisition and first-time downloads.

Change only the **en-US subtitle** in the next validated release:

| Field | Current | Proposed | Characters / limit |
| --- | --- | --- | --- |
| Subtitle | Auto-sync fixtures to calendar | Soccer schedules & reminders | 30 → 28 / 30 |
| Name | Sports Calendar Sync | Keep current | 20 / 30 |
| Keywords | soccer,football,MLS,calendar,schedule,fixtures,premier league,bundesliga,laliga,serie a | Keep current | 87 / 100 |

The title supplies the calendar-sync benefit; the subtitle identifies the actual sport and two supported uses. This is a hypothesis about relevance and communication, not a verified keyword-volume or ranking claim. Soccer and schedule already occur in the keyword field, so this is not a claim that the app becomes newly eligible for those queries. Do not simultaneously optimize the keyword field, title, screenshots, promotional text, description, price, or other locales. The current keyword field duplicates calendar from the name and could be cleaned up later as a separate experiment.

Rollback copy: `Auto-sync fixtures to calendar`. A post-release rollback also requires Apple's applicable metadata/review workflow; do not promise an instant rollback.

## Evidence and listing accuracy

- Inspected the [live US listing](https://apps.apple.com/us/app/sports-calendar-sync/id6763406189) directly in Chrome on September 30. It shows version 1.1.3, dated September 16. App Store Connect shows 1.1.3 Ready for Distribution, build 1789570067. The browser's current description matches Connect. The web-search crawl returned an older description, so it was not used as the current listing evidence.
- The live description identifies soccer clubs, supported leagues/cups, calendar events, reminders, and broadcast information when available. These are consistent with the repository's supported product scope. It does not promise every sport or universal broadcasts. Opening/manual refresh language is more accurate than the obsolete crawled promise of guaranteed daily automatic updates. No additional accuracy edit is needed for this experiment.
- The US public page has insufficient ratings for an overview. Connect's all-territory review view has one four-star rating and one August 24 review from the UAE, version 1.0, requesting a separate upcoming-matches view and league schedules. This supports schedule vocabulary but is a single non-US observation, not evidence of US demand. No reply was sent.
- `docs/feedback.md` documents fixture-reporting, sync-problem feedback and a local survey. It contains no collected response dataset, and no private mailbox or personal app stores were accessed.
- Typed `soccer` into Apple's US web App Store search input. No autocomplete phrase hints appeared in the available UI. Native iPhone search hints and popularity data remain unverified; no phrases are represented as observed hints. Do not create an advertising campaign to obtain suggestions.
- [Apple's product-page guidance](https://developer.apple.com/app-store/product-page/) recommends specific, relevant metadata; subtitle limit is 30 characters, keywords limit is 100. Subtitles update with a new version. Promotional text is not a search-ranking experiment. No competitor names or unsupported functionality are proposed.

Candidate phrases derived from the listing and review vocabulary:

| Candidate | Fit and disposition |
| --- | --- |
| soccer schedule / soccer calendar | Strong US sport + schedule/calendar intent; primary hypothesis |
| kickoff reminder / match reminder | Supported reminder use; included through subtitle language |
| football fixtures | Supported but ambiguous US football intent; retain current keywords |
| team schedule / match calendar | Relevant but broader; retain for later research |
| live scores / every sport / watch live soccer | Exclude: mismatched or unsupported promise |

These are inferred candidate phrases, not individual organic search terms from App Store Connect. Source analytics does not expose those phrases, and this test cannot measure phrase-specific acquisition.

## Captured 28-day baseline

Source: authenticated App Store Connect → Sports Calendar Sync → Analytics → Metrics. Captured September 30, 2026. Inclusive reporting range **September 2–29, 2026**, 28 complete UTC days. Filters: **Source Type = App Store Search; Region = United States**. All devices, OS versions, and product pages; no device/page/version filters. Preserve exactly these filters on follow-up.

| Metric | Connect summary | Daily observations |
| --- | --- | --- |
| Impressions (Unique Devices) | 15 daily average, rounded | 432 summed daily device counts; exact mean 15.43 |
| Product Page Views (Unique Devices) | 1 daily average, rounded | 35 summed reported daily device counts; mean 1.25 if dash days represent no activity |
| First-Time Downloads | 15 total | 15 numeric downloads across reported days |
| Conversion Rate | 4.17% displayed summary | Daily rates preserved in CSV |

See [baseline CSV](app-store-search-baseline-20260902-20260929.csv). Values were transcribed from the visible metric tables, not an Apple CSV export. `-` is preserved exactly as displayed, not converted to zero. Sums above use numeric cells only. Unique counts are unique **within each reporting day**; their sums are device-days, not 28-day deduplicated users/devices. Do not multiply rounded averages by 28 or call impressions/page views independent funnels: impressions include product page views.

[Apple's definitions](https://developer.apple.com/help/app-store-connect-analytics/reference/metrics-definitions/) define conversion using total downloads and pre-orders divided by unique-device impressions. First-time downloads / product page views is not Apple's conversion rate. Redownloads can explain conversion on days without first-time downloads. Use Apple's displayed period rate directly, rather than averaging daily percentages.

Saved query parameters for reproducing the visible metrics: `dateSpec=r:20260902:20260929`, `frequency=day`, `chartType=singleaxis`; measure keys `impressionsTotalUnique`, `pageViewUnique`, `units`, and `conversionRate`. The UI-confirmed filter payload is:

```text
NobwRA5mBcYM4HsCuAnAxgUwCoE8AOGYANGAG4zDDzLqEkDKGAhugBbFgCCeeABPQBcEKDP2ZswAXUkBfIuCiwREAJYIAdh3LRK8ISIBmKDQI4BGACwBmCxbMcAqupUCMAE34CmruFNmSgA
```

[Apple's acquisition guidance](https://developer.apple.com/help/app-store-connect-analytics/acquisition/acquisition) says App Store Search includes search-result ads. No ads were run here; historical Apple Ads inactivity has not been verified. Label these figures **App Store Search**, not proven pure organic traffic, until that is confirmed. Do not subtract unmatched ad reports or invent organic totals.

## Concrete release blockers and preparation

Connect has only the released 1.1.3 version. Subtitle and keyword fields are disabled; there is no editable next version or selected validated new build. `project.yml` also remains 1.1.3. The local checkout contains substantial existing uncommitted app, widget, test, fixture, and screenshot changes; their release readiness is not established by this task. A release from the current checkout would bundle unrelated behavior into the search experiment.

The exact subtitle and rollback are prepared above. Before launch, the release owner must select a coherent validated release scope/build and next version. Do not blindly upload the current checkout. Use the normal review/CI/QA process and `scripts/release.sh verify`, archive, then authorized upload. Confirm screenshots, privacy, release notes and compliance match the selected binary; use the shared screenshot workflow before submission. Read the shared delivery guide: Simulator and physical-phone validation, **no TestFlight**. Its no-TestFlight rule supersedes stale TestFlight instructions in `docs/RELEASE.md`.

The repository release policy states: **“Obtain explicit approval to submit the selected build to App Review.”** Preserve that checkpoint once a concrete processed build and metadata are ready. This task has no selected validated next build to bring to that checkpoint. No version number was invented, draft version created, or submission attempted. No app build is required for this documentation-only preparation.

When the new version is ready, copy only the proposed subtitle into its en-US App Information, verify all other metadata against the current fields, and obtain the required submission signoff. After approval, verify the new subtitle on the live US listing. Record version/build, submission/approval timestamps, actual first observed public subtitle timestamp in UTC and Pacific time, and release date here. Treat that public timestamp as T0, not upload/submission time.

## Several-week comparison and decision

1. Immediately before launch, capture a fresh 28-day pre-period ending before T0; this September baseline is an initial reference, not automatically the final pre-period. September 16's 1.1.3 release falls inside it and is a known confounder.
2. Allow seven complete UTC days after T0 for propagation; describe this as a practical buffer, not Apple's guaranteed indexing time. Compare the following 28 complete days with the fresh pre-period. At low volume, continue another 28 days under the same metadata if results are inconclusive.
3. Preserve daily data and report four seven-day blocks, 28-day numeric sums of daily unique metrics, exact daily means, first-time download totals, and Apple's displayed conversion rate. Use equal-length windows with the same weekday mix. Keep dashes/missing/privacy-limited values explicit; never equate unavailable data with confirmed zero.
4. Primary outcome: US search first-time downloads; supporting signals: daily unique search impressions, unique page views and Apple conversion. Look for improvement that appears across multiple weeks, not one matchday spike. Fifteen baseline downloads is too small for confident percentage claims; one extra download alone changes the total by 6.7%.
5. Record app releases, screenshot/price changes, editorial featuring, external promotion, paid-ad activity, ratings changes, league/cup fixture density and international breaks. Use US Browse/referral trends and unchanged locales as context, not randomized controls. Freeze other metadata where feasible; annotate unavoidable release changes.
6. Retain if download gains recur across weeks with compatible acquisition signals and no persistent conversion decline; extend observation if sparse/mixed; consider rollback in a reviewed release if downloads consistently fall. Document the judgment with absolute counts and uncertainty rather than declaring a win from a small percentage swing.

This is an observational before/after experiment, not a randomized causal test. Seasonality, competition and the new binary can affect results. Report “associated with” or “consistent with” improvement; do not say the subtitle caused it, increased a particular phrase's ranking, or proved organic lift. No recurring automation was requested or created; the experiment remains ready for the next release checkpoint.
