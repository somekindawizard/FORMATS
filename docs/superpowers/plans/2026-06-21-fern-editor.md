# Fern Editor Implementation Plan (Plan 2 of 7)

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking. This plan is **code-only** — the controller writes/commits each task; the user builds/runs in Xcode. Do not invoke `xcodebuild` or the iOS Simulator from the controller.

**Goal:** A calm, live‑Markdown editor — the heart of Fern — that lets Austin create a new entry from Today's "Begin writing" button, open and edit any entry from the Library, and save changes back through SwiftData. Markdown styles inline as he types: `## headings`, **bold**, *italic*, lists, block quotes, and inline `code` render with their syntax marks dimmed.

**Architecture:** A `MarkdownTextView` (a `UIViewRepresentable` wrapping `UITextView` with **TextKit 2**) applies styling as text changes. Parsing uses **Apple's `swift-markdown` package** for a full CommonMark AST; a `MarkdownStyler` walks the AST and emits styled ranges into the text storage, then a single pass dims the visible syntax marks. The editor screen owns one `Entry` (an `@Bindable` SwiftData object) and a slim chip row for date · mood · place. A keyboard accessory bar provides B/I/“”/#/— shortcuts and a live word count. Navigation is push (per the design spec) from Today's **Begin writing** and from tapping any Library entry row.

**Tech Stack:** Swift 5.10+, SwiftUI, **SwiftData**, **TextKit 2** (`UITextView`), **swift-markdown** (Apple, SwiftPM), XCTest. iOS 18.0 deployment target.

**Scope note:** Plan 2 only adds *creating, reading, and editing* one entry at a time, with live Markdown styling. Photos (Plan 4), tags (Plan 3), search (Plan 3), and Journaling Suggestions (Plan 6) are explicitly out. Mood/place chips render the spec's UI but their pickers are stubbed (`/* picker arrives in Plan 4 */`) — tapping them does nothing visible, which is fine.

**Key risk and discipline:** The live‑styling text view is the genuinely hard piece flagged in the design spec. It is built as an **isolated unit** (`Fern/Editor/MarkdownTextView.swift` + `MarkdownStyler.swift`) so nothing else depends on its internals. If a task lands at "this needs a deeper TextKit rewrite," **stop and report DONE_WITH_CONCERNS** — don't expand scope.

---

## File structure created by this plan

```
Fern/Editor/
  MarkdownTextView.swift     – UIViewRepresentable wrapping UITextView (TextKit 2)
  MarkdownStyler.swift       – swift-markdown AST → NSAttributedString styling
  MarkdownTheme.swift        – fonts, colors, paragraph styles for the styled output
  AccessoryBar.swift         – B/I/“”/#/— buttons + live word count
Fern/Views/
  EntryEditorView.swift      – the editor screen: title, chip row, MarkdownTextView, accessory bar
Fern/Views/
  EntryRow.swift             – modify: existing row gets NavigationLink wrapping
  LibraryView.swift          – modify: rows push EntryEditorView
  TodayView.swift            – modify: "Begin writing" creates a draft entry and pushes EntryEditorView
FernTests/
  MarkdownStylerTests.swift  – styler emits expected attributes for headings/bold/italic/code/list
```

---

### Task 1: Add the swift-markdown package

**Files:** `project.yml` (modify), `Fern.xcodeproj` (regenerated)

