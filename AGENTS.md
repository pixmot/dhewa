# Agent Rules (Ordinatio)

- Create short, one-line, standard atomic commits for each change.

## Swift / SwiftUI
- Targets: Ordinatio app assumes iOS 17+; OrdinatioCore stays iOS 16+. Guard newer APIs with availability + fallback.
- Prefer Observation + Swift Concurrency (`@Observable/@Bindable`, `async/await`, `AsyncSequence`); avoid new Combine/callback APIs.
- Actor hygiene: UI state is `@MainActor`; never block the main actor with DB/file/network or heavy formatting.
- Data access: app uses `DatabaseClient` only; keep GRDB imports/queries confined to OrdinatioCore.
- Formatting: prefer `FormatStyle` (`Date.FormatStyle`, `Decimal.formatted`) over formatters; if using `DateFormatter/NumberFormatter`, cache them and never allocate in `View.body`.
- View performance: keep `body` cheap + side-effect free; avoid expensive work in computed properties used by `body`; precompute/cache off-main.
- Lists: use stable identities from real ids; avoid index-based ids; use `id: \\.self` only for fixed, unique primitives (e.g. enums, keypad digits).
- Navigation/presentation: use `NavigationStack`/`navigationDestination`; prefer state-driven `.sheet(item:)` modals.
- UIKit: avoid new UIKit; allow small UIKit bridging (e.g. dynamic colors) or tiny representables when strictly necessary.
- Design consistency: use `OrdinatioColor`, `OrdinatioMetric`, and shared typography; avoid hard-coded colors/spacing/fonts.
- Accessibility/testing: add `accessibilityLabel` + `accessibilityIdentifier` for interactive/tested UI; support Dynamic Type and Reduce Motion.
- Quality: keep builds warning-free (especially Swift 6 concurrency/Sendable); no `print`; use `Logger` when needed; add/extend tests for new logic.
- GRDB (OrdinatioCore): prefer `ValueObservation/AsyncValueObservation`; avoid `.immediate` unless started on main; keep observation queues serial + cancelable.
