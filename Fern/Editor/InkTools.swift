import SwiftUI
import PencilKit

// MARK: - Ink settings

/// The current Pencil selection: pen type, color, width, eraser.
struct InkSettings {
    enum Pen: String, CaseIterable, Identifiable {
        case pen, fountainPen, pencil, monoline, marker, crayon
        var id: String { rawValue }
        var pk: PKInkingTool.InkType {
            switch self {
            case .pen: return .pen
            case .fountainPen: return .fountainPen
            case .pencil: return .pencil
            case .monoline: return .monoline
            case .marker: return .marker
            case .crayon: return .crayon
            }
        }
        var icon: String {
            switch self {
            case .pen: return "pencil.tip"
            case .fountainPen: return "paintbrush.pointed"
            case .pencil: return "pencil"
            case .monoline: return "scribble.variable"
            case .marker: return "highlighter"
            case .crayon: return "pencil.and.outline"
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

/// Forwards Apple Pencil double-tap (Pencil 2) and squeeze (Pencil Pro) to the
/// controller, honoring the user's system-preferred double-tap action.
final class PencilInteractionCoordinator: NSObject, UIPencilInteractionDelegate {
    weak var controller: MarkdownEditorController?
    init(_ controller: MarkdownEditorController) { self.controller = controller }

    func pencilInteraction(_ interaction: UIPencilInteraction,
                           didReceiveTap tap: UIPencilInteraction.Tap) {
        controller?.handlePencilDoubleTap()
    }

    func pencilInteraction(_ interaction: UIPencilInteraction,
                           didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        if squeeze.phase == .ended { controller?.showColorWheel = true }
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
        // Apple Pencil double-tap / squeeze.
        let pencilCoord = PencilInteractionCoordinator(self)
        let interaction = UIPencilInteraction()
        interaction.delegate = pencilCoord
        c.addInteraction(interaction)
        pencilCoordinator = pencilCoord
        if let saved = DrawingStore.load(entryID) { c.drawing = saved }
        c.backgroundColor = PaperTiles.pattern(for: ThemeStore.shared.paperRule,
                                               spacing: CGFloat(ThemeStore.shared.ruleSpacing)) ?? .clear
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
        isSelecting = false
        c.tool = ink.isEraser ? PKEraserTool(.vector)
                              : PKInkingTool(ink.pen.pk, color: ink.uiColor, width: ink.width)
    }

    /// Activate the lasso for selecting / moving / cutting strokes.
    func selectStrokes() {
        ink.isEraser = false
        isSelecting = true
        canvas?.tool = PKLassoTool()
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

    /// Re-apply the ruled / dot paper pattern live (rule or spacing changed).
    func refreshPaperPattern() {
        canvas?.backgroundColor = PaperTiles.pattern(for: ThemeStore.shared.paperRule,
                                                     spacing: CGFloat(ThemeStore.shared.ruleSpacing)) ?? .clear
    }

    func undoInk() { canvas?.undoManager?.undo() }

    func toggleRuler() {
        showRuler.toggle()
        canvas?.isRulerActive = showRuler
    }

    /// Respond to an Apple Pencil double-tap, honoring the user's Settings
    /// choice. Off the page, a double-tap simply enters drawing mode.
    func handlePencilDoubleTap() {
        guard isDrawing else { setDrawing(true); return }
        switch UIPencilInteraction.preferredTapAction {
        case .switchEraser:
            toggleEraser()
        case .switchPrevious:
            toggleEraser()
        case .showColorPalette, .showInkAttributes:
            showColorWheel = true
        case .ignore:
            break
        @unknown default:
            toggleEraser()
        }
    }

    private func toggleEraser() {
        if ink.isEraser {
            ink.isEraser = false
            ink.pen = previousPen
        } else {
            previousPen = ink.pen
            ink.isEraser = true
        }
        applyInk()
    }

    func clearInk() {
        canvas?.drawing = PKDrawing()
        saveDrawing()
    }

    func saveDrawing() {
        guard let id = drawingEntryID, let c = canvas else { return }
        DrawingStore.save(id, c.drawing)
    }
}

// MARK: - Paper backdrop

/// Repeating tile patterns for the ruled / dot-grid paper backdrop. Returned as
/// a pattern `UIColor` set on the canvas background, so it tiles across the full
/// document and scrolls with the content.
enum PaperTiles {
    static let defaultSpacing: CGFloat = 30

    static func pattern(for rule: PaperRule, spacing: CGFloat = defaultSpacing) -> UIColor? {
        let s = max(14, spacing)
        switch rule {
        case .plain: return nil
        case .ruled: return UIColor(patternImage: ruledTile(s))
        case .dots:  return UIColor(patternImage: dotTile(s))
        }
    }

    private static func ruledTile(_ spacing: CGFloat) -> UIImage {
        let size = CGSize(width: 24, height: spacing)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            MarkdownTheme.faint.withAlphaComponent(0.28).setFill()
            ctx.fill(CGRect(x: 0, y: size.height - 1, width: size.width, height: 1))
        }
    }

    private static func dotTile(_ spacing: CGFloat) -> UIImage {
        let size = CGSize(width: spacing, height: spacing)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            MarkdownTheme.faint.withAlphaComponent(0.45).setFill()
            let r: CGFloat = 1.3
            ctx.cgContext.fillEllipse(in: CGRect(x: size.width / 2 - r, y: size.height / 2 - r,
                                                 width: 2 * r, height: 2 * r))
        }
    }
}

// MARK: - Bespoke ink toolbar

/// Fern's own Pencil palette — the five theme inks plus a muted hue wheel that
/// stays in the theme's value space, pen/pencil/marker, width, eraser, undo.
struct InkToolbar: View {
    @Bindable var controller: MarkdownEditorController
    @State private var showWheel = false
    @State private var confirmClear = false
    @State private var collapsed = false

    /// The five theme accent colours as inks.
    private var themeInks: [(Double, Double, Double)] {
        AccentTone.allCases.map { ($0.light.0, $0.light.1, $0.light.2) }
    }
    private let ink = (0.129, 0.118, 0.102)   // near-black
    /// Line-weight presets (fine → bold).
    private let weights: [CGFloat] = [2, 5, 9, 16]

    /// Left-handers rest their hand on the left, so the tools cluster on the
    /// right; right-handers get them on the left (Procreate convention).
    private var trailing: Bool { ThemeStore.shared.handedness.controlsTrailing }

    var body: some View {
        Group {
            if collapsed { collapsedBar } else { fullBar }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(
            Rectangle().fill(Paper.raised.opacity(0.98))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Paper.line), alignment: .top)
        )
        .popover(isPresented: $showWheel) {
            MutedWheel(current: controller.ink.isEraser ? nil
                       : (controller.ink.r, controller.ink.g, controller.ink.b)) { rgb in
                controller.ink.setColor(rgb); controller.applyInk()
            }
            .frame(width: 240, height: 240)
            .padding(24)
            .presentationCompactAdaptation(.popover)
        }
        .confirmationDialog("Clear this drawing?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear drawing", role: .destructive) { controller.clearInk() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This erases all ink on this note. It can't be undone.")
        }
    }

    private var fullBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                if trailing { doneButton; hideButton; Spacer() }
                ForEach(InkSettings.Pen.allCases) { pen in
                    toolButton(pen.icon, on: !controller.ink.isEraser && controller.ink.pen == pen) {
                        controller.ink.pen = pen; controller.ink.isEraser = false; controller.applyInk()
                    }
                }
                toolButton("eraser", on: controller.ink.isEraser) {
                    controller.ink.isEraser = true; controller.applyInk()
                }
                toolButton("lasso", on: controller.isSelecting) { controller.selectStrokes() }
                toolButton("ruler", on: controller.showRuler) { controller.toggleRuler() }
                Divider().frame(height: 22)
                toolButton("arrow.uturn.backward") { controller.undoInk() }
                toolButton("trash") { confirmClear = true }
                if !trailing { Spacer(); hideButton; doneButton }
            }

