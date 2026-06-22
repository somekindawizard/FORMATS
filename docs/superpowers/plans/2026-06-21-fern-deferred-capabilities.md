# Fern — Deferred Capability Features

These three features each require an Xcode **capability** (and Apple-portal
enablement) that, if added blindly, can break automatic code signing — so they
were deliberately NOT auto-added during unattended work. Each needs ~1–2 minutes
in Xcode → target **Fern** → **Signing & Capabilities → + Capability**, after
which the code is straightforward to add. Do these with the user present so a
signing hiccup can be resolved immediately.

---

## A. Weather (Plan 4 remainder)

**Capability:** *WeatherKit* (also enable WeatherKit for the App ID in the
Apple Developer portal — Xcode usually offers to do this automatically).

**Then implement:**
- Add optional fields to `Entry` (migration-safe): `weatherSymbol: String?`,
  `weatherTempC: Double?`.
- `WeatherProvider` using `WeatherKit.WeatherService.shared.weather(for:)` for the
  captured `CLLocation`; store the SF Symbol name + temperature.
- When the user taps **add place** (LocationProvider already gives a CLLocation),
  also fetch weather and show a small chip (e.g. `☀︎ 31°`).
- Fail gracefully: if WeatherKit is unavailable, just skip — place still works.

---

## B. Journaling Suggestions (Plan 6) — iPhone only

**Capability:** *Journaling Suggestions* (entitlement
`com.apple.developer.journal.allow`).

**Then implement:**
- A **Suggestions** affordance on Today (and/or the new-entry flow), shown only
  on iPhone (`UIDevice.current.userInterfaceIdiom == .phone`) and when
  `JournalingSuggestionsPicker` is available.
- Present `JournalingSuggestionsPicker`; in its completion, map the chosen
  suggestion to a new `Entry`:
  - photo asset → save via `PhotoStore`, append to `photoFileNames`
  - location/significant place → `placeName` + coords
  - State of Mind → `mood`
  - media (song/podcast)/workout → a quiet line appended to `body`
- iPad has no picker → falls back to the existing rotating prompts (already built).

**Note:** the picker runs out-of-process and returns only the chosen content —
no permission prompt, fully private.

---

## C. CloudKit sync (Plan 7 remainder)

**Capability:** *iCloud* → check **CloudKit**, add a container
(e.g. `iCloud.garden.fern.Fern`). Also add *Background Modes → Remote
notifications* if push-driven sync is desired.

**Then implement:**
- Switch `Persistence.shared` to a CloudKit-backed configuration:
  ```swift
  let config = ModelConfiguration(cloudKitDatabase: .private("iCloud.garden.fern.Fern"))
  return try ModelContainer(for: Entry.self, Tag.self, Attachment.self, configurations: config)
  ```
- Requirement: every SwiftData property must be optional or have a default, and
  relationships must be optional. Fern's `Entry` is already all-optional /
  defaulted and relationship-free, so it's CloudKit-ready as-is.
- Entries then sync across the user's iPad and iPhone via their private iCloud.
- Markdown export + Files visibility (already shipped) remain the portable escape
  hatch regardless of CloudKit.

---

## Why these were deferred

Adding a capability writes an entitlement into the build. With **automatic**
signing, Xcode must mint a provisioning profile that includes that entitlement;
if the App ID doesn't yet have the capability enabled, the build fails to sign.
That's a fine, instant fix when you're at the Mac — but a dead end if it happens
while you're away. Everything that ships without an entitlement (mood, photos,
place, prompts, On-This-Day, tags, search, pin, stats, export, Files visibility,
Face ID lock, the botanical art) was safe to build unattended; these three were
not.