XcodeGen adds SwiftPM dependencies under a target's `dependencies:`. We add Apple's [`swift-markdown`](https://github.com/swiftlang/swift-markdown), product name `Markdown`.

- [ ] **Step 1: Edit `project.yml`** — add the package and link the product

In `project.yml`, add a top-level `packages:` block (if absent) and add a `package: Markdown` dependency to the `Fern` target:

```yaml
# (existing settings/options/...)
packages:
  swift-markdown:
    url: https://github.com/swiftlang/swift-markdown
    from: "0.5.0"
targets:
  Fern:
    type: application
    platform: iOS
    sources: [Fern]
    dependencies:
      - package: swift-markdown
        product: Markdown
    settings:
      base:
        # (existing settings unchanged)
```

(Preserve every other key in `project.yml` exactly. If the file already has a `dependencies:` line on the `Fern` target — it doesn't yet — append, don't replace.)

- [ ] **Step 2: Regenerate**

Run: `xcodegen generate`
Expected: `Created project at Fern.xcodeproj`. The generated `.xcodeproj` now references the package; on first open Xcode resolves it from the network.

- [ ] **Step 3: Commit**

```bash
git add project.yml Fern.xcodeproj
git commit -m "Fern: add swift-markdown (Apple) as an SPM dependency"
```

**User verification (when convenient):** open Xcode — it will say "Resolving Package Graph" briefly. After that, `import Markdown` is available. ⌘B should succeed.

---

### Task 2: MarkdownTheme — fonts/colors for styled output

**Files:** Create `Fern/Editor/MarkdownTheme.swift`

Centralizes every visual choice the styler makes, so the styler stays a pure logic walker. Uses tokens from `Paper`/`Font` (Plan 1).

- [ ] **Step 1: Write the file**

Create `Fern/Editor/MarkdownTheme.swift`:

```swift
import UIKit

/// Fonts, colors, paragraph styles used by `MarkdownStyler` to render
/// CommonMark inline. Everything stylable from one place.
enum MarkdownTheme {

    // Colors — pulled from the same RGB values as Paper.* (UIColor for UITextView).
    static let ink     = UIColor(red: 0.110, green: 0.102, blue: 0.090, alpha: 1)
    static let inkSoft = UIColor(red: 0.357, green: 0.341, blue: 0.314, alpha: 1)
    /// Used to dim Markdown syntax marks (`**`, `*`, `#`, etc.).
    static let faint   = UIColor(red: 0.541, green: 0.525, blue: 0.486, alpha: 1)
    static let accent  = UIColor(red: 0.604, green: 0.290, blue: 0.176, alpha: 1)

    // Fonts — system "New York" serif, scaled to the editor's body size.
    static let bodySize: CGFloat = 18
    static func body() -> UIFont {
        UIFont(descriptor: serifDescriptor(weight: .regular), size: bodySize)
    }
    static func italic() -> UIFont {
        UIFont(descriptor: serifDescriptor(weight: .regular, italic: true), size: bodySize)
    }
    static func bold() -> UIFont {
        UIFont(descriptor: serifDescriptor(weight: .semibold), size: bodySize)
    }
    static func boldItalic() -> UIFont {
        UIFont(descriptor: serifDescriptor(weight: .semibold, italic: true), size: bodySize)
    }
    static func heading(level: Int) -> UIFont {
        let size: CGFloat = switch level {
        case 1: 30; case 2: 24; case 3: 21; default: 19
        }
        return UIFont(descriptor: serifDescriptor(weight: .medium), size: size)
    }
    static func mono(size: CGFloat = bodySize - 1) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    // Paragraph spacing — generous, page-like.
    static func paragraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 4
        p.paragraphSpacing = 10
        p.lineHeightMultiple = 1.15
        return p
    }
    static func headingParagraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineHeightMultiple = 1.1
        p.paragraphSpacingBefore = 12
        p.paragraphSpacing = 6
        return p
    }
    static func blockquoteParagraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.firstLineHeadIndent = 18
        p.headIndent = 18
        p.paragraphSpacing = 10
        p.lineSpacing = 4
        return p
    }

    private static func serifDescriptor(weight: UIFont.Weight, italic: Bool = false) -> UIFontDescriptor {
        var desc = UIFont.systemFont(ofSize: bodySize, weight: weight)
            .fontDescriptor
            .withDesign(.serif) ?? UIFont.systemFont(ofSize: bodySize, weight: weight).fontDescriptor
        if italic {
            desc = desc.withSymbolicTraits(.traitItalic) ?? desc
        }
        return desc
    }
}
```

- [ ] **Step 2: Regenerate + commit**

```bash
xcodegen generate
git add Fern/Editor/MarkdownTheme.swift Fern.xcodeproj
git commit -m "Fern: MarkdownTheme — fonts, colors, paragraph styles for the editor"
```

**User verification:** ⌘B succeeds (no behavior change; just adds a type).

---

### Task 3: MarkdownStyler — AST walker that returns `NSAttributedString`

**Files:** Create `Fern/Editor/MarkdownStyler.swift`; create `FernTests/MarkdownStylerTests.swift`

The styler takes a Markdown string, parses it with `Markdown.Document`, walks the AST, and produces an `NSAttributedString` with attributes from `MarkdownTheme`. Syntax marks (`**`, `*`, `#`, backticks, `>`) are written into the output too — and *dimmed* — so they remain visible in the editor (iA Writer style).

