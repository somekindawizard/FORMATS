import XCTest
@testable import Fern

final class MarkdownStylerTests: XCTestCase {

    private func style(_ s: String) -> NSAttributedString {
        MarkdownStyler.attributed(for: s)
    }

    func test_plain_text_is_rendered_in_body_font() {
        let out = style("just plain text.")
        // Plain text gets the paragraph break appended; the visible chars match.
        XCTAssertTrue(out.string.hasPrefix("just plain text."))
        let font = out.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, MarkdownTheme.bodySize)
    }

    func test_heading_uses_heading_font() {
        let out = style("# Title\n")
        XCTAssertTrue(out.string.contains("# Title"))
        // 'T' lives just after "# "
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