            HStack(spacing: 14) {
                if trailing { Spacer() }
                ForEach(Array(weights.enumerated()), id: \.offset) { _, w in weightDot(w) }
                Divider().frame(height: 22)
                swatch(ink)
                ForEach(Array(themeInks.enumerated()), id: \.offset) { _, c in swatch(c) }
                paletteButton
                if !trailing { Spacer() }
            }
        }
    }

    /// Slim bar when the tools are hidden — a fresh, unobstructed canvas.
    private var collapsedBar: some View {
        HStack(spacing: 16) {
            if trailing { doneButton; Spacer() }
            Button { withAnimation(.easeOut(duration: 0.2)) { collapsed = false } } label: {
                Label("Tools", systemImage: "chevron.up")
                    .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
            }
            .buttonStyle(.plain)
            // The live ink color, so you know what you're drawing with while hidden.
            currentColorChip
            if !trailing { Spacer(); doneButton }
        }
        .frame(height: 30)
    }

    /// Shows the color currently in use (or the eraser) — also opens the wheel.
    private var currentColorChip: some View {
        Button { showWheel.toggle() } label: {
            ZStack {
                Circle().fill(controller.ink.isEraser ? Paper.raised : controller.ink.color)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(Paper.inkSoft.opacity(0.4), lineWidth: 1))
                if controller.ink.isEraser {
                    Image(systemName: "eraser").font(.system(size: 12)).foregroundStyle(Paper.inkSoft)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var paletteButton: some View {
        HStack(spacing: 8) {
            currentColorChip
            Button { showWheel.toggle() } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 18))
                    .foregroundStyle(Paper.inkSoft)
                    .frame(width: 30, height: 30)
            }
        }
    }

    private var hideButton: some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { collapsed = true } } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 16))
                .foregroundStyle(Paper.inkSoft)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hide tools")
    }

    private var doneButton: some View {
        Button("Done") { controller.setDrawing(false) }
            .font(.headlineSerif)
            .foregroundStyle(Paper.accent)
    }

    private func weightDot(_ w: CGFloat) -> some View {
        let selected = !controller.ink.isEraser && abs(controller.ink.width - w) < 0.5
        let d = 8 + w * 0.7
        return Circle()
            .fill(selected ? Paper.accent : Paper.inkSoft)
            .frame(width: d, height: d)
            .frame(width: 34, height: 30)
            .contentShape(Rectangle())
            .onTapGesture {
                controller.ink.width = w; controller.ink.isEraser = false; controller.applyInk()
            }
    }

    private func swatch(_ c: (Double, Double, Double)) -> some View {
        let selected = controller.ink.matches(c)
        return Circle()
            .fill(Color(red: c.0, green: c.1, blue: c.2))
            .frame(width: 28, height: 28)
            // Always-visible hairline (so dark swatches read against the bar)…
            .overlay(Circle().strokeBorder(Paper.inkSoft.opacity(0.4), lineWidth: 1))
            // …and a selection ring drawn *outside* the fill, in the accent, so it
            // shows on any color including near-black.
            .overlay(Circle().stroke(Paper.accent, lineWidth: selected ? 2.5 : 0).padding(-3))
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

/// Adjusts the gap between ruled / dot-grid lines, live. Shared by both apps.
struct LineSpacingSheet: View {
    let controller: MarkdownEditorController
    @Environment(\.dismiss) private var dismiss
    @State private var spacing: Double = ThemeStore.shared.ruleSpacing

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                VStack(alignment: .leading, spacing: 18) {
                    Text("The gap between ruled or dot-grid lines. Turn lines on from the Lines menu.")
                        .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.down.and.line.horizontal.and.arrow.up")
                            .foregroundStyle(Paper.inkSoft)
                        Slider(value: $spacing, in: 18...64, step: 1)
                            .tint(Paper.accent)
                        Text("\(Int(spacing))")
                            .font(.figure(15)).foregroundStyle(Paper.accent)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Line spacing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Paper.accent)
                }
            }
        }
        .presentationDetents([.height(200)])
        .onChange(of: spacing) { _, v in
            ThemeStore.shared.ruleSpacing = v
            controller.refreshPaperPattern()
        }
    }
}