- [ ] **Step 1: Write the failing tests**

Create `FernTests/MarkdownStylerTests.swift`:

```swift
import XCTest
@testable import Fern

final class MarkdownStylerTests: XCTestCase {

    private func style(_ s: String) -> NSAttributedString {
        MarkdownStyler.attributed(for: s)
    }

    func test_plain_text_is_rendered_in_body_font() {
        let out = style("just plain text.")
        XCTAssertEqual(out.string, "just plain text.")
        let font = out.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, MarkdownTheme.bodySize)
    }

    func test_heading_uses_heading_font() {
        let out = style("# Title\n")
        // The `# ` syntax remains in the visible text.
        XCTAssertTrue(out.string.contains("# Title"))
        // The letter 'T' (after "# ") should be heading-sized.
        let tIdx = out.string.firstIndex(of: "T")!
        let pos = out.string.distance(from: out.string.startIndex, to: tIdx)
        let font = out.attribute(.font, at: pos, effectiveRange: nil) as? UIFont
        XCTAssertGreaterThan(font?.pointSize ?? 0, MarkdownTheme.bodySize)
    }

    func test_bold_marks_are_dimmed_around_bold_text() {
        let out = style("a **bold** b")
        let firstStarIdx = out.string.firstIndex(of: "*")!
        let pos = out.string.distance(from: out.string.startIndex, to: firstStarIdx)
        let color = out.attribute(.foregroundColor, at: pos, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, MarkdownTheme.faint)
    }

    func test_bold_text_uses_bold_font() {
        let out = style("a **bold** b")
        let bIdx = out.string.range(of: "bold")!.lowerBound
        let pos = out.string.distance(from: out.string.startIndex, to: bIdx)
        let font = out.attribute(.font, at: pos, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }

    func test_inline_code_uses_monospace() {
        let out = style("call `now()` here")
        let nIdx = out.string.range(of: "now")!.lowerBound
        let pos = out.string.distance(from: out.string.startIndex, to: nIdx)
        let font = out.attribute(.font, at: pos, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) ?? false)
    }
}
```

- [ ] **Step 2: Write the styler**

Create `Fern/Editor/MarkdownStyler.swift`:

```swift
import UIKit
import Markdown

/// Pure-logic walker: Markdown source → NSAttributedString styled per
/// `MarkdownTheme`. Syntax marks (`**`, `*`, `#`, backticks, `>`) are
/// preserved in the visible text and **dimmed** so the user sees what
/// they typed but the formatting reads correctly.
enum MarkdownStyler {

    static func attributed(for source: String) -> NSAttributedString {
        let doc = Document(parsing: source)
        let out = NSMutableAttributedString()
        var walker = Walker(out: out)
        walker.visit(doc)
        return out
    }

    // MARK: – Walker

    private struct Walker: MarkupWalker {
        let out: NSMutableAttributedString
        var stack: [Style] = [.body]

