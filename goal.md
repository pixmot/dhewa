Below is a **very detailed, milestone-based plan** for building an **offline-first iOS finance tracker** with **real collaboration (couples/families)** and a **Rust sync backend optimized for low allocations + high throughput**.

I’m going to assume (so we can be concrete):

* iOS-only for now, **iOS 16+** (Swift Concurrency, background tasks).
* **Manual entry first** (no bank connections in early milestones).
* Multi-household support (e.g., “Family”, “Roommates”).
* Multi-currency supported at the transaction level (amount stored in minor units + currency code).
* Privacy-first: no selling data; minimal analytics.

If any of those assumptions differ, the plan still holds—just adjust some scope.

---

## Business scope and product boundaries

### Vision

A **local-first** personal finance tracker that becomes a **shared ledger** for couples/families—fast, simple, and trustworthy—where collaboration doesn’t break offline usage.

### Target users

* Couples sharing everyday spending
* Families tracking household spending + allowances
* Roommates splitting shared expenses (optional later)

### Primary differentiators (what you’re “about”)

1. **Collaboration done right**: shared households, roles, invites, near-real-time sync, conflict safety.
2. **Offline-first**: the app is fully functional with no internet.
3. **Trustworthy data model**: finance-grade correctness (no silent overwrites of money/date fields).
4. **Performance**: instant UI, smooth scrolling, efficient sync, cheap backend.

### MVP feature boundaries (early)

**In-scope early**

* Manual transactions (income/expense)
* Categories
* Budgets (basic)
* Shared household ledger with invites
* Sync + conflict detection

**Explicitly out-of-scope early (to avoid exploding complexity)**

* Bank connections (Plaid, etc.)
* Investment tracking
* Tax features
* AI categorization
* Full web app

### Monetization (business plan options)

Pick one early and build with it in mind (paywall boundaries + entitlements):

* **Freemium** (recommended):

  * Free: personal ledger, 1 household, limited history/export
  * Pro: multiple households, recurring rules, advanced analytics, attachments/receipts, unlimited export, widgets
* **Subscription-only**:

  * Harder to grow early; better for remembering revenue
* **One-time purchase**:

  * Great UX, but tough to sustain if you run a server

### Legal + trust basics

* Clear disclaimer: “not financial advice”
* Privacy policy + data deletion policy (important if you store any data)
* Security posture from day 1: TLS, token auth, backups, audit logging

---

## Core technical architecture (stable foundations)

### High-level design

* **iOS app**

  * Local SQLite (GRDB recommended) is the source-of-truth for UI
  * Writes generate local “operations” in an **outbox**
  * Sync engine:

    * Push outbox ops when online
    * Pull remote changes since last known sequence
  * Conflict resolution UI for meaningful collisions

* **Rust backend (sync + auth + collaboration)**

  * Stateless HTTP API (Axum/Hyper)
  * Postgres as canonical store
  * Append-only **change log** (oplog) per household to support incremental pulls

### Sync approach (why this one)

* Not “timestamp sync” (bad for deletes + clock skew)
* Not full CRDT (overkill for this domain)
* Use:

  * **Entity versions** + optimistic concurrency for conflict detection
  * **Idempotent ops** to safely retry
  * **Change log sequence** to pull deltas efficiently

### Data correctness rules (finance-grade)

* Store money as **integer minor units** (cents) + currency code
* Don’t silently merge/overwrite:

  * `amount`, `currency`, `date`, `category`
* Conflicts must be surfaced and resolved explicitly

---

# Milestone plan (very detailed)

## Milestone 0 — Product definition + engineering foundations

### Business deliverables

* Define your “One Sentence Promise”:

  * Example: “A lightning-fast offline finance tracker that couples can share without data loss.”
* Define the **MVP user journeys**:

  1. Create account → create household → invite partner → both add transactions → see updates
  2. Offline usage → add/edit → later sync → handle conflicts if needed
* Define success metrics (for internal measurement):

  * Activation: created household + added 5 transactions
  * Collaboration: invited member accepted + both have synced within 24h
  * Retention: 7-day retention
