# Fern — Design Spec

*A calm, paper‑and‑ink creative‑writing and journaling app for iPhone and iPad.*
Date: 2026‑06‑21 · Status: approved design, ready for implementation planning.

---

## 1. Concept

**Fern** is a single, calm library that holds both quick **dated journal entries** and longer **creative pieces**, lightly distinguished. It is built to feel like a well‑set page and to make the writer *want* to write. It shares the paper‑and‑ink design language of its sibling app **Press**, retuned to a cleaner, cooler paper.

It is made for one person ("Austin") and distributed via Xcode on a paid Apple Developer account — **no App Store review**. This unlocks CloudKit and managed entitlements while keeping the app private.

### Goals
- A writing surface that is a joy to use: live Markdown, serif type, nothing in the way.
- One blended library for journaling *and* creative work.
- Beautiful, bespoke, on‑brand details (the fern motif, the unlock animation).
- Reliable sync across the writer's two devices; never lose an entry.

### Non‑goals (v1)
- No public distribution / App Store listing.
- No third‑party accounts or servers (CloudKit private DB only).
- No focus/typewriter modes (explicitly declined — the clean page is calm enough).
- No collaboration, no web app, no Android.

---

## 2. Platforms & technology

- **SwiftUI**, iOS / iPadOS **26.5**. **Light mode only** (matches Press).
- Target devices: **iPhone 17 Pro / 17 Pro Max**, **iPad Air M2**.
- Deployment target set low enough to build on shipping Xcode; tuned and tested on the above.
- **SwiftData + CloudKit** for storage and sync.
- **LocalAuthentication** (Face ID), **JournalingSuggestions** (iPhone), **CoreLocation** + **WeatherKit** (optional metadata), **Canvas / TimelineView / Metal `distortionEffect`** for the fern art.

---

## 3. Information architecture

**iPhone** — a tab bar with three tabs; the editor pushes on top of any of them.
- **Today** — the warm front door (see §4).
- **Library** — the full archive: a date‑grouped feed, filterable by collection and tag.
- **Search** — full‑text search across all entries.

**iPad** — a single **`NavigationSplitView`** with three columns:
- **Sidebar**: Today / Library / Search, then **Collections** (Journal, Pieces) and **tags**.
- **List**: the entry list for the current selection.
- **Detail**: the open entry in the editor.

On iPhone these three are pushed screens; on iPad they sit side by side.

**Collections** are two built‑ins — **Journal** and **Pieces** — plus user **tags**. An entry's collection encodes its intent; both intents live in one store and one library.

---

## 4. Today screen (layout "B")

A calm greeting that surfaces the journaling soul:
- Date line + serif greeting ("Good morning, Austin.").
- **Today's prompt** card (rotating, tappable) with a **Begin writing** button.
- **On This Day** card — "a year ago today you wrote…" — when a past entry matches.
- **Recent pieces** strip.
- iPhone only: a **Suggestions** affordance opening the system Journaling Suggestions picker (§9).

---

## 5. The editor (heart of the app — layout "E2")

- **Live Markdown styling.** Typing `## Heading`, `**bold**`, `*italic*`, lists, and block quotes styles inline as you write, with the **syntax marks dimmed** (the iA Writer / Bear approach). No preview pane, no formatting toolbar.
- **Serif title** at top, then a quiet **chip row**: date · mood · place — tappable to set.
- **Keyboard accessory bar** (kept, light touch): `B` / `I` / `“ ”` / `#` / `—` insert Markdown without reaching for symbols, plus a **live word count**. This is a shortcut strip, *not* a rich‑text toolbar — the text remains plain Markdown.
- **No focus or typewriter modes** in v1, by decision.

### Implementation note — the one genuinely hard piece
The live‑Markdown surface is a custom **`UITextView` / TextKit 2** wrapper exposed to SwiftUI, applying styling attributes as the text changes. It is built as an **isolated unit** (`Editor/MarkdownTextView`) so nothing else depends on its internals. Fallback within v1 if it proves too costly: plain serif text with Markdown applied on render — but live styling is the target.

---

## 6. Feature set (all v1)

| Feature | Behavior |
|---|---|
| Writing prompts | Rotating, tappable prompt on Today and on a new entry. Ignorable, never nagging. |
| Mood + metadata | Optional mood; auto‑captured date, time, and (if permitted) place + weather. |
| On This Day | Resurfacing on Today when a past entry shares the calendar day. |
| Photos in entries | Attach one or more images per entry. |
| Full‑text search | Across titles and bodies; filterable by collection/tag. |
| Tags / collections | Light tags + the two built‑in collections; browse filtered. |
| Pin / favorite | Star entries/pieces to keep them at the top. |
| Word count + stats | Live word count while writing; a gentle "words this week" / streak glance. |
| Journaling Suggestions | iPhone only (§9). |
| Privacy lock | Optional Face ID / passcode, off by default, with the custom fern unlock (§10). |
| Export / portability | Markdown export (single entry or whole library) + Files‑app visibility. |