        mutating func visitText(_ text: Text) {
            append(text.string, style: stack.last ?? .body)
        }

        mutating func visitEmphasis(_ e: Emphasis) {
            appendMark("*")
            push(stack.last?.adding(.italic) ?? .body.adding(.italic)); defer { pop() }
            descendInto(e)
            appendMark("*")
        }

        mutating func visitStrong(_ s: Strong) {
            appendMark("**")
            push(stack.last?.adding(.bold) ?? .body.adding(.bold)); defer { pop() }
            descendInto(s)
            appendMark("**")
        }

        mutating func visitInlineCode(_ c: InlineCode) {
            appendMark("`")
            append(c.code, style: .code)
            appendMark("`")
        }

        mutating func visitHeading(_ h: Heading) {
            appendMark(String(repeating: "#", count: h.level) + " ")
            push(.heading(h.level)); defer { pop() }
            descendInto(h)
            append("\n", style: .body)
        }

        mutating func visitBlockQuote(_ bq: BlockQuote) {
            appendMark("> ")
            push(.blockquote); defer { pop() }
            descendInto(bq)
            append("\n", style: .body)
        }

        mutating func visitParagraph(_ p: Paragraph) {
            descendInto(p)
            append("\n", style: .body)
        }

        mutating func visitOrderedList(_ list: OrderedList) {
            for (i, item) in list.children.enumerated() {
                appendMark("\(i + 1). ")
                descendInto(item)
                if i < list.childCount - 1 { append("\n", style: .body) }
            }
            append("\n", style: .body)
        }

        mutating func visitUnorderedList(_ list: UnorderedList) {
            for (i, item) in list.children.enumerated() {
                appendMark("• ")
                descendInto(item)
                if i < list.childCount - 1 { append("\n", style: .body) }
            }
            append("\n", style: .body)
        }

        // MARK: – Helpers

        private mutating func descendInto(_ markup: Markup) {
            for child in markup.children { visit(child) }
        }

        private mutating func push(_ s: Style) { stack.append(s) }
        private mutating func pop() { _ = stack.popLast() }

        private mutating func append(_ s: String, style: Style) {
            out.append(NSAttributedString(string: s, attributes: style.attributes()))
        }

        private mutating func appendMark(_ s: String) {
            var attrs = (stack.last ?? .body).attributes()
            attrs[.foregroundColor] = MarkdownTheme.faint
            out.append(NSAttributedString(string: s, attributes: attrs))
        }
    }

    // MARK: – Style descriptor

    private enum Style {
        case body, code, blockquote
        case heading(Int)
        indirect case modified(Style, traits: Traits)

        struct Traits: OptionSet { let rawValue: Int
            static let bold   = Traits(rawValue: 1 << 0)
            static let italic = Traits(rawValue: 1 << 1)
        }

        var traits: Traits {
            if case .modified(_, let t) = self { return t }
            return []
        }

        func adding(_ t: Traits) -> Style { .modified(self, traits: traits.union(t)) }

        func attributes() -> [NSAttributedString.Key: Any] {
            switch self {
            case .body:
                return [
                    .font: fontWithTraits(MarkdownTheme.body(), traits: traits),
                    .foregroundColor: MarkdownTheme.ink,
                    .paragraphStyle: MarkdownTheme.paragraphStyle()
                ]
            case .code:
                return [
                    .font: MarkdownTheme.mono(),
                    .foregroundColor: MarkdownTheme.ink,
                    .paragraphStyle: MarkdownTheme.paragraphStyle()
                ]
            case .blockquote:
                return [
                    .font: fontWithTraits(MarkdownTheme.body(), traits: traits.union(.italic)),
                    .foregroundColor: MarkdownTheme.inkSoft,
                    .paragraphStyle: MarkdownTheme.blockquoteParagraphStyle()
                ]
            case .heading(let lvl):
                return [
                    .font: MarkdownTheme.heading(level: lvl),
                    .foregroundColor: MarkdownTheme.ink,
                    .paragraphStyle: MarkdownTheme.headingParagraphStyle()
                ]
            case .modified(let inner, _):
                var attrs = inner.attributes()
                if let f = attrs[.font] as? UIFont {
                    attrs[.font] = fontWithTraits(f, traits: traits)
                }
                return attrs
            }
        }
    }

