import SwiftUI
import SwiftData
import PhotosUI

/// Edit one binder document — title, synopsis, and body — on the shared
/// paper-and-ink Markdown editor.
struct DocumentEditorView: View {
    @Bindable var doc: RWDocument
    @Environment(\.modelContext) private var context
    @State private var controller = MarkdownEditorController()
    @State private var showPhotoPicker = false
    @State private var picks: [PhotosPickerItem] = []
    @State private var showingReader = false
    @State private var showingSnapshots = false
    @State private var snapshotTaken = false
    @State private var showLineSpacing = false
    @State private var editingTarget = false
    @State private var targetText = ""

    var body: some View {
        @Bindable var controller = controller
        return ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 8) {
                TextField("Untitled", text: $doc.title, axis: .vertical)
                    .font(.titleSerif)
                    .foregroundStyle(Paper.ink)
                    .padding(.top, 8)

                TextField("Synopsis — what happens here…", text: $doc.synopsis, axis: .vertical)
                    .font(.calloutSerif).italic()
                    .foregroundStyle(Paper.inkFaint)

                WordCountBar(words: doc.wordCount, minutes: doc.readMinutes,
                             status: doc.status, target: doc.wordTarget)

                MarkdownTextView(text: $doc.body, controller: controller,
                                 wash: false, entryID: doc.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Full width so ink reaches the edges; text keeps its margin.
                    .padding(.horizontal, -22)
            }
            .padding(.horizontal, 22)
            .safeAreaInset(edge: .bottom) {
                if controller.isDrawing { InkToolbar(controller: controller) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .focusedValue(\.editorController, controller)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Apple Pencil drawing — hidden on Mac (no Pencil hardware).
                #if !targetEnvironment(macCatalyst)
                Button {
                    Haptics.tap(); controller.setDrawing(!controller.isDrawing)
                } label: {
                    Image(systemName: controller.isDrawing ? "pencil.and.scribble" : "pencil.tip.crop.circle")
                        .foregroundStyle(controller.isDrawing ? Paper.accent : Paper.inkSoft)
                }
                #endif
                Button { showingReader = true } label: {
                    Image(systemName: "book").foregroundStyle(Paper.accent)
                }
                Menu {
                    Menu("Status") {
                        ForEach(RWStatus.allCases) { s in
                            Button { doc.status = s } label: {
                                if doc.status == s { Label(s.label, systemImage: "checkmark") }
                                else { Text(s.label) }
                            }
                        }
                    }
                    Button { beginEditTarget() } label: {
                        Label(doc.wordTarget > 0 ? "Word target: \(doc.wordTarget)" : "Word target…",
                              systemImage: "target")
                    }
                    Button { controller.presentFind() } label: {
                        Label("Find & Replace", systemImage: "magnifyingglass")
                    }
                    Divider()
                    Button { takeSnapshot() } label: {
                        Label("Take snapshot", systemImage: "camera.aperture")
                    }
                    Button { showingSnapshots = true } label: {
                        Label("Version history", systemImage: "clock.arrow.circlepath")
                    }
                    Divider()
                    Button {
                        ThemeStore.shared.handedness = ThemeStore.shared.handedness.flipped
                    } label: {
                        Label(ThemeStore.shared.handedness == .right ? "Left-handed layout" : "Right-handed layout",
                              systemImage: "hand.point.up.left")
                    }
                    Menu {
                        ForEach(PaperRule.allCases) { rule in
                            Button { ThemeStore.shared.paperRule = rule } label: {
                                if ThemeStore.shared.paperRule == rule { Label(rule.title, systemImage: "checkmark") }
                                else { Text(rule.title) }
                            }
                        }
                        Divider()
                        Button { showLineSpacing = true } label: {
                            Label("Line spacing…", systemImage: "arrow.up.and.down.text.horizontal")
                        }
                    } label: {
                        Label("Lines", systemImage: "line.3.horizontal")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(Paper.accent)
                }
            }
        }
        .sheet(isPresented: $showingReader) {
            NavigationStack { DocumentReader(doc: doc) }
        }
        .sheet(isPresented: $showingSnapshots) {
            SnapshotsView(doc: doc)
        }
        .sheet(isPresented: $showLineSpacing) { LineSpacingSheet(controller: controller) }
        .alert("Word target", isPresented: $editingTarget) {
            TextField("Words (0 = none)", text: $targetText).keyboardType(.numberPad)
            Button("Save") {
                doc.wordTarget = Int(targetText.filter(\.isNumber)) ?? 0
                doc.updatedAt = .now; try? context.save()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("A goal for just this document — shown on its card and in the editor.")
        }
        .overlay(alignment: .top) {
            if snapshotTaken {
                Text("Snapshot saved")
                    .font(.calloutSerif).foregroundStyle(Paper.bg)
                    .padding(.vertical, 8).padding(.horizontal, 16)
                    .background(Capsule().fill(Paper.ink))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $controller.showColorWheel) {
            MutedWheel(current: controller.ink.isEraser ? nil
                       : (controller.ink.r, controller.ink.g, controller.ink.b)) { rgb in
                controller.ink.setColor(rgb); controller.applyInk()
            }
                .frame(maxWidth: 280, maxHeight: 280)
                .padding(28)
                .presentationDetents([.height(360)])
                .presentationBackground(Paper.bg)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $picks,
                      maxSelectionCount: 1, matching: .images)
        .onChange(of: picks) { _, items in Task { await insertPhotos(items) } }
        .onChange(of: doc.title)    { _, _ in doc.updatedAt = .now }
        .onChange(of: doc.body)     { _, _ in doc.updatedAt = .now }
        .onChange(of: doc.synopsis) { _, _ in doc.updatedAt = .now }
        .onAppear { controller.requestPhoto = { showPhotoPicker = true } }
        .onDisappear {
            // Ink saves are debounced — flush pending strokes before leaving,
            // or a quick back after drawing loses them.
            controller.flushDrawing()
            try? context.save()
        }
    }

    private func beginEditTarget() {
        targetText = doc.wordTarget > 0 ? "\(doc.wordTarget)" : ""
        editingTarget = true
    }

    private func takeSnapshot() {
        let snap = RWSnapshot(documentID: doc.id, title: doc.title,
                              synopsis: doc.synopsis, body: doc.body,
                              wordCount: doc.wordCount)
        context.insert(snap)
        try? context.save()
        Haptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { snapshotTaken = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 0.3)) { snapshotTaken = false }
        }
    }

    private func insertPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let name = PhotoStore.save(data) {
                controller.insertPhoto(name)
            }
        }
        picks = []
    }
}

/// A thin ribbon under the synopsis: live word count, reading time, an optional
/// per-document target, and the status chip.
private struct WordCountBar: View {
    let words: Int
    let minutes: Int
    let status: RWStatus
    let target: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(target > 0 ? "\(words) / \(target) words" : "\(words) words")
                .font(.label).foregroundStyle(target > 0 && words >= target ? Paper.accent : Paper.inkFaint)
            Text("· \(minutes) min")
                .font(.label).foregroundStyle(Paper.inkFaint)
            if status != .none {
                Text("· \(status.label)")
                    .font(.label).foregroundStyle(Paper.accent)
            }
            Spacer()
        }
        .padding(.bottom, 2)
    }
}

/// Read-only rendering of a document, on the shared reader style.
private struct DocumentReader: View {
    let doc: RWDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !doc.title.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(doc.title).font(.masthead).foregroundStyle(Paper.ink)
                    }
                    RenderedBody(markdown: doc.body, wash: false, detectData: true)
                }
                .padding(.horizontal, 26).padding(.vertical, 16)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.tint(Paper.accent)
            }
        }
    }
}
