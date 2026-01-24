# Agent Rules (Ordinatio)

- Create short, one-line, standard atomic commits for each change.

## Swift / SwiftUI (iOS 17+)
- Assume iOS 17+ baseline; use modern SwiftUI APIs and avoid legacy/deprecated ones.
- Prefer Swift Concurrency (`async/await`, `Task`, `AsyncSequence`) over callbacks/Combine for new code; never block the main actor with DB/file/network work.
- Prefer Observation for new state/view models (`@Observable`, `@Bindable`); avoid introducing new `ObservableObject/@Published` unless required.
- Keep `View.body` cheap: no per-render allocations (e.g. `DateFormatter`/`NumberFormatter`) and no expensive sorting/grouping; precompute/cache off the main actor.
- Lists must have stable identity (`Identifiable` with stable ids); avoid `id: \\.self` and index-based ids; keep row views lightweight.
- Keep design consistent: use `OrdinatioColor`/`OrdinatioMetric`/shared typography helpers; avoid hard-coded colors/spacing/fonts.
- Prefer SwiftUI-native components; isolate UIKit wrappers behind small `UIViewControllerRepresentable`/`UIViewRepresentable` when unavoidable.
- For GRDB reads: prefer `ValueObservation`/`AsyncValueObservation` over polling or manual notifications.
- Add accessibility labels/values + `accessibilityIdentifier` for anything tappable/tested; support Dynamic Type and Reduce Motion.
- Keep builds warning-free (especially concurrency); validate UI performance with Instruments when touching rendering-heavy paths.
