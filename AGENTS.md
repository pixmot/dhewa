# Agent Rules (Ordinatio)

- Create short, one-line, standard atomic commits for each change.

## Swift / SwiftUI (iOS 17+)
- Prefer SwiftUI-first APIs and modern Swift Concurrency; avoid UIKit/Combine/GCD unless there is no practical SwiftUI alternative.
- If UIKit is unavoidable: isolate it in a small bridge file (Representable), keep the surface area minimal, and add a short comment explaining why SwiftUI cannot do it.
- Keep the UI consistent: use the design system tokens/components in `Ordinatio/DesignSystem` and avoid one-off colors/fonts/spacing in feature views.
- Keep views fast: keep `body` pure and cheap, avoid heavy work in `body`, cancel `Task` work on disappear, and avoid `AnyView`/type erasure unless required.

## Concurrency & Data
- UI state is `@MainActor`; do heavy work off-main; use structured concurrency (`async/await`) and propagate cancellation.
- For GRDB reads: prefer `ValueObservation`/`AsyncValueObservation` over polling or manual notifications.

## Quality Gates
- Keep warnings at zero; avoid force unwraps, `try!`, and `fatalError` in production paths.
- Add/update tests for behavior changes; keep UI tests stable with `accessibilityIdentifier`s.
- Before finishing: run `xcodebuild test` for the `Ordinatio` scheme (or at minimum `xcodebuild build` for non-behavioral changes).

## UX & Accessibility
- Ensure tappable controls have accessibility labels, respect Dynamic Type, and do not rely on color alone to convey meaning.