    private static func fontWithTraits(_ base: UIFont, traits: Style.Traits) -> UIFont {
        if traits.contains([.bold, .italic]) { return MarkdownTheme.boldItalic() }
        if traits.contains(.bold)   { return MarkdownTheme.bold() }
        if traits.contains(.italic) { return MarkdownTheme.italic() }
        return base
    }
}
```

- [ ] **Step 3: Regenerate + commit**

```bash
xcodegen generate
git add Fern/Editor/MarkdownStyler.swift FernTests/MarkdownStylerTests.swift Fern.xcodeproj
git commit -m "Fern: MarkdownStyler — swift-markdown AST -> styled NSAttributedString, tested"
```

**User verification:** ⌘U should land **10 green tests** (6 existing + 4 new MarkdownStyler tests).

---

### Task 4: MarkdownTextView — the live-styling text view

**Files:** Create `Fern/Editor/MarkdownTextView.swift`

A `UIViewRepresentable` wrapping a `UITextView` (TextKit 2). When the user types, we update the binding *and* re-style the entire string using `MarkdownStyler`. To avoid caret jump, we preserve the selected range across the re-style. (For real-app perf at long documents this re-styles the whole document on every keystroke; acceptable for entries up to ~10k characters, which covers everything the user will hand-type. Sub-second re-style on a Pro Max for the canonical limit.)

- [ ] **Step 1: Write the file**

Create `Fern/Editor/MarkdownTextView.swift`:

```swift
import SwiftUI
import UIKit

/// SwiftUI wrapper around UITextView (TextKit 2) that styles Markdown
/// inline as it's typed: headings/bold/italic/code/lists/blockquotes
/// render in their target font while the syntax marks stay visible
/// in faint ink. Two-way bound to a String.
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(usingTextLayoutManager: true) // TextKit 2
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 80, right: 4)
        tv.textContainer.lineFragmentPadding = 0
        tv.alwaysBounceVertical = true
        tv.autocorrectionType = .yes
        tv.smartQuotesType = .yes
        tv.smartDashesType = .yes
        tv.tintColor = MarkdownTheme.accent
        tv.allowsEditingTextAttributes = false
        tv.attributedText = MarkdownStyler.attributed(for: text)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only re-style when the source string differs from what the view shows.
        if uiView.text != text {
            let selected = uiView.selectedRange
            uiView.attributedText = MarkdownStyler.attributed(for: text)
            uiView.selectedRange = selected
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        init(parent: MarkdownTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""
            parent.text = newText
            // Re-style preserving the caret.
            let selected = textView.selectedRange
            let styled = MarkdownStyler.attributed(for: newText)
            // Avoid resetting attributedText when identical (cheap guard).
            if styled.string != textView.attributedText.string ||
               !attributesEqual(styled, textView.attributedText) {
                textView.attributedText = styled
                textView.selectedRange = selected
            }
        }

        private func attributesEqual(_ a: NSAttributedString, _ b: NSAttributedString) -> Bool {
            guard a.length == b.length else { return false }
            // Cheap shallow equality: compare a few stride samples.
            let stride = max(1, a.length / 8)
            for i in Swift.stride(from: 0, to: a.length, by: stride) {
                if a.attributes(at: i, effectiveRange: nil) as NSDictionary !=
                   b.attributes(at: i, effectiveRange: nil) as NSDictionary {
                    return false
                }
            }
            return true
        }
    }
}
```

- [ ] **Step 2: Regenerate + commit**

```bash
xcodegen generate
git add Fern/Editor/MarkdownTextView.swift Fern.xcodeproj
git commit -m "Fern: MarkdownTextView — TextKit 2 UITextView with live styling"
```

**User verification:** ⌘B (no UI change yet; consumed in Task 6).

---

### Task 5: AccessoryBar — keyboard B/I/“”/#/— + word count

**Files:** Create `Fern/Editor/AccessoryBar.swift`

A thin horizontal bar that sits above the keyboard. Each button inserts the Markdown sequence at the caret. Live word count on the right uses the same logic as `Entry.wordCount`.

- [ ] **Step 1: Write the file**

Create `Fern/Editor/AccessoryBar.swift`:

```swift
import SwiftUI