---

## 7. Data model (SwiftData + CloudKit)

```
Entry
  id: UUID
  title: String
  body: String                 // Markdown
  collection: Collection       // .journal | .piece
  createdAt, updatedAt: Date
  mood: Mood?                  // optional enum
  placeName: String?           // reverse-geocoded label
  latitude, longitude: Double? // optional
  weather: WeatherSnapshot?    // optional (symbol, temp)
  isPinned: Bool
  tags: [Tag]                  // many-to-many
  attachments: [Attachment]    // ordered

Tag
  name: String (unique)
  entries: [Entry]

Attachment
  imageData / fileRef
  caption: String?
  order: Int
```

- Synced via the **CloudKit private database** across the writer's devices. Nothing leaves the writer's iCloud.
- **Markdown export** writes real `.md` files (single entry or full library). The app's **Documents folder is exposed in Files** (`UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace`) for backup and AirDrop.
- If iCloud is ever unavailable, the SwiftData store still works fully on‑device.

---

## 8. Visual system

Retuned from Press's `Theme/` for a cleaner, cooler paper.

**Palette (final):**
| Token | Hex | Use |
|---|---|---|
| `paper` | `#F6F5F1` | primary canvas ("Mist") |
| `raised` | `#FFFFFF` | cards, sheets |
| `line` | `#EBE9E1` | hairline rules / borders |
| `ink` | `#1C1A17` | primary text & strokes |
| `inkSoft` | `#5B5750` | secondary text |
| `inkFaint` | `#8A867C` | tertiary / hints / dimmed Markdown marks |
| `accent` | `#9A4A2D` | single restrained sienna accent |

**Type:** system **serif (New York)** editorial scale — masthead / title / headline / body — plus **monospace** for figures (word & character counts). Tracked uppercase small‑caps for section labels.

**Components** (ported from Press, re‑toned): `Rule` hairline, `card()`, ink / outline / quiet button styles, `SectionHeader`, `pressable()` scale, and a paper‑grain background re‑toned for the cool paper (seeded, static).

---

## 9. Journaling Suggestions (iOS 26, iPhone)

A **Suggestions** affordance on Today / new‑entry opens the system **`JournalingSuggestionsPicker`**. When the writer picks a suggestion, iOS hands the app **only the chosen content** — no permission prompt, runs out‑of‑process, fully private — and Fern pre‑fills a new entry:

- photo → **attachment**
- location / significant place → **place** chip
- State of Mind → **mood** chip
- workout / media (song, podcast) → a quiet **metadata line** ("Listening to…")

**Constraints (designed for):**
- Requires the managed entitlement **`com.apple.developer.journal.allow`** — selectable in Xcode on the paid account and enabled on the App ID. Works for a development install.
- The picker is **iPhone‑only**. On iPad, the feature is hidden and Fern falls back to its own rotating prompts. Graceful degradation, no broken affordances.

---

## 10. Privacy & the fern unlock

- Optional **Face ID / passcode** via `LAContext`, off by default. A lock gate wraps the app root.
- The system Face ID scan UI cannot be themed, but everything around it is ours. The **lock veil** shows the coiled **fiddlehead** fern mark on the Mist paper; on a successful match the frond **unfurls** as the paper veil lifts to reveal the library. Failure → a gentle shake, frond stays coiled.
- The coiled fiddlehead is the app's **signature mark**: it is also the **app icon** and the **empty‑state flourish**.

---

## 11. Architecture / file layout

```
Fern/
  FernApp.swift          – entry, tab bar / split view, lock gate
  Theme/                 – palette, type scale, paper background, components (from Press, re-toned)
  Models/                – Entry, Tag, Attachment, Mood, Collection, WeatherSnapshot (SwiftData)
  Store/                 – ModelContainer, LibraryStore, search, prompts, on-this-day, stats
  Services/              – Location/Weather, MarkdownExporter, BiometricLock, JournalingSuggestionsBridge
  Editor/                – MarkdownTextView (TextKit 2), live-styling, accessory bar
  Fern/                  – FernMark (Barnsley), FernFrond (skeletal), FiddleheadUnfurl, sway
  Views/                 – Today, Library, EntryRow, EntryEditor, Search, Collections, Stats, Settings
  Assets.xcassets/       – app icon + accent
```

Each unit has one clear purpose and communicates through a narrow interface, so it can be understood and tested independently (notably `MarkdownTextView` and the `Fern/` art, which are the two pieces with real internal complexity).

---

## 12. Appendix — Fern generation & motion

The fern motif uses **two representations**, each for a different job. The key lesson from prototyping: **point clouds are for stills; skeletons are for motion.**

