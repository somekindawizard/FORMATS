# Fern Journaling Soul — Plan 3 of 7

> **Code-only.** Controller writes/commits; user builds in Xcode. No simulator runs from the controller.

**Goal:** Bring the journaling features to life: rotating **prompts**, **On This Day** resurfacing, **tags** (as a value array), full-text **search**, a **Pinned** section, and a gentle **stats** glance (words this week + a writing streak).

**Robustness note:** Tags are stored as `Entry.tagNames: [String]` — a value array, not a SwiftData relationship — to avoid the iOS 26 relationship insert-trap. Tag filtering is a predicate over `tagNames`.

## Tasks

1. **Model additions** — `Entry.tagNames: [String]`, `displayTitle`, and pure stat helpers (`WritingStats`). Tests for stats + displayTitle.
2. **Prompts** — `Prompt` provider with a curated list; one per calendar day, deterministic. Today uses it.
3. **On This Day** — `OnThisDay.entries(from:asOf:)` finds past entries sharing today's month/day; Today shows a card. Tested.
4. **Search** — `SearchView` with a live query over title/body/tags.
5. **Library: Pinned section + tag filter** — pinned entries float to a top section; a tag chip bar filters.
6. **Tags editor** — add/remove tags in `EntryEditorView`.
7. **Stats card** — words-this-week + streak on Today.

Each task: write code, regenerate, commit. Tests where logic is pure.