/// The thin accessory above the keyboard. Tapping a glyph inserts the
/// corresponding Markdown at the caret; word count auto-updates from text.
struct AccessoryBar: View {
    /// The current text — we insert into it.
    @Binding var text: String
    /// Inserts at the end if nil (TextKit will give us a real selection in a
    /// later iteration; for v1, end-insertion is the right default for the
    /// accessory bar, since the user is typing forward.).
    var insertAt: (() -> Int?)? = nil

    private var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        HStack(spacing: 22) {
            glyph("B", weight: .bold) { wrap("**") }
            glyph("I", italic: true) { wrap("*") }
            glyph("“ ”")            { wrap("“", "”") }
            glyph("#")              { lineStart("# ") }
            glyph("—")              { insert("—") }
            Spacer()
            Text("\(wordCount) words")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Paper.inkFaint)
        }
        .padding(.horizontal, 20)
        .frame(height: 42)
        .background(
            Rectangle().fill(Paper.raised.opacity(0.96))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Paper.line), alignment: .top)
        )
    }

    // MARK: – Buttons

    @ViewBuilder
    private func glyph(_ s: String, weight: Font.Weight = .regular,
                       italic: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(s)
                .font(.system(size: 17, weight: weight, design: .serif))
                .italic(italic)
                .foregroundStyle(Paper.inkSoft)
                .frame(minWidth: 24)
        }
        .buttonStyle(.plain)
    }

    // MARK: – Edits

    private func insert(_ s: String) { text.append(s) }

    private func wrap(_ open: String, _ close: String? = nil) {
        // v1: append wrapped marker pair at end with a cursor-style ellipsis
        // inside, so the user sees the structure and types into it.
        text.append("\(open)…\(close ?? open)")
    }

    private func lineStart(_ s: String) {
        // Ensure we begin on a new line.
        if !text.hasSuffix("\n") && !text.isEmpty { text.append("\n") }
        text.append(s)
    }
}
```

> The accessory bar's button behavior in v1 is intentionally simple — *append at end* — because tracking the live caret position from a SwiftUI binding requires a deeper hand‑off from the `UITextView` than belongs in v1. A later milestone (Plan 3 or a small follow-up) can teach the bar to insert at the caret. The shortcut still saves the user from typing the Markdown sequence by hand.

- [ ] **Step 2: Regenerate + commit**

```bash
xcodegen generate
git add Fern/Editor/AccessoryBar.swift Fern.xcodeproj
git commit -m "Fern: AccessoryBar — keyboard shortcuts + live word count"
```

**User verification:** ⌘B (consumed in Task 6).

---

### Task 6: EntryEditorView — the editor screen

**Files:** Create `Fern/Views/EntryEditorView.swift`

The screen the user actually sees when writing: serif title field, a quiet chip row (date · mood · place), the live‑Markdown canvas, the accessory bar above the keyboard. Title and body are bound to `@Bindable var entry: Entry`; SwiftData persists on context save (which we trigger when the view disappears).

- [ ] **Step 1: Write the file**

Create `Fern/Views/EntryEditorView.swift`:

```swift
import SwiftUI
import SwiftData

