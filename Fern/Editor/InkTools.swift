import SwiftUI
import PencilKit

// MARK: - Ink settings

/// The current Pencil selection: pen type, color, width, eraser.
struct InkSettings {
    enum Pen: String, CaseIterable, Identifiable {
        case pen, pencil, marker
        var id: String { rawValue }
        var pk: PKInkingTool.InkType {
            switch self {
            case .pen: return .pen
            case .pencil: return .pencil
            case .marker: return .marker
            }
        }
        var icon: String {
            switch self {
            case .pen: return "pencil.tip"
            case .pencil: return "pencil"
            case .marker: return "highlighter"
            }
        }
    }

    var pen: Pen = .pen
    var isEraser = false
    var width: CGFloat = 5
    var r: Double = AccentTone.sienna.light.0
    var g: Double = AccentTone.sienna.light.1
    var b: Double = AccentTone.sienna.light.2

    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
    var color: Color { Color(red: r, green: g, blue: b) }

    mutating func setColor(_ c: (Double, Double, Double)) {
        r = c.0; g = c.1; b = c.2; isEraser = false
    }

    func matches(_ c: (Double, Double, Double)) -> Bool {
        !isEraser && abs(r - c.0) < 0.02 && abs(g - c.1) < 0.02 && abs(b - c.2) < 0.02
    }
}

// MARK: - Canvas management on the controller

/// PencilKit's delegate must be an NSObject; the controller isn't one, so this
/// thin object forwards drawing changes back to it.
final class InkCoordinator: NSObject, PKCanvasViewDelegate {
    weak var controller: MarkdownEditorController?
    init(_ controller: MarkdownEditorController) { self.controller = controller }
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        controller?.saveDrawing()
    }
}

extension MarkdownEditorController {

    /// Attach a transparent PencilKit canvas over the text, sized to (and
    /// scrolling with) the document. Display-only until drawing mode is on.
    func setupCanvas(on textView: UITextView, entryID: UUID) {
        guard canvas == nil else { return }
        let c = PKCanvasView()
        c.backgroundColor = .clear
        c.isOpaque = false
        c.isScrollEnabled = false          // it rides along inside the text scroll view
        c.drawingPolicy = .pencilOnly       // finger stays for typing/scrolling
        c.isUserInteractionEnabled = false  // until draw mode
        let coord = InkCoordinator(self)
        c.delegate = coord
        inkCoordinator = coord
        if let saved = DrawingStore.load(entryID) { c.drawing = saved }
        textView.addSubview(c)
        canvas = c
        drawingEntryID = entryID
        applyInk()
        resizeCanvas()
        // Keep the ink surface matched to the text's growing content height.
        contentSizeObservation = textView.observe(\.contentSize, options: [.initial, .new]) { [weak self] _, _ in
            self?.resizeCanvas()
        }
    }

    func resizeCanvas() {
        guard let tv = textView, let c = canvas else { return }
        let w = tv.contentSize.width > 0 ? tv.contentSize.width : tv.bounds.width
        let h = max(tv.contentSize.height, tv.bounds.height)
        c.frame = CGRect(x: 0, y: 0, width: w, height: h)
    }

    /// Build the active tool from the current settings.
    func applyInk() {
        guard let c = canvas else { return }
        c.tool = ink.isEraser ? PKEraserTool(.vector)
                              : PKInkingTool(ink.pen.pk, color: ink.uiColor, width: ink.width)
    }

    func setDrawing(_ active: Bool) {
        isDrawing = active
        canvas?.isUserInteractionEnabled = active
        if active {
            applyInk()
            textView?.resignFirstResponder()
        } else {
            saveDrawing()
        }
    }

    func undoInk() { canvas?.undoManager?.undo() }

    func clearInk() {
        canvas?.drawing = PKDrawing()
        saveDrawing()
    }

    func saveDrawing() {
        guard let id = drawingEntryID, let c = canvas else { return }
        DrawingStore.save(id, c.drawing)
    }
}

