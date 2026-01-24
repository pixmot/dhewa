# Agent Rules (Ordinatio)

- Create short, one-line, standard atomic commits for each change.

## Swift / SwiftUI
- Targets: Ordinatio app assumes iOS 17+; OrdinatioCore stays iOS 16+. Guard newer APIs with availability + fallback.
- Prefer Observation + Swift Concurrency (`@Observable/@Bindable`, `async/await`, `AsyncSequence`); avoid new Combine/callback APIs.
- Actor hygiene: UI state is `@MainActor`; never block the main actor with DB/file/network or heavy formatting.
- Dependencies: no singletons; inject dependencies via initializers/Environment; keep OrdinatioCore free of SwiftUI/app types.
- Concurrency: prefer structured concurrency; avoid `Task.detached` unless required; handle cancellation and avoid task leaks.
- Data access: app uses `DatabaseClient` only; keep GRDB imports/queries confined to OrdinatioCore.
- Formatting: prefer `FormatStyle` (`Date.FormatStyle`, `Decimal.formatted`) over formatters; if using `DateFormatter/NumberFormatter`, cache them and never allocate in `View.body`.
- View performance: keep `body` cheap + side-effect free; avoid expensive work in computed properties used by `body`; precompute/cache off-main.
- Lists: use stable identities from real ids; avoid index-based ids; use `id: \\.self` only for fixed, unique primitives (e.g. enums, keypad digits).
- Navigation/presentation: use `NavigationStack`/`navigationDestination`; prefer state-driven `.sheet(item:)` modals.
- UIKit: avoid new UIKit; allow small UIKit bridging (e.g. dynamic colors) or tiny representables when strictly necessary.
- Design consistency: use `OrdinatioColor`, `OrdinatioMetric`, and shared typography; avoid hard-coded colors/spacing/fonts.
- Accessibility/testing: add `accessibilityLabel` + `accessibilityIdentifier` for interactive/tested UI; support Dynamic Type and Reduce Motion.
- Quality: keep builds warning-free (especially Swift 6 concurrency/Sendable); no `print`; use `Logger` when needed; add/extend tests for new logic.
- Error handling: no `try!`/`fatalError` in production paths; show user-safe errors; log failures with context and avoid sensitive data in logs.
- Migrations: schema changes are additive and versioned; add migration tests; never rely on "reset DB" to fix production issues.
- Tests: cover new logic/bugs (esp. money/date parsing and DB queries); keep tests deterministic (fixed locale/time zone/calendar when relevant).
- CI discipline: treat warnings as errors in CI; keep strict concurrency checks enabled; no warning regressions.
- GRDB (OrdinatioCore): prefer `ValueObservation/AsyncValueObservation`; avoid `.immediate` unless started on main; keep observation queues serial + cancelable.