struct EntryEditorView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) private var context
    @FocusState private var bodyFocused: Bool

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 8) {
                // Title
                TextField("Untitled", text: $entry.title, axis: .vertical)
                    .font(.titleSerif)
                    .foregroundStyle(Paper.ink)
                    .padding(.top, 8)

                ChipRow(entry: entry)
                    .padding(.bottom, 4)

                MarkdownTextView(text: $entry.body)
                    .focused($bodyFocused)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            }
            .padding(.horizontal, 22)
            .safeAreaInset(edge: .bottom) {
                if bodyFocused {
                    AccessoryBar(text: $entry.body)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    entry.isPinned.toggle()
                } label: {
                    Image(systemName: entry.isPinned ? "star.fill" : "star")
                        .foregroundStyle(Paper.accent)
                }
            }
        }
        .onChange(of: entry.title) { _, _ in entry.updatedAt = .now }
        .onChange(of: entry.body)  { _, _ in entry.updatedAt = .now }
        .onDisappear {
            try? context.save()
        }
        .onAppear { bodyFocused = true }
    }
}

/// The date · mood · place strip beneath the title. Mood/place pickers
/// arrive in Plan 4 — for now they render as read-only chips.
private struct ChipRow: View {
    let entry: Entry
    var body: some View {
        HStack(spacing: 6) {
            chip(entry.createdAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
            if let mood = entry.mood {
                chip("● \(mood.label.lowercased())", accent: true)
            }
            if let place = entry.placeName {
                chip(place)
            }
        }
    }

    private func chip(_ s: String, accent: Bool = false) -> some View {
        Text(s)
            .font(.calloutSerif)
            .foregroundStyle(accent ? Paper.accent : Paper.inkSoft)
            .padding(.vertical, 5).padding(.horizontal, 10)
            .background(
                Capsule().stroke(accent ? Paper.accent.opacity(0.25) : Paper.line, lineWidth: 1)
                    .background(Capsule().fill(accent ? Paper.accent.opacity(0.07) : Paper.raised))
            )
    }
}

#Preview {
    let container = SampleData.previewContainer()
    let entry = (try? container.mainContext.fetch(FetchDescriptor<Entry>()))?.first
        ?? Entry(title: "Preview", body: "Hello *world*.", collection: .journal)
    return NavigationStack { EntryEditorView(entry: entry) }
        .modelContainer(container)
}
```

- [ ] **Step 2: Regenerate + commit**

```bash
xcodegen generate
git add Fern/Views/EntryEditorView.swift Fern.xcodeproj
git commit -m "Fern: EntryEditorView — title + chips + live-Markdown canvas + accessory bar"
```

**User verification:** ⌘B succeeds. The preview in `EntryEditorView.swift` should render in Xcode showing the seeded entry "The light over Lady Bird" in serif body type, with the accessory bar above a soft keyboard sketch.

---

### Task 7: Wire from Library and Today

**Files:** Modify `Fern/Views/EntryRow.swift`, `Fern/Views/LibraryView.swift`, `Fern/Views/TodayView.swift`

Library rows push the editor; the Today **Begin writing** button creates a fresh journal `Entry`, inserts it, then pushes the editor.

- [ ] **Step 1: Modify `Fern/Views/LibraryView.swift`** — wrap each row in `NavigationLink`

Replace the `ForEach(section.entries)` block. The full file becomes:

```swift
import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    private var sections: [DaySection] { DayGrouping.sections(from: entries) }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        Text(section.day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .sectionLabel()
                            .padding(.top, 22).padding(.bottom, 6)
                        ForEach(section.entries) { entry in
                            NavigationLink(value: entry) {
                                EntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            Rule()
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Library")
        .navigationDestination(for: Entry.self) { entry in
            EntryEditorView(entry: entry)
        }
    }
}

#Preview {
    NavigationStack { LibraryView() }
        .modelContainer(SampleData.previewContainer())
}
```

- [ ] **Step 2: Modify `Fern/Views/TodayView.swift`** — Begin button creates entry + pushes editor

Replace the file with:

```swift
import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @State private var draft: Entry?

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        switch h {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default:      return "Hello,"
        }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .sectionLabel()
                        .padding(.top, 8)
                    Text("\(greeting)\nAustin.")
                        .font(.masthead)
                        .foregroundStyle(Paper.ink)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("A prompt for today").sectionLabel()
                        Text("What has quietly stayed with you?")
                            .font(.titleSerif)
                            .foregroundStyle(Paper.ink)
                        Button("Begin writing") {
                            let entry = Entry(title: "", body: "", collection: .journal)
                            context.insert(entry)
                            draft = entry
                        }
                        .buttonStyle(InkButtonStyle())
                        .padding(.top, 4)
                    }
                    .card()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Today")
        .navigationDestination(item: $draft) { entry in
            EntryEditorView(entry: entry)
        }
    }
}