* Decide monetization boundary (free vs pro) even if you don’t implement payments yet.

### Technical deliverables

* Repo + CI:

  * Separate repos or monorepo (either works)
  * CI runs: formatting, linting, unit tests, integration tests
* Coding standards:

  * Swift: SwiftLint + formatting
  * Rust: `rustfmt`, `clippy`, deny warnings in CI
* Architecture docs:

  * System overview
  * Data model v0
  * Sync protocol v0
  * Threat model v0 (what you protect, what you don’t)

### Key decisions to lock

* ID format:

  * ULID or UUIDv7-style IDs generated on device (offline-friendly)
* iOS DB library:

  * **GRDB** for predictable performance + explicit control (recommended)
* Backend:

  * Axum + sqlx + Postgres
* Sync conflict stance:

  * “Do not silently overwrite sensitive finance fields.”

**Definition of done**

* Written spec for entities + sync algorithm + MVP flows
* Minimal wireframes for core screens (list, add/edit, budgets, households)

---

## Milestone 1 — iOS Local-First App (no server yet)

**Goal:** a fully usable offline tracker that feels instant.

### iOS app scope

#### Data model (local)

* Households (local concept initially)
* Categories
* Transactions
* Budgets

#### Screens

* Onboarding (local-only, stub auth)
* Transaction list

  * Date grouping
  * Filters (category, amount range, member placeholder)
  * Search (note)
* Add/edit transaction

  * amount, currency, date, category, note
* Categories management
* Budgets view (simple monthly budget totals)
* Settings (export, data reset)

#### Storage & performance

* SQLite schema with indexes:

  * `transactions(household_id, txn_date)`
  * `transactions(category_id, txn_date)`
  * `transactions(updated_at)` (for local needs)
  * `categories(household_id, sort_order)`
* Denormalize carefully:

  * Keep canonical source fields in tables
  * Derived values (monthly totals) computed on demand or cached

#### Correctness rules

* Amount entered as decimal → convert to integer minor units
* Enforce currency code; never “guess”
* Date semantics:

  * store `txn_date` as a date-only concept (year-month-day)
  * store `created_at/updated_at` as UTC timestamps

### Quality

* Unit tests for:

  * amount parsing/formatting
  * budget calculations
  * category ordering
* Basic UI tests:

  * add/edit flow
  * list updates

**Definition of done**

* App works entirely offline and persists correctly
* Scrolling a large list remains smooth
* No server code required yet

---

## Milestone 2 — Backend Foundation (Auth + Tenancy + Skeleton APIs)

**Goal:** you can create users, households, and authenticate requests.

### Backend scope (Rust)

#### Core crates and patterns (performance-minded)

* Axum + Hyper
* Tokio multi-thread runtime
* Use `bytes::Bytes` and avoid request-body copies
* Strict request size limits (protect memory)
* Structured logging with `tracing`
* Metrics endpoint (Prometheus-style) or basic counters

#### Authentication

* Sign in with Apple:

  * verify identity token server-side
  * create/find user
  * issue access token (JWT) + refresh token
* Token strategy:

  * short access token
  * refresh token stored hashed in DB (so leaks are less catastrophic)
* Device identity:

  * client generates `device_id` once and stores in Keychain
  * sent with sync calls (helps debugging & future device-based acknowledgements)

#### Collaboration primitives

* Households:

  * create household
  * list households for user
* Membership + roles:

  * owner/admin/member

#### Database schema (server)

* `users`
* `households`
* `household_members`
* (empty for transactions until next milestones)

#### Infra basics

* Container image build
* Migration tool:

  * sqlx migrations
* Deployment:

  * single instance is enough early
* Backups (even now):

  * automated daily snapshots (managed) OR nightly dump to object storage

**Definition of done**

* iOS can log in and call “list households”
* Backend has health check + logs + basic metrics
* DB has automated backups enabled

---

## Milestone 3 — Sync V1 (Single-user correctness first)