/// A hue wheel confined to the theme's muted value space (low saturation and
/// brightness), so picked inks never look garish next to the paper.
struct MutedWheel: View {
    var current: (Double, Double, Double)? = nil
    var onPick: ((Double, Double, Double)) -> Void

    @State private var hue: Double?     // the live/selected hue, for the indicator

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
            ZStack {
                Circle()
                    .fill(AngularGradient(gradient: Gradient(colors: hues + [hues[0]]), center: .center))
                    .overlay(Circle().fill(Paper.raised).scaleEffect(0.32))
                // A ring marking the selected hue on the wheel.
                if let hue {
                    let angle = hue * 2 * .pi
                    let radius = side * 0.375
                    Circle()
                        .fill(Color(hue: hue, saturation: Self.saturation, brightness: Self.brightness))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .overlay(Circle().stroke(Paper.ink.opacity(0.35), lineWidth: 0.5).padding(-1))
                        .position(x: side / 2 + cos(angle) * radius,
                                  y: side / 2 + sin(angle) * radius)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { v in
                    let cx = side / 2, cy = side / 2
                    var a = atan2(v.location.y - cy, v.location.x - cx)
                    if a < 0 { a += 2 * .pi }
                    let h = a / (2 * .pi)
                    hue = h
                    onPick(Self.rgb(from: h))
                }
            )
        }
        .onAppear { if hue == nil { hue = Self.hue(of: current) } }
    }

    /// The wheel hue for a color (nil when there's no current color).
    private static func hue(of rgb: (Double, Double, Double)?) -> Double? {
        guard let rgb else { return nil }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(h)
    }

    static func rgb(from hue: Double) -> (Double, Double, Double) {
        let ui = UIColor(hue: CGFloat(hue), saturation: saturation, brightness: brightness, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}
