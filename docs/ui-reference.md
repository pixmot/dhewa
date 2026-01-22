# UI Reference (no code reuse)

This document is a **visual + interaction checklist** for building an Ordinatio UI with a minimal, iOS-native look and feel, while keeping our **implementation original, cleaner, and more maintainable**.

Scope: **Milestone 1** (local-only app).

## Global style

- Typography: iOS-native, **rounded** system design; strong hierarchy with one “hero” number on key screens.
- Surfaces:
  - Light mode: soft, near-white backgrounds; cards with subtle borders/shadows.
  - Dark mode: **true black** primary surface; elevated elements slightly lighter.
- Chrome: minimal; icons over text where possible.
- Motion: fast, subtle transitions; sheets feel “snappy”.

## App structure (primary navigation)

- Tabs: 4 destinations + a **center add button**.
  - `Log` (Transactions)
  - `Insights`
  - `Budgets`
  - `Settings`
- Tab bar: custom, floating feel; center “+” has higher emphasis.

## Onboarding

- Full-screen onboarding with:
  1) Welcome/branding + short feature bullets
  2) Choose default currency (searchable list)
  3) Finish → seed local data → land in Log

## Log (Transactions)

- Header summary:
  - “Net total (this week)” (or chosen period) + large amount.
  - Income/expense deltas shown with green/red.
- Search (icon/field) and filter affordances are lightweight.
- List rows:
  - Leading **icon tile** (rounded square) with a symbol + color.
  - Title (category) + optional subtitle (note/time).
  - Trailing amount, monospaced digits; color indicates income/expense.
- Grouping: Today/Yesterday/Date sections; low-contrast section headers.

## Add/Edit transaction

- Fast entry first:
  - Numeric keypad-focused amount entry (minimal friction).
  - Quick switches for Expense/Income.
  - Compact category picker and date controls.
- Full-screen or tall sheet presentation with clear primary action.

## Insights

- Period switcher (week/month/year/custom) and summary tiles.
- Simple, readable charts (bar/stacked) with category legend chips.

## Budgets

- Summary ring/hero figure near top.
- Grid/card budgets per category/currency with progress visualization.

## Settings

- List-style groups with leading icon tiles.
- “Data” actions (export/reset) clearly separated and safe.
- Categories management accessible here.

## Quality targets

- Design system tokens (`Color`, spacing, typography) to avoid magic numbers.
- Component library for:
  - Icon tiles
  - Cards
  - Summary tiles
  - Custom tab bar
- Accessibility from day 1 (Dynamic Type, VoiceOver labels, sufficient contrast).
- Cleaner state management: local view state in views; shared state via environment injection.
