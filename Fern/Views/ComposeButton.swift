import SwiftUI

/// A bespoke "new free write" affordance — a custom-drawn pencil inside a soft
/// paper disc, matching the app's circular-button language rather than the
/// stock compose glyph.
struct ComposeButton: View {
    let action: () -> Void
    /// Optional templates — when present, a long-press opens a template menu
    /// while a tap still starts a blank page.
    var templates: [WritingTemplate] = []
    var onTemplate: (WritingTemplate) -> Void = { _ in }

    var body: some View {
        Group {
            if templates.isEmpty {
                Button(action: action) { glyph }.buttonStyle(.plain)
            } else {
                Menu {
                    Button { action() } label: { Label("Blank page", systemImage: "pencil") }
                    Section("Start from a template") {
                        ForEach(templates) { t in
                            Button { onTemplate(t) } label: { Label(t.title, systemImage: t.icon) }
                        }
                    }
                } label: {
                    glyph
                } primaryAction: {
                    action()
                }
            }
        }
        .accessibilityLabel("New entry")
    }

    private var glyph: some View {
        PencilGlyph()
            .stroke(Paper.accent, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .frame(width: 21, height: 21)
            .frame(width: 44, height: 44)
            .background(
                Circle().fill(Paper.raised)
                    .overlay(Circle().stroke(Paper.line, lineWidth: 1))
                    .shadow(color: Paper.ink.opacity(0.06), radius: 7, x: 0, y: 3)
            )
    }
}

/// A simple line-art pencil drawn on a diagonal, writing toward the lower-left.
private struct PencilGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = w / 2, cy = h / 2
        let bodyW = w * 0.34

        var p = Path()
        let top = h * 0.08          // flat (eraser) end
        let shoulder = h * 0.72     // where the wood is shaved to the tip
        let tip = h * 0.96          // graphite point

        // Pencil body + sharpened tip, drawn vertically.
        p.move(to: CGPoint(x: cx - bodyW / 2, y: top))
        p.addLine(to: CGPoint(x: cx + bodyW / 2, y: top))
        p.addLine(to: CGPoint(x: cx + bodyW / 2, y: shoulder))
        p.addLine(to: CGPoint(x: cx, y: tip))
        p.addLine(to: CGPoint(x: cx - bodyW / 2, y: shoulder))
        p.closeSubpath()
        // Collar (band) and the wood/graphite line — small analog details.
        p.move(to: CGPoint(x: cx - bodyW / 2, y: top + h * 0.16))
        p.addLine(to: CGPoint(x: cx + bodyW / 2, y: top + h * 0.16))
        p.move(to: CGPoint(x: cx - bodyW / 2, y: shoulder))
        p.addLine(to: CGPoint(x: cx + bodyW / 2, y: shoulder))

        // Rotate the whole pencil onto a writing diagonal.
        let transform = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: -0.62)
            .translatedBy(x: -cx, y: -cy)
        return p.applying(transform)
    }
}
