---
stack: swiftui
fileKey: TBD
tokenFile: SportsCalendarSync/Extensions/Color+Theme.swift
sectionBgVariable: bg/background
defaultMode: dark
screenOrder:
  - ScreenUpcoming
  - ScreenDiscover
  - ScreenTeamDetail
  - ScreenSettings
---

## Components

| Figma Component | Node ID | Code File | Code Name |
|-----------------|---------|-----------|-----------|
| FeedRow | TBD | SportsCalendarSync/Views/Components/FeedRow.swift | FeedRow |
| .FeedRowTrailing | TBD | SportsCalendarSync/Views/Components/FeedRowActionButton.swift | FeedRowActionButton |
| MatchRow | TBD | SportsCalendarSync/Views/Components/MatchRow.swift | MatchRow |
| TeamRow | TBD | SportsCalendarSync/Views/Components/TeamRow.swift | TeamRow |
| CrestView | TBD | SportsCalendarSync/Views/Components/CrestView.swift | CrestView |
| LeagueChip | TBD | SportsCalendarSync/Views/Components/LeagueChip.swift | LeagueChip |
| FormRow | TBD | SportsCalendarSync/Views/Components/FormRow.swift | FormRow |
| StandingsRow | TBD | SportsCalendarSync/Views/Components/StandingsRow.swift | StandingsRow |
| BroadcastBadge | TBD | SportsCalendarSync/Views/Components/BroadcastBadge.swift | BroadcastBadge |
| ScreenUpcoming | TBD | SportsCalendarSync/Views/UpcomingView.swift | UpcomingView |
| ScreenDiscover | TBD | SportsCalendarSync/Views/DiscoverView.swift | DiscoverView |
| ScreenTeamDetail | TBD | SportsCalendarSync/Views/TeamDetailView.swift | TeamDetailView |
| ScreenSettings | TBD | SportsCalendarSync/Views/ProfileView.swift | ProfileView |
| FloatingTabBar | TBD | SportsCalendarSync/ContentView.swift | FloatingTabBar |
| SegmentedFilter | TBD | SportsCalendarSync/ContentView.swift | SegmentedFilter |
| ActionButton | TBD | SportsCalendarSync/Views/Components/ActionButton.swift | ActionButton |
| EmptyState | TBD | SportsCalendarSync/Views/Components/EmptyState.swift | EmptyState |
| SettingsRow | TBD | SportsCalendarSync/Views/Components/SettingsRow.swift | SettingsRow |
| SearchBar | TBD | SportsCalendarSync/Views/Components/SearchBar.swift | SearchBar |
| ToastView | TBD | SportsCalendarSync/Views/ToastView.swift | ToastView |
| SkeletonView | TBD | SportsCalendarSync/Views/Components/SkeletonView.swift | SkeletonView |
| MatchRowSkeleton | TBD | SportsCalendarSync/Views/Components/SkeletonView.swift | MatchRowSkeleton |
| TeamDetailSkeleton | TBD | SportsCalendarSync/Views/Components/SkeletonView.swift | TeamDetailSkeleton |

## Text Styles

Port from ShowSync (identical scale).

| Figma Style | SwiftUI |
|-------------|---------|
| Title 1 | .system(size: 28, weight: .bold) |
| Title 2 | .system(size: 22, weight: .bold) |
| Title 3 | .system(size: 20, weight: .bold) |
| Title 4 | .system(size: 18, weight: .semibold) |
| Headline | .system(size: 17, weight: .semibold) |
| Body | .system(size: 17) |
| Callout | .system(size: 16) |
| Callout Emphasized | .system(size: 16, weight: .semibold) |
| Subheadline | .system(size: 15) |
| Subheadline Emphasized | .system(size: 15, weight: .medium) |
| Body Small | .system(size: 14) |
| Body Small Emphasized | .system(size: 14, weight: .semibold) |
| Button | .system(size: 14, weight: .medium) |
| Footnote | .system(size: 13) |
| Caption 1 | .system(size: 12) |
| Caption 2 | .system(size: 11) |
| Overline | .system(size: 11, weight: .semibold) |

## Component States

| View | Skeleton | Empty | Error | Reason |
|------|----------|-------|-------|--------|
| Upcoming (Home) | — | EmptyState | — | SwiftData query, no network calls |
| Discover (Teams by League) | MatchRowSkeleton | EmptyState | — | ESPN `/teams` fetch |
| Team Detail | TeamDetailSkeleton | — | — | ESPN team + schedule fetch |
| Search Results | MatchRowSkeleton | — | — | Client-side filter on cached team list |
| Settings | — | — | — | Static content |

## Token Overrides

| Figma Variable | Code Token | Notes |
|----------------|-----------|-------|
| semantic/result-win | Color.green | FormRow W pill |
| semantic/result-draw | Color.gray | FormRow D pill |
| semantic/result-loss | Color.red | FormRow L pill |
| league/mls | TBD | Per-league accent |
| league/epl | TBD | Per-league accent |
| league/laliga | TBD | Per-league accent |
| league/bundesliga | TBD | Per-league accent |
| league/seriea | TBD | Per-league accent |
| league/ligue1 | TBD | Per-league accent |
