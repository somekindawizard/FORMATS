import SwiftUI
import PencilKit
import UIKit.UIGestureRecognizerSubclass

// MARK: - Ink settings

/// The current Pencil selection: pen type, color, width, eraser.
struct InkSettings: Codable {
    enum Pen: String, CaseIterable, Identifiable, Codable {
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

/// Remembers each note's last-used ink (pen, color, width) so a note reopens
/// with the tools you left it with. Keyed by the note's id in UserDefaults.
enum InkPrefsStore {
    private static func key(_ id: UUID) -> String { "fern.ink.\(id.uuidString)" }

    static func save(_ id: UUID, _ settings: InkSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key(id))
        }
    }

    static func load(_ id: UUID) -> InkSettings? {
        guard let data = UserDefaults.standard.data(forKey: key(id)) else { return nil }
        return try? JSONDecoder().decode(InkSettings.self, from: data)
    }

    /// Clean up when a note is deleted (otherwise the plist grows forever).
    static func remove(_ id: UUID) {
        UserDefaults.standard.removeObject(forKey: key(id))
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
        // Grow the drawing room as ink extends downward, and keep the ink word
        // count fresh.
        controller?.resizeCanvas()
        controller?.scheduleInkWordCount()
    }
    /// A tool started touching the page. Auto-enter drawing mode if a Pencil
    /// woke us (the reliable "auto-detect Apple Pencil" hook), and tuck the
    /// toolbar away so it's never under your hand while you make marks.
    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        if controller?.isDrawing == false { controller?.setDrawing(true) }
        controller?.inkToolsCollapsed = true
    }
}

/// Lets you scroll the document while drawing with a **two-finger drag** — the
/// pencil keeps drawing, two fingers pan the page (so you can reach and draw on
/// any part of a long note). Additive: it never touches the single-finger /
/// pencil drawing path.
final class CanvasScrollGesture: NSObject, UIGestureRecognizerDelegate {
    weak var textView: UITextView?
    weak var controller: MarkdownEditorController?
    private var startOffset: CGPoint = .zero

    @objc func handle(_ g: UIPanGestureRecognizer) {
        guard let tv = textView else { return }
        switch g.state {
        case .began:
            startOffset = tv.contentOffset
        case .changed:
            let t = g.translation(in: tv)
            let minY = -tv.adjustedContentInset.top
            let maxY = max(minY, tv.contentSize.height + tv.adjustedContentInset.bottom - tv.bounds.height)
            let y = min(max(startOffset.y - t.y, minY), maxY)
            tv.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        default:
            break
        }
    }

    // Procreate gestures: two-finger tap = undo, three-finger tap = redo.
    @objc func undoTap() { Haptics.tap(); controller?.undoInk() }
    @objc func redoTap() { Haptics.tap(); controller?.redoInk() }

    /// A Pencil touched the page while not drawing — enter drawing mode. This
    /// wake-up touch is consumed by the mode switch (UIKit won't re-route an
    /// in-flight touch to the newly interactive canvas), so it can't mark;
    /// the haptic makes the handshake feel intentional rather than broken.
    /// On hover-capable hardware `pencilHover` pre-arms before contact and
    /// the first stroke marks normally.
    @objc func pencilBegan() {
        if controller?.isDrawing == false {
            Haptics.tap()
            controller?.setDrawing(true)
        }
    }