### A. Barnsley fern — still imagery (icon, empty‑state, lock background)
An IFS "chaos game": plot ~80k points, each step picking one of four affine transforms by probability. Seed a **fixed PRNG** so the mark is deterministic (same fern every launch), exactly as Press seeds its paper grain.

`xₙ₊₁ = a·x + b·y + e`, `yₙ₊₁ = c·x + d·y + f`

| transform | a | b | c | d | e | f | prob | role |
|---|---|---|---|---|---|---|---|---|
| f₁ | 0 | 0 | 0 | 0.16 | 0 | 0 | 1% | stem |
| f₂ | 0.85 | 0.04 | −0.04 | 0.85 | 0 | 1.60 | 85% | successively smaller leaflets |
| f₃ | 0.20 | −0.26 | 0.23 | 0.22 | 0 | 1.60 | 7% | left leaflet |
| f₄ | −0.15 | 0.28 | 0.26 | 0.24 | 0 | 0.44 | 7% | right leaflet |

Output spans x ∈ [−2.18, 2.66], y ∈ [0, 9.99]; scale to fit. Render once into a SwiftUI **`Canvas`** and cache as an image. **Never animated.**

### B. Gentle idle sway — the motion we chose
The preferred motion is a **soft gust‑and‑settle** of the *still* Barnsley fern (not a constant breeze, and not the per‑branch segmentation, which tore leaves in half). Generate the points once; per frame, offset each point horizontally by a height‑weighted, slow wind function so the base stays rooted and the tip moves most:

```
h    = y / yMax
bend = SWAY · h² · gust(t) · sin(t·0.62 − h·1.3)      // SWAY ≈ 0.34 (one tunable knob)
flutter = 0.018 · h · sin(t·2.6 + y·1.9 + x·1.4)
x'   = x + bend + flutter
gust(t) = 0.6·sin(t·0.5) + 0.28·sin(t·1.15 + 1.0)
```

A **gust** is a single soft swell: an amplitude envelope that rises from rest and decays over several seconds, eased slowly. This plays on launch/unlock and at long idle intervals on the empty‑state and lock fern.

**Production rendering:** render the fern once, then drive the bend with a Metal **`distortionEffect`** (height‑ and time‑based horizontal displacement) under a `TimelineView(.animation)` — GPU‑cheap, no per‑point CPU work. The CPU point‑offset version is acceptable at moderate counts for a first pass.

**Why not per‑branch animation:** the Barnsley attractor has no connectivity, so any grouping of its points cuts across real leaflets and splits them. The gentle whole‑motion bend avoids this entirely and reads as natural for a light breeze.

### C. Structured skeletal frond — reserved, optional
For richer motion (the unfurl, or future per‑leaflet flutter), use **connected vector geometry** instead of points: a node hierarchy (rachis → leaflets → barbs). Each leaflet is one path rotated **rigidly about its joint** (rotation preserves length → no stretch; per‑node phase → independent leaflets). Generatable from the **L‑system** `X → F+[[X]−X]−F[−FX]+X`, `F → FF`, angle ≈ 25°, 5–6 rewrites.

### D. Fiddlehead unfurl — the unlock motion
A parametric **logarithmic spiral** `r = a·e^(b·θ)` that uncoils by animating θ_max from tight → extended, with leaflets drawn along the rachis as it opens. An animatable `Shape` whose `animatableData` is the unfurl parameter, driven by a spring on a successful Face ID match (or `PhaseAnimator` for staged coil → stem → leaflets).

---

## 13. Risks & phasing

- **Live‑Markdown editor** is the main technical risk; isolate it as `MarkdownTextView`. Fallback noted in §5.
- **CloudKit** needs the iCloud entitlement on the App ID and a schema push from the dev environment — a setup step, not a design risk.
- **WeatherKit** requires the paid account (available); if undesired, ship place‑only and drop weather.
- **Journaling Suggestions** entitlement is managed and iPhone‑only — handled by capability/idiom checks (§9).

**Optional leaner first milestone** (if ever desired): ship the core — write, library, prompts, mood/metadata, search, tags, pin, export, Face ID + fern unlock — and fast‑follow with **photos, On This Day, stats, weather, Journaling Suggestions**. Default plan is the full v1.

---

## 14. Decision log

- Blended journal + creative, one library. ("Both, blended")
- SwiftData + CloudKit (paid account, no review) over local `.md`‑in‑iCloud‑Drive, for reliability; Markdown export covers portability.
- All listed features in v1.
- Live Markdown styling; **no** focus/typewriter modes.
- Today‑screen layout **B**; editor layout **E2** (with accessory bar); iPad three‑column split.
- Paper **Mist `#F6F5F1`**; accent **Sienna `#9A4A2D`**.
- Name: **Fern**. Signature mark: the coiled fiddlehead.
- Motion: gentle **gust‑and‑settle** on the still Barnsley fern.