**Goal:** push/pull sync works for one user on multiple devices (same account).
This removes collaboration complexity while you harden the sync engine.

### Sync protocol (v1)

#### Entities synced

* categories
* transactions
* budgets (optional in v1, can be v1.1)

#### Server-side requirements

* Canonical tables:

  * `categories`, `transactions`, `budgets`
* Versioning:

  * Each row has `version INT NOT NULL`
  * Update increments version
* Deletes:

  * Soft-delete: `deleted_at` timestamp
* Change log:

  * `change_log(seq BIGINT, household_id, op_id, entity_type, entity_id, action, payload, actor_user_id, device_id, server_ts)`

#### Client-side requirements

* Local tables store:

  * `server_version`
  * `deleted_at`
* Outbox table:

  * `op_id, household_id, entity_type, entity_id, action, base_version, patch, client_ts`
* Sync state:

  * `last_seq` per household

### Endpoints

* `POST /sync/push`

  * request: batch of ops
  * response: applied op_ids, conflicts (if any), latest_seq
* `GET /sync/pull?household_id=…&since_seq=…&limit=…`

  * response: ordered change_log entries

### Conflict handling in V1

Even single-user can have conflicts across devices:

* if `base_version != current_version`:

  * return conflict entry
  * do not apply sensitive updates automatically

### Implementation details (server) — performance & low allocations

* Parse request body once into a borrowed/owned struct:

  * Avoid intermediate JSON `Value`s
  * Prefer typed structs with small enums, numeric codes, `Cow<str>` where possible
* Apply ops in a single DB transaction:

  * membership check once
  * for each op:

    * use `UPDATE ... WHERE id=$id AND version=$base_version`
    * check affected rows
    * insert into `change_log` only on success
* Idempotency:

  * `op_id` unique constraint
  * if insert fails due to duplicate `op_id`, treat as already applied

### iOS sync engine

* Scheduler triggers:

  * foreground
  * after local write (debounced)
  * background refresh
  * when network returns
* Push loop:

  * take N outbox ops
  * push
  * mark applied ops as done
  * store conflicts
* Pull loop:

  * pull since last_seq
  * apply in order in one SQLite transaction
  * update last_seq

### Testing (non-negotiable)

* Integration tests for:

  * idempotent retry of push
  * out-of-order delivery handling
  * delete vs update collisions
* Property-based tests for sync invariants:

  * “After push+pull, both devices converge (except unresolved conflicts).”

**Definition of done**

* Two devices under same account converge reliably
* Conflicts are detected and recorded, not silently overwritten
* Sync survives flaky network and retries without duplicates

---

## Milestone 4 — Collaboration (Households, Invites, Multi-user)

**Goal:** couples/families can share a ledger.

### Business scope

* Household creation + naming
* Invite flows:

  * generate invite link/code
  * accept invite
* Roles:

  * owner/admin/member
* Basic shared views:

  * show who added/edited a transaction (optional but helpful for trust)

### Backend scope

* `invites` table:

  * `invite_id`, `household_id`, `token_hash`, `expires_at`, `created_by`
* Endpoints:

  * `POST /households/{id}/invites`
  * `POST /invites/accept`
  * `GET /households/{id}/members`
  * `DELETE /households/{id}/members/{user_id}` (role-checked)
* Permission enforcement:

  * Every sync op checks household membership and role rules

### iOS scope

* Household switcher UI
* Invite UI:

  * share link/code
  * accept flow
* Member list UI (owner/admin only)
* “Added by” / “Last edited by” display (at least in detail view)

### Sync changes

* Same sync engine, but now multiple users write to the same household.
* Conflicts become more common → ensure conflict UI is on roadmap soon.

**Definition of done**

* Two different users in the same household see each other’s transactions after sync
* Permissions enforced (non-members can’t sync household data)

---

## Milestone 5 — Conflict Resolution UX + Audit History (Trust milestone)

**Goal:** make collaboration safe for finance data.

### Conflict categories

Define “sensitive fields” per entity:

* Transactions: amount, currency, txn_date, category_id
* Budgets: amount, period
* Categories: name (less sensitive but still)

### Server conflict records

* `conflicts` table:

  * `conflict_id`, `household_id`, `entity_type`, `entity_id`
  * `server_version`, `client_base_version`
  * `server_snapshot` (jsonb)
  * `client_patch` (jsonb)
  * `created_at`, `created_by`
* Push response includes conflict summaries so clients can fetch details if needed.

### iOS conflict UI

* “Conflicts” inbox:

  * list of conflicts with entity summary
* Conflict detail:

  * show “Mine vs Theirs”
  * actions:

    * keep server
    * keep mine (re-apply as a new op based on latest version)
    * manual merge (edit fields and save)
* After resolution:

  * create a new op with `base_version = latest_server_version`

### Audit history (lightweight but powerful)

* Keep `change_log` as your audit trail.
* In iOS, allow:

  * “View history” for a transaction (optional)
  * Show last editor + timestamp

**Definition of done**

* Users can safely resolve conflicts without losing money/date integrity
* Support can debug issues using change_log + device_id

---

## Milestone 6 — Push Notifications for Near-real-time Collaboration

**Goal:** “It feels live” without polling.

### Backend

* Store device push tokens:

  * `device_tokens(device_id, user_id, token, platform, updated_at)`
* On successful op apply:

  * notify other household members’ devices (silent push)
  * payload: `household_id`, `latest_seq`
* Rate limit pushes (avoid storms):

  * batch notifications (coalesce within short window)
  * don’t notify the device that performed the write

### iOS

* Register APNs token
* Silent notification handler:

  * schedule a pull (respect background limits)
* UI:

  * subtle “Synced just now” indicator

**Definition of done**

* Partner adds a transaction and you see it appear shortly after (even if you didn’t open the app)
* Backend costs stay controlled (no push storms)

---

## Milestone 7 — Performance + Cost Optimization (Rust “very low allocations” emphasis)

**Goal:** keep hosting cheap and the backend extremely efficient under load.

### Backend performance checklist

#### Request/response efficiency

* Batch ops (already)
* Enforce size limits (hard cap on ops and bytes)
* Response compression:

  * gzip is simplest; brotli optional
* Consider alternative encodings:

  * **Phase A**: JSON (fast enough for most)
  * **Phase B**: CBOR/MessagePack optional content-type to reduce CPU/bytes

    * Keep the API shape identical

#### Allocation control (Rust)

* Prefer borrowed deserialization when possible:

  * `#[serde(borrow)]` + `Cow<'a, str>` for string fields
* Avoid cloning `String` / `Vec`:

  * pass references through layers
  * use `Bytes` for request bodies and raw payload buffers
* Avoid building large in-memory structures:

  * stream where possible, or process ops iteratively
* Use a fast allocator only if profiling proves it helps (don’t guess)
* Use `smallvec` where arrays are tiny (e.g., small patches), but measure.

#### DB efficiency

* Use prepared statements (sqlx handles)
* Make sure indexes match pull queries:

  * `change_log(household_id, seq)`
* Consider partitioning `change_log` by time if it grows large (later)
* Add **bootstrap endpoint** to avoid infinite change_log retention:

  * `GET /sync/bootstrap` returns full snapshot for a household
  * Keep change_log retention window (e.g., last N days or last N seq)
  * If device is too far behind, require bootstrap

#### Load testing & profiling

* Define SLAs (internal):

  * push latency P95 target
  * pull latency P95 target
* Use:

  * `cargo flamegraph` / `pprof`
  * DB query analysis (EXPLAIN)
* Run synthetic load tests:

  * many households
  * many ops
  * bursty push patterns (realistic)

### iOS performance checklist

* DB transactions around bulk applies
* Debounce writes for sync
* Efficient list rendering:

  * avoid recalculating aggregates on every render
* Precompute monthly summaries when needed (cache table) if required

**Definition of done**