// MARK: - Bespoke ink toolbar

/// Fern's own Pencil palette — the five theme inks plus a muted hue wheel that
/// stays in the theme's value space, pen/pencil/marker, width, eraser, undo.
struct InkToolbar: View {
    @Bindable var controller: MarkdownEditorController
    @State private var showWheel = false

    /// The five theme accent colours as inks.
    private var themeInks: [(Double, Double, Double)] {
        AccentTone.allCases.map { ($0.light.0, $0.light.1, $0.light.2) }
    }
    private let ink = (0.129, 0.118, 0.102)   // near-black

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 22) {
                ForEach(InkSettings.Pen.allCases) { pen in
                    toolButton(pen.icon, on: !controller.ink.isEraser && controller.ink.pen == pen) {
                        controller.ink.pen = pen; controller.ink.isEraser = false; controller.applyInk()
                    }
                }
                toolButton("eraser", on: controller.ink.isEraser) {
                    controller.ink.isEraser = true; controller.applyInk()
                }
                Divider().frame(height: 22)
                toolButton("arrow.uturn.backward") { controller.undoInk() }
                toolButton("trash") { controller.clearInk() }
                Spacer()
                Button("Done") { controller.setDrawing(false) }
                    .font(.headlineSerif)
                    .foregroundStyle(Paper.accent)
            }

            HStack(spacing: 12) {
                swatch(ink)
                ForEach(Array(themeInks.enumerated()), id: \.offset) { _, c in swatch(c) }
                Button { showWheel.toggle() } label: {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 17))
                        .foregroundStyle(Paper.inkSoft)
                        .frame(width: 30, height: 30)
                }
                Slider(value: $controller.ink.width, in: 1...24)
                    .tint(Paper.accent)
                    .onChange(of: controller.ink.width) { _, _ in controller.applyInk() }
                    .frame(maxWidth: 140)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(
            Rectangle().fill(Paper.raised.opacity(0.98))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Paper.line), alignment: .top)
        )
        .popover(isPresented: $showWheel) {
            MutedWheel { rgb in controller.ink.setColor(rgb); controller.applyInk() }
                .frame(width: 240, height: 240)
                .padding(24)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func swatch(_ c: (Double, Double, Double)) -> some View {
        Circle()
            .fill(Color(red: c.0, green: c.1, blue: c.2))
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(Paper.ink, lineWidth: controller.ink.matches(c) ? 2 : 0).padding(1))
            .overlay(Circle().stroke(Paper.line, lineWidth: 0.5))
            .onTapGesture { controller.ink.setColor(c); controller.applyInk() }
    }

    @ViewBuilder
    private func toolButton(_ system: String, on: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18))
                .foregroundStyle(on ? Paper.accent : Paper.inkSoft)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }
}

/// A hue wheel confined to the theme's muted value space (low saturation and
/// brightness), so picked inks never look garish next to the paper.
struct MutedWheel: View {
    var onPick: ((Double, Double, Double)) -> Void

    private static let saturation = 0.5
    private static let brightness = 0.62

    private var hues: [Color] {
        stride(from: 0.0, to: 1.0, by: 1.0 / 12).map {
            Color(hue: $0, saturation: Self.saturation, brightness: Self.brightness)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Circle()
                .fill(AngularGradient(gradient: Gradient(colors: hues + [hues[0]]), center: .center))
                .overlay(Circle().fill(Paper.raised).scaleEffect(0.32))
                .frame(width: side, height: side)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { v in
                        let cx = side / 2, cy = side / 2
                        var a = atan2(v.location.y - cy, v.location.x - cx)
                        if a < 0 { a += 2 * .pi }
                        onPick(Self.rgb(from: a / (2 * .pi)))
                    }
                )
        }
    }

    static func rgb(from hue: Double) -> (Double, Double, Double) {
        let ui = UIColor(hue: CGFloat(hue), saturation: saturation, brightness: brightness, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}
