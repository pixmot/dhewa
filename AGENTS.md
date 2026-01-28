# Agent Rules (Ordinatio)

- Create short, one-line, standard atomic commits for each change.

## Swift / SwiftUI
- Targets: Ordinatio app assumes iOS 17+; OrdinatioCore stays iOS 16+. Guard newer APIs with availability + fallback.
- Prefer Observation + Swift Concurrency (`@Observable/@Bindable`, `async/await`, `AsyncSequence`); avoid new Combine/callback APIs.
- Actor hygiene: UI state is `@MainActor`; never block the main actor with DB/file/network or heavy formatting.
- Immutability: default to `let` for view inputs/dependencies/derived values and async snapshots; use `var` only for owned mutable state (`@State`, `@Observable`, local accumulators).
- Dependencies: no singletons; inject dependencies via initializers/Environment; keep OrdinatioCore free of SwiftUI/app types.
- Concurrency: prefer structured concurrency; avoid `Task.detached` unless required; handle cancellation and avoid task leaks.
- Concurrency escapes: ban `@unchecked Sendable`, `nonisolated(unsafe)`, and `DispatchQueue.main.async` "fixes" unless there is a written justification.
- Data access: app uses `DatabaseClient` only; keep GRDB imports/queries confined to OrdinatioCore.
- Determinism: avoid `Date()`, `Calendar.current`, `Locale.current`, `TimeZone.current` in core logic; inject clock/calendar/locale/time zone and fix them in tests.
- Query/perf: DB reads specify `ORDER BY`; avoid unbounded `fetchAll` on hot paths; paginate/limit and add indexes when needed.
- Formatting: prefer `FormatStyle` (`Date.FormatStyle`, `Decimal.formatted`) over formatters; if using `DateFormatter/NumberFormatter`, cache them and never allocate in `View.body`.
- View performance: keep `body` cheap + side-effect free; avoid expensive work in computed properties used by `body`; precompute/cache off-main.
- Lists: use stable identities from real ids; avoid index-based ids; use `id: \\.self` only for fixed, unique primitives (e.g. enums, keypad digits).
- Navigation/presentation: use `NavigationStack`/`navigationDestination`; prefer state-driven `.sheet(item:)` modals.
- UIKit: avoid new UIKit; allow small UIKit bridging (e.g. dynamic colors) or tiny representables when strictly necessary.
- Design consistency: use `OrdinatioColor`, `OrdinatioMetric`, and shared typography; avoid hard-coded colors/spacing/fonts.
- Localization: avoid hard-coded user-facing strings long-term; avoid string-concatenated UI; add locale-variant tests for formatting/parsing.
- Accessibility/testing: add `accessibilityLabel` + `accessibilityIdentifier` for interactive/tested UI; support Dynamic Type and Reduce Motion.
- Quality: keep builds warning-free (especially Swift 6 concurrency/Sendable); no `print`; use `Logger` when needed; add/extend tests for new logic.
- Tooling: enforce `swift-format` in CI (lint in strict mode); keep diffs small and consistently formatted.
- Observability: standardize `Logger` categories and use signposts for hot paths; integrate crash reporting when ready; never log sensitive fields.
- Error handling: no `try!`/`fatalError` in production paths; show user-safe errors; log failures with context and avoid sensitive data in logs.
- Privacy: treat notes and amounts as sensitive; do not log them; decide and enforce DB file protection and backup policy.
- Memory: no long-lived tasks without a clear owner; cancel in `deinit`/on disappear; avoid unintended strong `self` captures.
- Migrations: schema changes are additive and versioned; add migration tests; never rely on "reset DB" to fix production issues.
- Tests: cover new logic/bugs (esp. money/date parsing and DB queries); keep tests deterministic (fixed locale/time zone/calendar when relevant).
- Tests (UI): set launch arguments for fixed locale/time zone/calendar; avoid relying on simulator/device settings.
- Debug vs release: keep debug-only helpers behind `#if DEBUG`; do not ship verbose logging or debug behavior in release builds.
- CI discipline: treat warnings as errors in CI; keep strict concurrency checks enabled; no warning regressions.
- GRDB (OrdinatioCore): prefer `ValueObservation/AsyncValueObservation`; avoid `.immediate` unless started on main; keep observation queues serial + cancelable.

## Flow & Runtime
- Use repo’s package manager/runtime; no swaps w/o approval.
- Use Codex background for long jobs; tmux only for interactive/persistent (debugger/server).

## Git
- Do not modify `AGENTS.md` unless the user explicitly asks.
- Commit after each change.
- Safe by default: `git status/diff/log`. Push only when the user asks.
- `git checkout` ok for PR review / explicit request.
- Branch changes require user consent.
- Destructive ops are forbidden unless explicit (`reset --hard`, `clean`, `restore`, `rm`, ...).
- Remotes under `~/Projects`: prefer HTTPS; flip SSH->HTTPS before pull/push.
- Do not delete/rename unexpected stuff; stop and ask.
- No repo-wide S/R scripts; keep edits small/reviewable.
- Avoid manual `git stash`; if Git auto-stashes during pull/rebase, that's fine.
- If the user types a command ("pull and push"), that's consent for that command.
- Do not amend a commit unless asked.
- For big reviews: `git --no-pager diff --color=never`.

## Language/Stack Notes
- Swift: use workspace helper/daemon; validate `swift build` + tests; keep concurrency attrs right.
- TypeScript: use repo PM; run `docs:list`; keep files small; follow existing patterns.

## macOS Permissions / Signing (TCC)
- Never re-sign / ad-hoc sign / change bundle ID as “debug” without explicit ok (can mess TCC).

## Critical Thinking
- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Don’t remove changes you didn’t make.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
- Leave breadcrumb notes in thread.