* Sync endpoints stay fast under load tests
* Memory usage remains stable with request size caps
* DB size growth controlled via bootstrap + retention strategy

---

## Milestone 8 — “Real Couples/Family Features” (Business value expansion)

**Goal:** features that specifically make collaboration worth paying for.

### Features (prioritized)

1. **Split transactions**

   * Split by ratio or fixed amounts among members
   * Track “who paid” vs “who owes”
2. **Allowances / pocket money**

   * Parent sets monthly allowance budget per child
3. **Shared goals**

   * e.g., vacation fund spending category with budget and progress
4. **Receipts (attachments)**

   * Photos stored in object storage, metadata in DB
5. **Export**

   * CSV export for household
   * Month/year filters

### Sync considerations

* Split rules must be deterministic and stored as canonical data
* Attachments:

  * upload to object storage
  * store key + hash + size in DB
  * sync metadata via ops

**Definition of done**

* Collaboration feels meaningfully better than a solo tracker
* These features can be used as Pro upsell

---

## Milestone 9 — Billing, Entitlements, and Business Operations

**Goal:** convert users to revenue cleanly and safely.

### iOS

* In-app purchases/subscriptions
* Paywall screens
* Restore purchases
* Entitlement gating:

  * multiple households
  * advanced analytics
  * attachments
  * export limits, etc.

### Backend

* Receipt validation (optional but recommended)
* Store entitlements per user
* Rate-limits / quotas tied to plan (fair use)

### Operations

* Support tools:

  * “export my data”
  * “delete my account & household”
* App Store metadata, onboarding, email support workflows

**Definition of done**

* Users can pay and features unlock reliably across devices
* You can handle refunds/restore without drama

---

## Milestone 10 — Security Hardening + Compliance Readiness

**Goal:** ensure you’re not a “toy app” security-wise.

### Security baseline

* TLS everywhere
* Token rotation
* Strict authorization checks in every endpoint
* Rate limiting and abuse protection
* Secrets management (no secrets in env files checked into repo)
* Regular dependency scanning

### Privacy/compliance features

* Data deletion (GDPR-like):

  * delete account
  * leave household
  * owner deletes household
* Data export
* Incident response basics:

  * logging retention policy
  * access controls for production DB

### Optional: End-to-end encryption (E2EE)

This is possible but adds complexity with collaboration (key sharing, recovery).
If you want E2EE:

* Each household has an encryption key
* Members exchange key material securely (e.g., via public-key envelopes)
* Server stores only ciphertext for sensitive fields

I’d treat this as an advanced milestone unless privacy is your #1 differentiator.

**Definition of done**

* You can confidently answer: “How is data protected?”
* You can execute deletion/export requests correctly

---

# Extra: Concrete “Definition of Done” invariants (keep these sacred)

These are rules you enforce with tests:

1. **Local-first**: UI reads from local DB only.
2. **Idempotency**: repeating the same push batch does not duplicate data.
3. **Convergence**: after push+pull with no unresolved conflicts, devices match.
4. **No silent money overwrites**: conflicts are explicit for amount/date/currency/category.
5. **Durability**: backups exist and restore is tested (at least once).

---

# Recommended implementation order (fastest path to a “real” collaborative app)

If you follow the milestones above, the fastest “real collaboration” path is:

1. Milestone 1 (local tracker)
2. Milestone 2 (auth + households skeleton)
3. Milestone 3 (sync V1 single-user)
4. Milestone 4 (multi-user households)
5. Milestone 5 (conflict UX)
6. Milestone 6 (push notifications)
7. Milestone 7 (performance/cost hardening)

This sequence minimizes “rewrite risk.”

---

If you want, I can also produce (in the same level of detail):

* A full **Postgres schema (DDL)** for all entities + change_log + conflicts + invites
* A precise **sync API contract** (request/response JSON plus an optional CBOR variant)
* A recommended **Swift GRDB schema + migrations** and “Outbox write service” pattern
* Rust handler pseudocode that’s optimized for low allocations (including idempotency + optimistic concurrency)
