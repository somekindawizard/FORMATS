import SwiftUI
import UIKit

/// A UITextView that re-fits inline photo attachments to the column **only when
/// its usable width actually changes** (rotation, iPad sidebar, Split View) —
/// not on every layout pass, which would feed back into typing jitter.
final class PhotoTextView: UITextView {
    private var lastWidth: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        // Use the view's frame width (stable while typing), NOT the text
        // container width (which can fluctuate a point per layout on iPad and
        // was re-firing the image re-fit on every keystroke → the jitter).
        let usable = bounds.width - textContainerInset.left - textContainerInset.right
        guard usable > 1, abs(usable - lastWidth) > 2 else { return }
        lastWidth = usable
        let storage = textStorage
        let whole = NSRange(location: 0, length: storage.length)
        var changed = false
        storage.enumerateAttribute(.attachment, in: whole) { value, _, _ in
            if let a = value as? PhotoAttachment { a.fit(toWidth: usable); changed = true }
        }
        if changed {
            // Re-lay-out with the new sizes on the next runloop (avoid re-entrancy).
            DispatchQueue.main.async { [weak self] in
                self?.layoutManager.invalidateLayout(forCharacterRange: whole, actualCharacterRange: nil)
            }
        }
    }
}

/// Hides Markdown syntax glyphs (marked `.fernFold`) unless the caret is on
/// their line — Bear-style live preview. Works at the glyph layer, so it never
/// touches the text or attachment sizes.
final class FoldingLayoutDelegate: NSObject, NSLayoutManagerDelegate {
    weak var textView: UITextView?

    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
                       characterIndexes: UnsafePointer<Int>,
                       font: UIFont,
                       forGlyphRange glyphRange: NSRange) -> Int {
        var newProps = Array(UnsafeBufferPointer(start: props, count: glyphRange.length))
        if ThemeStore.shared.foldMarkers, let storage = layoutManager.textStorage {
            let ns = storage.string as NSString
            var caretPara = NSRange(location: NSNotFound, length: 0)
            if let sel = textView?.selectedRange, sel.location <= ns.length {
                caretPara = ns.paragraphRange(for: sel)
            }
            for i in 0..<glyphRange.length {
                let ci = characterIndexes[i]
                guard ci < storage.length else { continue }
                let onCaretLine = caretPara.location != NSNotFound && NSLocationInRange(ci, caretPara)
                if !onCaretLine, storage.attribute(.fernFold, at: ci, effectiveRange: nil) != nil {
                    newProps[i].insert(.null)   // hide glyph, zero advancement
                }
            }
        }
        newProps.withUnsafeBufferPointer { buf in
            layoutManager.setGlyphs(glyphs, properties: buf.baseAddress!,
                                    characterIndexes: characterIndexes, font: font,
                                    forGlyphRange: glyphRange)
        }
        return glyphRange.length
    }
}