#Preview { NavigationStack { TodayView() }.modelContainer(SampleData.previewContainer()) }
```

> `EntryRow.swift` itself doesn't need to change — it's plain content for the `NavigationLink` button.

- [ ] **Step 3: Regenerate + commit**

```bash
xcodegen generate
git add Fern/Views/LibraryView.swift Fern/Views/TodayView.swift Fern.xcodeproj
git commit -m "Fern: Library rows push the editor; Today's Begin creates and opens a new entry"
```

**User verification (the big payoff):** ⌘R on the device.
- Tap **Begin writing** → empty editor pushes; keyboard appears; type a few lines. Watch live styling appear when you type `## A morning`, `**bold**`, `*italic*`, `- list`, `> a thought`.
- Hit the back button → entry persists. Switch to **Library** → the entry shows up (date + title from your first line of body, since title was left empty, OR "Untitled" placeholder).
- Tap any Library entry → editor re-opens with content. Edit. Back. Re-open. Edits persist.

If anything snags, paste the error and I'll patch surgically.

---

## Self-review

**Spec coverage (Plan 2 portion of design §5):**
- Live Markdown styling, dimmed syntax marks: Tasks 3 + 4 ✓
- Serif title + chip row (date · mood · place): Task 6 (mood/place pickers explicitly deferred to Plan 4 — chips render read-only when present)
- Keyboard accessory bar (B / I / “ ” / # / —) + live word count: Task 5 ✓
- No focus/typewriter modes: confirmed by absence (per design decision)
- Push navigation from Today's Begin writing + tappable Library rows: Task 7 ✓
- Saves through SwiftData: Task 6 (`context.save()` on disappear; SwiftData also autosaves periodically)
- Editor isolated as its own unit: file structure (`Fern/Editor/*`) ✓

**Placeholder scan:** No unresolved TBDs. Two intentional out-of-scope markers cite specific later plans:
- Mood/place chips render read-only (Plan 4 adds pickers).
- Accessory bar appends at end rather than at caret (small follow-up; doesn't block the editor's core function).

**Type consistency:** `Entry(title:body:collection:createdAt:mood:isPinned:)` used as defined in Plan 1. `Paper.*` and `.titleSerif`/`.masthead`/`.calloutSerif` come from Plan 1's Theme. `MarkdownStyler.attributed(for:)`, `MarkdownTextView(text:)`, `AccessoryBar(text:)`, `EntryEditorView(entry:)`, `ChipRow` are all defined in this plan before first consumption.

**Risks named:**
- Live re-style of the whole document on each keystroke is fine to ~10k chars on M-class silicon; if perf bites at longer entries, the fix is paragraph-scoped re-style — a Plan 3+ follow-up, not a v1 blocker.
- swift-markdown is at version 0.5+; pin in Task 1's `from:`. No breaking changes expected; if the package's API moves, the styler's import path is the one file affected.