    /// Pencil hovering over the page (Pencil 2 / Pro on hover-capable iPads) —
    /// enter drawing mode BEFORE the tip lands so the first stroke draws.
    @objc func pencilHover(_ g: UIHoverGestureRecognizer) {
        guard g.state == .began || g.state == .changed else { return }
        if controller?.isDrawing == false { controller?.setDrawing(true) }
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

/// Recognizes an Apple Pencil touch on the text view **only while not already
/// drawing**, so it can auto-enter drawing mode without ever interfering with
/// the live canvas (which sits above the text once drawing).
final class PencilTouchGesture: UIGestureRecognizer {
    weak var controller: MarkdownEditorController?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if controller?.isDrawing == true { state = .failed; return }
        state = touches.contains(where: { $0.type == .pencil }) ? .recognized : .failed
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

/// A canvas with its OWN undo stack. `UIView.undoManager` resolves up the
/// responder chain, and as a subview of the text view the canvas landed on the
/// TEXT undo manager — ink and typing undos interleaved on one stack, so a
/// two-finger undo tap while drawing could silently revert the last typed
/// sentence (off-screen, no feedback). Ink undo is now isolated.
final class InkCanvasView: PKCanvasView {
    private let inkUndo = UndoManager()
    override var undoManager: UndoManager? { inkUndo }
}

extension MarkdownEditorController {

    /// Attach a transparent PencilKit canvas over the text, sized to (and
    /// scrolling with) the document. Interactive only in drawing mode; a Pencil
    /// touch auto-enters that mode (see PencilTouchGesture).
    func setupCanvas(on textView: UITextView, entryID: UUID) {
        guard canvas == nil else { return }
        let c = InkCanvasView()
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
        // On the canvas (which receives touches while drawing): two-finger drag
        // scrolls, two-/three-finger taps undo/redo (Procreate).
        let g = CanvasScrollGesture()
        g.textView = textView
        g.controller = self
        let scrollPan = UIPanGestureRecognizer(target: g, action: #selector(CanvasScrollGesture.handle(_:)))
        scrollPan.minimumNumberOfTouches = 2
        scrollPan.maximumNumberOfTouches = 2
        scrollPan.delegate = g
        c.addGestureRecognizer(scrollPan)
        let undoTap = UITapGestureRecognizer(target: g, action: #selector(CanvasScrollGesture.undoTap))
        undoTap.numberOfTouchesRequired = 2
        undoTap.delegate = g
        c.addGestureRecognizer(undoTap)
        let redoTap = UITapGestureRecognizer(target: g, action: #selector(CanvasScrollGesture.redoTap))
        redoTap.numberOfTouchesRequired = 3
        redoTap.delegate = g
        c.addGestureRecognizer(redoTap)
        scrollPanHandler = g
        // Auto-detect: a Pencil touch on the text enters drawing mode. Fails when
        // already drawing, so it never interferes with the live canvas.
        let pencilDetect = PencilTouchGesture(target: g, action: #selector(CanvasScrollGesture.pencilBegan))
        pencilDetect.controller = self
        pencilDetect.cancelsTouchesInView = true
        pencilDetect.delegate = g
        textView.addGestureRecognizer(pencilDetect)
        // Hover pre-arm: a Pencil approaching the page enters drawing mode
        // before contact, so the very first stroke marks (the touch-based
        // fallback above consumes its wake-up stroke). Pencil hover only —
        // trackpad/mouse pointers must not trigger it.
        let hover = UIHoverGestureRecognizer(target: g, action: #selector(CanvasScrollGesture.pencilHover(_:)))
        hover.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        textView.addGestureRecognizer(hover)
        if let saved = DrawingStore.load(entryID) { c.drawing = saved }
        c.backgroundColor = PaperTiles.pattern(for: ThemeStore.shared.paperRule,
                                               spacing: CGFloat(ThemeStore.shared.ruleSpacing)) ?? .clear
        textView.addSubview(c)
        canvas = c
        drawingEntryID = entryID
        ink = InkPrefsStore.load(entryID) ?? InkSettings()   // this note's last ink
        applyInk()
        resizeCanvas()
        // Keep the ink surface matched to the text's growing content height.
        contentSizeObservation = textView.observe(\.contentSize, options: [.initial, .new]) { [weak self] _, _ in
            self?.resizeCanvas()
        }
    }

    /// Size the ink surface (and the scrollable room) so:
    ///  • your handwriting is **always** reachable — even below the text and even
    ///    when not drawing (the old bug: room only existed mid-draw, so ink under
    ///    the text became unscrollable the moment you tapped Done);
    ///  • while drawing, a generous slab of blank room sits below the lowest
    ///    content and **grows** as your ink extends downward, so it feels endless.
    func resizeCanvas() {
        guard let tv = textView, let c = canvas else { return }
        let w = tv.contentSize.width > 0 ? tv.contentSize.width : tv.bounds.width
        // The scroll view's reachable bottom is measured from contentSize.height
        // (the *typed text* height) — NOT max(content, bounds). A handwritten note
        // has little text, so measuring from `content` is what lets you actually
        // scroll down to ink that sits far below the text.
        let content = tv.contentSize.height
        let inkBottom = c.drawing.strokes.isEmpty ? 0 : ceil(c.drawing.bounds.maxY)
        // Bottom inset = how far past the text you can scroll. Must reach the ink
        // (inkBottom − content, + pad); while drawing keep a growing blank slab.
        let reachInk = max(0, inkBottom + 60 - content)
        let extra = isDrawing ? max(1200, inkBottom + 500 - content) : reachInk
        if abs(tv.contentInset.bottom - extra) > 0.5 { tv.contentInset.bottom = extra }
        inkRoomInset = extra   // caret-reveal subtracts this (room ≠ occlusion)
        // The canvas must span the whole scrollable extent (text + the room).
        let h = content + extra
        if abs(c.frame.height - h) > 0.5 || abs(c.frame.width - w) > 0.5 {
            c.frame = CGRect(x: 0, y: 0, width: w, height: h)
        }
    }

    /// Build the active tool from the current settings, and remember this note's
    /// ink choice (pen/color/width) so it's restored next time.
    func applyInk() {
        guard let c = canvas else { return }
        if let id = drawingEntryID { InkPrefsStore.save(id, ink) }
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
            inkToolsCollapsed = false        // show the tools when you enter
            applyInk()
            textView?.resignFirstResponder()
            scheduleInkWordCount()
        } else {
            saveDrawing()
        }
        // resizeCanvas sets the scroll room + inset for the current mode.
        resizeCanvas()
        // Leaving draw mode shrinks the room; if the user was scrolled deep in
        // it, the offset is now out of range — clamp so the next touch doesn't
        // rubber-band the page in a jarring jump.
        if !active, let tv = textView {
            let maxY = max(-tv.adjustedContentInset.top,
                           tv.contentSize.height + tv.contentInset.bottom - tv.bounds.height)
            if tv.contentOffset.y > maxY {
                tv.setContentOffset(CGPoint(x: 0, y: maxY), animated: true)
            }
        }
    }

    /// Re-apply the ruled / dot paper pattern live (rule or spacing changed).
    func refreshPaperPattern() {
        canvas?.backgroundColor = PaperTiles.pattern(for: ThemeStore.shared.paperRule,
                                                     spacing: CGFloat(ThemeStore.shared.ruleSpacing)) ?? .clear
    }

    func undoInk() { canvas?.undoManager?.undo() }
    func redoInk() { canvas?.undoManager?.redo() }

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
    /// Size of the area the pill can roam within (for clamping the drag).
    var bounds: CGSize = .zero
    @State private var showWheel = false
    @State private var confirmClear = false
    /// Reveal the line-weight dots (Procreate-style: a second tap on the brush).
    @State private var showWeights = false
    /// Free position of the pill on screen (draggable via its grip).
    @State private var offset: CGSize = .zero
    @GestureState private var drag: CGSize = .zero

    private var collapsed: Bool { controller.inkToolsCollapsed }

    /// The five theme accent colours as inks.
    private var themeInks: [(Double, Double, Double)] {
        AccentTone.allCases.map { ($0.light.0, $0.light.1, $0.light.2) }
    }
    private let ink = (0.129, 0.118, 0.102)   // near-black
    /// Line-weight presets (fine → bold).
    private let weights: [CGFloat] = [2, 5, 9, 16]

    var body: some View {
        Group {
            if collapsed { collapsedBar } else { fullBar }
        }
        .padding(.horizontal, collapsed ? 6 : 16)
        .padding(.vertical, collapsed ? 6 : 12)
        .background { pillBackground }
        .offset(x: offset.width + drag.width, y: offset.height + drag.height)
        .padding(.bottom, 10)
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

    /// A rounded, floating pill — no longer an edge-to-edge bar.
    private var pillBackground: some View {
        RoundedRectangle(cornerRadius: collapsed ? 28 : 22, style: .continuous)
            .fill(Paper.raised.opacity(0.99))
            .overlay(RoundedRectangle(cornerRadius: collapsed ? 28 : 22, style: .continuous)
                .strokeBorder(Paper.line, lineWidth: 1))
            .shadow(color: Paper.ink.opacity(0.18), radius: 14, y: 5)
    }

    /// Drag anywhere on the pill's grip to reposition it, clamped to the screen.
    private var dragGesture: some Gesture {
        DragGesture()
            .updating($drag) { v, s, _ in s = v.translation }
            .onEnded { v in
                var o = CGSize(width: offset.width + v.translation.width,
                               height: offset.height + v.translation.height)
                if bounds != .zero {
                    let mx = bounds.width / 2, my = bounds.height
                    o.width = min(max(o.width, -mx + 40), mx - 40)
                    o.height = min(max(o.height, -my + 120), 20)
                }
                offset = o
            }
    }

    /// A grip handle — the drag affordance for moving the pill.
    private var grip: some View {
        Capsule().fill(Paper.line)
            .frame(width: 30, height: 5)
            .frame(width: 44, height: 26)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .accessibilityLabel("Move tools")
    }

    private var fullBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                grip
                doneButton
                barDivider
                toolButton("arrow.uturn.backward") { controller.undoInk() }
                toolButton("arrow.uturn.forward")  { controller.redoInk() }
                barDivider
                brushes
                barDivider
                toolButton("eraser", on: controller.ink.isEraser) {
                    controller.ink.isEraser = true; showWeights = false; controller.applyInk()
                }
                toolButton("lasso", on: controller.isSelecting) { controller.selectStrokes() }
                toolButton("ruler", on: controller.showRuler) { controller.toggleRuler() }
                toolButton("trash") { confirmClear = true }
                hideButton
            }
            if showWeights { weightRow }
            colorRow
        }
    }

    /// The six pens. Tapping the already-selected pen discloses the sizes.
    private var brushes: some View {
        HStack(spacing: 14) {
            ForEach(InkSettings.Pen.allCases) { pen in
                let selected = !controller.ink.isEraser && controller.ink.pen == pen
                toolButton(pen.icon, on: selected) {
                    if selected {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { showWeights.toggle() }
                    } else {
                        controller.ink.pen = pen; controller.ink.isEraser = false
                        controller.applyInk()
                    }
                }
            }
        }
    }

    private var weightRow: some View {
        HStack(spacing: 14) {
            ForEach(Array(weights.enumerated()), id: \.offset) { _, w in weightDot(w) }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var colorRow: some View {
        HStack(spacing: 12) {
            swatch(ink)
            ForEach(Array(themeInks.enumerated()), id: \.offset) { _, c in swatch(c) }
            paletteButton
        }
    }

    private var barDivider: some View {
        Rectangle().fill(Paper.line).frame(width: 1, height: 26)
    }

    /// When hidden, a small Notes-style circle floats (showing the current ink
    /// color); tap it to bring the tools back. Done sits beside it.
    private var collapsedBar: some View {
        HStack(spacing: 12) {
            grip
            expandCircle
            doneButton
        }
    }

    private var expandCircle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { controller.inkToolsCollapsed = false }
        } label: {
            ZStack {
                Circle().fill(Paper.raised)
                    .overlay(Circle().strokeBorder(Paper.line, lineWidth: 1))
                    .shadow(color: Paper.ink.opacity(0.16), radius: 5, y: 2)
                    .frame(width: 48, height: 48)
                if controller.ink.isEraser {
                    Image(systemName: "eraser.fill").font(.system(size: 16)).foregroundStyle(Paper.inkSoft)
                } else {
                    Circle().fill(controller.ink.color)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show tools")
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
        Button { withAnimation(.easeOut(duration: 0.2)) { controller.inkToolsCollapsed = true } } label: {
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