/// SwiftUI wrapper around UITextView that styles Markdown inline as it's typed.
///
/// Critically, styling is applied **in place** — we only change attributes on
/// the existing text storage, never reassign the string. Reassigning the
/// string on each keystroke (as an earlier version did) collapsed spaces and
/// reflowed lines because the Markdown was being re-rendered. Here the user's
/// exact characters are untouched.
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    var controller: MarkdownEditorController? = nil
    /// Render inline photos in the theme-toned wash.
    var wash: Bool = false
    /// Entry id, so the Pencil ink layer can persist per note.
    var entryID: UUID? = nil

    func makeUIView(context: Context) -> UITextView {
        // TextKit 1: the in-place textStorage styling + editable image
        // attachments behave predictably here. TextKit 2 caused scroll jumps on
        // every keystroke and taps grabbing the attachment instead of the caret.
        let layoutManager = NSLayoutManager()
        layoutManager.delegate = context.coordinator.foldDelegate
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer()
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        let tv = PhotoTextView(frame: .zero, textContainer: container)
        context.coordinator.foldDelegate.textView = tv
        tv.delegate = context.coordinator
        context.coordinator.lastWash = wash
        controller?.textView = tv
        controller?.photoWash = wash
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 80, right: 4)
        tv.textContainer.lineFragmentPadding = 0
        tv.alwaysBounceVertical = true
        tv.autocorrectionType = .yes
        tv.smartQuotesType = .yes
        tv.smartDashesType = .yes
        tv.tintColor = MarkdownTheme.accent
        tv.allowsEditingTextAttributes = false
        tv.isFindInteractionEnabled = true   // native find & replace
        tv.typingAttributes = MarkdownStyler.baseAttributes()
        tv.attributedText = EditorPhotos.attributed(fromMarkdown: text, width: Self.contentWidth(tv), wash: wash)
        if let entryID { controller?.setupCanvas(on: tv, entryID: entryID) }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        controller?.photoWash = wash
        // Rebuild when the source changed from outside the view (e.g. loading a
        // note) or when the photo wash toggled. Compare serialized Markdown so
        // inline photo attachments don't read as a perpetual mismatch.
        let washChanged = context.coordinator.lastWash != wash
        // Never rebuild attributedText while the user is actively editing — that
        // resets the scroll position. Only on wash toggle or an external change.
        let externalChange = !uiView.isFirstResponder
            && EditorPhotos.markdown(from: uiView.attributedText) != text
        if washChanged || externalChange {
            context.coordinator.lastWash = wash
            let selected = uiView.selectedRange
            uiView.attributedText = EditorPhotos.attributed(fromMarkdown: text,
                                                            width: Self.contentWidth(uiView), wash: wash)
            let len = uiView.textStorage.length
            uiView.selectedRange = NSRange(location: min(selected.location, len), length: 0)
        }
    }

    /// Usable text width, for sizing inline image attachments. Falls back to the
    /// screen width (minus the editor's padding) before the view has laid out,
    /// so photos in a freshly-opened note aren't sized tiny.
    static func contentWidth(_ tv: UITextView) -> CGFloat {
        let container = tv.textContainer.size.width
        if container > 0 {
            return max(80, container - tv.textContainerInset.left - tv.textContainerInset.right)
        }
        return max(80, UIScreen.main.bounds.width - 52)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        var lastWash = false
        let foldDelegate = FoldingLayoutDelegate()
        private var lastParagraph = NSRange(location: NSNotFound, length: 0)
        init(parent: MarkdownTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = EditorPhotos.markdown(from: textView.attributedText)
            let before = textView.contentOffset
            restyle(textView)
            parent.controller?.refreshCurrentWord()
            if ThemeStore.shared.typewriter {
                centerCaret(textView)
            } else {
                // Hold the page still (kills any restyle-induced jump), then
                // scroll only if the caret is actually off-screen.
                if textView.contentOffset != before {
                    textView.setContentOffset(before, animated: false)
                }
                revealCaretIfNeeded(textView)
            }
        }

        /// Scroll just enough to keep the caret on screen — nothing otherwise.
        private func revealCaretIfNeeded(_ tv: UITextView) {
            guard let range = tv.selectedTextRange else { return }
            let caret = tv.caretRect(for: range.end)
            guard !caret.isNull, caret.minY.isFinite, caret.maxY.isFinite else { return }
            let visibleTop = tv.contentOffset.y + tv.adjustedContentInset.top
            let visibleBottom = tv.contentOffset.y + tv.bounds.height - tv.adjustedContentInset.bottom
            if caret.maxY > visibleBottom {
                tv.setContentOffset(CGPoint(x: 0, y: tv.contentOffset.y + (caret.maxY - visibleBottom) + 8),
                                    animated: false)
            } else if caret.minY < visibleTop {
                tv.setContentOffset(CGPoint(x: 0, y: max(0, tv.contentOffset.y - (visibleTop - caret.minY) - 8)),
                                    animated: false)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.controller?.refreshCurrentWord()
            // Focus mode re-dims around the paragraph the caret moved into.
            if ThemeStore.shared.focusMode { restyle(textView) }
            if ThemeStore.shared.typewriter { centerCaret(textView) }
            refoldOnParagraphChange(textView)
        }

        /// When the caret moves to a new line, re-generate glyphs for the old and
        /// new lines so folding reveals/hides their marks.
        private func refoldOnParagraphChange(_ tv: UITextView) {
            guard ThemeStore.shared.foldMarkers else { return }
            let ns = (tv.text ?? "") as NSString
            guard tv.selectedRange.location <= ns.length else { return }
            let para = ns.paragraphRange(for: tv.selectedRange)
            guard para.location != lastParagraph.location || para.length != lastParagraph.length else { return }
            let old = lastParagraph
            lastParagraph = para
            let lm = tv.layoutManager
            if old.location != NSNotFound, NSMaxRange(old) <= ns.length {
                lm.invalidateGlyphs(forCharacterRange: old, changeInLength: 0, actualCharacterRange: nil)
                lm.invalidateDisplay(forCharacterRange: old)
            }
            lm.invalidateGlyphs(forCharacterRange: para, changeInLength: 0, actualCharacterRange: nil)
            lm.invalidateDisplay(forCharacterRange: para)
        }

        /// Keep the caret line vertically centered (typewriter scrolling).
        private func centerCaret(_ tv: UITextView) {
            guard let range = tv.selectedTextRange else { return }
            let caret = tv.caretRect(for: range.end)
            guard caret.midY.isFinite else { return }
            let target = caret.midY - tv.bounds.height / 2
            let maxY = max(0, tv.contentSize.height - tv.bounds.height + tv.contentInset.bottom)
            let y = min(max(target, -tv.contentInset.top), maxY)
            tv.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }

        /// Re-apply Markdown attributes over the existing characters.
        private func restyle(_ textView: UITextView) {
            // Don't disturb in-progress composition (emoji, CJK, autocorrect).
            guard textView.markedTextRange == nil else { return }

            let source = textView.text ?? ""
            let styled = MarkdownStyler.attributed(for: source)
            let storage = textView.textStorage

            // The styler preserves the string exactly, so lengths match and we
            // can swap attributes without touching characters or the caret.
            guard styled.length == storage.length else {
                let sel = textView.selectedRange
                textView.attributedText = styled
                textView.selectedRange = sel
                return
            }

            // Snapshot inline photo attachments — the base-attribute reset below
            // would otherwise strip them off their U+FFFC characters.
            var attachments: [(Int, PhotoAttachment)] = []
            storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { v, r, _ in
                if let a = v as? PhotoAttachment { attachments.append((r.location, a)) }
            }

            let selected = textView.selectedRange
            let whole = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.setAttributes(MarkdownStyler.baseAttributes(), range: whole)
            styled.enumerateAttributes(in: whole, options: []) { attrs, range, _ in
                storage.addAttributes(attrs, range: range)
            }
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            centered.paragraphSpacing = 6
            centered.paragraphSpacingBefore = 6
            let nsString = storage.string as NSString
            for (loc, a) in attachments where loc < storage.length {
                storage.addAttribute(.attachment, value: a, range: NSRange(location: loc, length: 1))
                // Center the photo on its own line, magazine-style.
                let para = nsString.paragraphRange(for: NSRange(location: loc, length: 0))
                storage.addAttribute(.paragraphStyle, value: centered, range: para)
            }
            storage.endEditing()
            textView.selectedRange = selected
            textView.typingAttributes = MarkdownStyler.baseAttributes()

            if ThemeStore.shared.focusMode { applyFocus(textView) }
        }

        /// Dim everything but the caret's paragraph.
        private func applyFocus(_ textView: UITextView) {
            let storage = textView.textStorage
            let ns = storage.string as NSString
            let para = ns.paragraphRange(for: textView.selectedRange)
            let dim = MarkdownTheme.ink.withAlphaComponent(0.22)
            if para.location > 0 {
                storage.addAttribute(.foregroundColor, value: dim,
                                     range: NSRange(location: 0, length: para.location))
            }
            let after = NSMaxRange(para)
            if after < storage.length {
                storage.addAttribute(.foregroundColor, value: dim,
                                     range: NSRange(location: after, length: storage.length - after))
            }
        }
    }
}
