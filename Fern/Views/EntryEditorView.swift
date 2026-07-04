import SwiftUI
import SwiftData
import PhotosUI
import Photos
import CoreLocation

struct EntryEditorView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) private var context
    @Query private var allEntries: [Entry]
    @FocusState private var bodyFocused: Bool
    @State private var locator = LocationProvider()
    @State private var noteUnlocked = false
    @State private var controller = MarkdownEditorController()
    @State private var showingNewNotebook = false
    @State private var newNotebookName = ""
    @State private var shareItems: ShareItems?
    @State private var showInlinePhotoPicker = false
    @State private var inlinePhotoPicks: [PhotosPickerItem] = []

    private var notebooks: [String] {
        Array(Set(allEntries.compactMap(\.notebook))).sorted()
    }

    var body: some View {
        @Bindable var controller = controller
        return ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 8) {
                TextField("Untitled", text: $entry.title, axis: .vertical)
                    .font(.titleSerif)
                    .foregroundStyle(Paper.ink)
                    .padding(.top, 8)

                if let prompt = entry.prompt, !prompt.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text(prompt)
                            .font(.calloutSerif).italic()
                            .foregroundStyle(Paper.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button { entry.prompt = nil } label: {
                            Image(systemName: "xmark").font(.system(size: 10))
                                .foregroundStyle(Paper.inkFaint)
                        }
                    }
                }

                MetadataRow(entry: entry, locator: locator)

                PhotoStrip(entry: entry)

                TagsEditor(entry: entry)

                WritingRule()

                MarkdownTextView(text: $entry.body, controller: controller,
                                 wash: entry.photoWash, entryID: entry.id)
                    .focused($bodyFocused)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 22)
            .safeAreaInset(edge: .bottom) {
                if controller.isDrawing {
                    InkToolbar(controller: controller)
                } else if bodyFocused {
                    AccessoryBar(controller: controller, text: entry.body,
                                 onInsertPhoto: { showInlinePhotoPicker = true })
                }
            }

            if entry.isLocked && !noteUnlocked {
                lockVeil
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .hidesFernTabBar()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Haptics.tap()
                    controller.setDrawing(!controller.isDrawing)
                } label: {
                    Image(systemName: controller.isDrawing ? "pencil.and.scribble" : "pencil.tip.crop.circle")
                        .foregroundStyle(controller.isDrawing ? Paper.accent : Paper.inkSoft)
                }
                .accessibilityLabel(controller.isDrawing ? "Stop drawing" : "Draw")
                NavigationLink {
                    ReadingView(entry: entry)
                } label: {
                    Image(systemName: "book").foregroundStyle(Paper.accent)
                }
                Menu {
                    Button {
                        entry.isPinned.toggle()
                    } label: {
                        Label(entry.isPinned ? "Unpin" : "Pin",
                              systemImage: entry.isPinned ? "star.slash" : "star")
                    }
                    Button {
                        entry.isLocked.toggle()
                        if entry.isLocked { noteUnlocked = true }
                    } label: {
                        Label(entry.isLocked ? "Unlock note" : "Lock note",
                              systemImage: entry.isLocked ? "lock.open" : "lock")
                    }
                    Button {
                        entry.isFinished.toggle()
                    } label: {
                        Label(entry.isFinished ? "Mark as draft" : "Mark as finished",
                              systemImage: entry.isFinished ? "circle" : "checkmark.seal")
                    }
                    Menu("Notebook") {
                        Button("None") { entry.notebook = nil }
                        ForEach(notebooks, id: \.self) { nb in
                            Button { entry.notebook = nb } label: {
                                if entry.notebook == nb { Label(nb, systemImage: "checkmark") }
                                else { Text(nb) }
                            }
                        }
                        Divider()
                        Button("New notebook…") { showingNewNotebook = true }
                    }
                    Button { entry.photoWash.toggle() } label: {
                        Label(entry.photoWash ? "Photo wash: on" : "Photo wash",
                              systemImage: entry.photoWash ? "camera.filters" : "photo.on.rectangle")
                    }
                    Divider()
                    Button { shareCard() } label: {
                        Label("Share as card", systemImage: "photo")
                    }
                    Button { controller.presentFind() } label: {
                        Label("Find & Replace", systemImage: "magnifyingglass")
                    }
                    Button { exportPDF() } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                    ShareLink(item: MarkdownExporter.markdown(for: entry)) {
                        Label("Share as Markdown", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(Paper.accent)
                }
            }
        }
        .sheet(item: $shareItems) { ActivityView(items: $0.items) }
        .sheet(isPresented: $controller.showColorWheel) {
            MutedWheel { rgb in controller.ink.setColor(rgb); controller.applyInk() }
                .frame(maxWidth: 280, maxHeight: 280)
                .padding(28)
                .presentationDetents([.height(360)])
                .presentationBackground(Paper.bg)
        }
        .photosPicker(isPresented: $showInlinePhotoPicker, selection: $inlinePhotoPicks,
                      maxSelectionCount: 1, matching: .images)
        .onChange(of: inlinePhotoPicks) { _, items in
            Task { await insertInlinePhotos(items) }
        }
        .alert("New notebook", isPresented: $showingNewNotebook) {
            TextField("Name", text: $newNotebookName)
            Button("Create") {
                let name = newNotebookName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { entry.notebook = name }
                newNotebookName = ""
            }
            Button("Cancel", role: .cancel) { newNotebookName = "" }
        }
        .onChange(of: entry.title) { _, _ in entry.updatedAt = .now }
        .onChange(of: entry.body)  { _, _ in entry.updatedAt = .now }
        .onDisappear {
            // Discard a note that was started but never written in.
            if entry.isBlank {
                DrawingStore.delete(entry.id)
                SpotlightIndexer.deindex(id: entry.id)
                context.delete(entry)
            } else {
                ocrInkForSearch()
                SpotlightIndexer.index(entry)
            }
            try? context.save()
        }
        .onAppear {
            if entry.isLocked && !noteUnlocked {
                Task { await tryUnlockNote() }
            } else {
                bodyFocused = true
            }
        }
    }

    private var lockVeil: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Paper.accent)
                Text("This note is locked")
                    .font(.titleSerif)
                    .foregroundStyle(Paper.ink)
                Button("Unlock") { Task { await tryUnlockNote() } }
                    .buttonStyle(OutlineButtonStyle())
                    .frame(width: 200)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { Task { await tryUnlockNote() } }
    }

    private func tryUnlockNote() async {
        let ok = await BiometricLock.authenticateOnce(reason: "Unlock this note")
        if ok {
            withAnimation(.easeOut(duration: 0.3)) { noteUnlocked = true }
            bodyFocused = true
        }
    }

    /// Recognize the note's ink (if any) so handwriting is searchable.
    private func ocrInkForSearch() {
        guard let d = DrawingStore.load(entry.id), !d.strokes.isEmpty,
              d.bounds.width > 1, d.bounds.height > 1 else {
            if !entry.inkText.isEmpty { entry.inkText = "" }
            return
        }
        let image = d.image(from: d.bounds, scale: 2)
        Task { @MainActor in
            let text = await HandwritingOCR.recognize(image)
            if text != entry.inkText {
                entry.inkText = text
                SpotlightIndexer.index(entry)
                try? context.save()
            }
        }
    }

    /// Save picked images and drop a `fern://` token at the caret for each.
    private func insertInlinePhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let name = PhotoStore.save(data) {
                entry.photoFileNames.append(name)
                controller.insertPhoto(name)
            }
        }
        inlinePhotoPicks = []
    }

    @MainActor
    private func exportPDF() {
        if let url = PDFExporter.pdf(for: entry) {
            shareItems = ShareItems(items: [url])
        }
    }

    @MainActor
    private func shareCard() {
        let renderer = ImageRenderer(content: PaperCard(entry: entry))
        renderer.scale = 2
        if let image = renderer.uiImage {
            shareItems = ShareItems(items: [image])
        }
    }
}

// MARK: - Writing rule

/// A quiet hairline that marks where the header ends and the writing begins.
/// Fades at both ends around a small centered leaf — a soft Fern fingerprint.
private struct WritingRule: View {
    var body: some View {
        HStack(spacing: 12) {
            LinearGradient(colors: [Paper.line.opacity(0), Paper.line.opacity(0.9)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            Image(systemName: "leaf")
                .font(.system(size: 9))
                .foregroundStyle(Paper.inkFaint)
            LinearGradient(colors: [Paper.line.opacity(0.9), Paper.line.opacity(0)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Metadata row (date · mood · place)

private struct MetadataRow: View {
    @Bindable var entry: Entry
    let locator: LocationProvider
    @State private var locating = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(entry.createdAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))

                Menu {
                    Button("No mood") { entry.mood = nil }
                    ForEach(Mood.allCases) { mood in
                        Button { entry.mood = mood } label: {
                            Label(mood.label, systemImage: mood.symbol)
                        }
                    }
                } label: {
                    if let mood = entry.mood {
                        chip("● \(mood.label.lowercased())", accent: true)
                    } else {
                        chip("mood")
                    }
                }

                if let place = entry.placeName {
                    Button {
                        entry.placeName = nil; entry.latitude = nil; entry.longitude = nil
                        entry.weatherSymbol = nil; entry.weatherTempC = nil
                    } label: { chip(place) }
                    .buttonStyle(.plain)
                } else {
                    Button { Task { await addPlace() } } label: {
                        chip(locating ? "finding…" : "add place")
                    }
                    .buttonStyle(.plain)
                    .disabled(locating)
                }

                if let symbol = entry.weatherSymbol, let temp = entry.weatherTempC {
                    Label("\(Int(temp.rounded()))°", systemImage: symbol)
                        .font(.calloutSerif)
                        .foregroundStyle(Paper.inkSoft)
                        .padding(.vertical, 5).padding(.horizontal, 10)
                        .background(Capsule().stroke(Paper.line, lineWidth: 1)
                            .background(Capsule().fill(Paper.raised)))
                }
                if let nb = entry.notebook {
                    Label(nb, systemImage: "books.vertical")
                        .font(.calloutSerif)
                        .foregroundStyle(Paper.inkSoft)
                        .padding(.vertical, 5).padding(.horizontal, 10)
                        .background(Capsule().stroke(Paper.line, lineWidth: 1)
                            .background(Capsule().fill(Paper.raised)))
                }
            }
        }
    }

    private func addPlace() async {
        locating = true
        defer { locating = false }
        if let place = await locator.currentPlace() {
            entry.placeName = place.name
            entry.latitude = place.latitude
            entry.longitude = place.longitude
            let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
            if let weather = await WeatherProvider.current(for: location) {
                entry.weatherSymbol = weather.symbol
                entry.weatherTempC = weather.tempC
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

// MARK: - Photos

private struct PhotoStrip: View {
    @Bindable var entry: Entry
    @State private var picks: [PhotosPickerItem] = []

    /// Only photos that aren't embedded inline in the body — those show in text.
    private var loosePhotos: [String] {
        entry.photoFileNames.filter { !entry.body.contains("fern://\($0)") }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(loosePhotos, id: \.self) { name in
                    if let image = PhotoStore.load(name) {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button { remove(name) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, Paper.ink.opacity(0.5))
                                        .padding(3)
                                }
                            }
                    }
                }
                PhotosPicker(selection: $picks, maxSelectionCount: 4, matching: .images) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Paper.line, lineWidth: 1)
                        .frame(width: 76, height: 76)
                        .overlay(Image(systemName: "plus").foregroundStyle(Paper.inkFaint))
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: 84)
        .onChange(of: picks) { _, items in
            Task { await load(items) }
        }
        .task {
            // Ask once for full photo access so Fern leaves "limited" mode and
            // appears in Settings ▸ Privacy ▸ Photos with a Full Access option.
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
                _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            }
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let name = PhotoStore.save(data) {
                entry.photoFileNames.append(name)
            }
        }
        picks = []
    }

    private func remove(_ name: String) {
        entry.photoFileNames.removeAll { $0 == name }
        PhotoStore.delete(name)
    }
}

// MARK: - Tags

/// Add/remove tags. Tags are normalized (lowercased, no '#', no spaces) and
/// stored on `entry.tagNames`.
private struct TagsEditor: View {
    @Bindable var entry: Entry
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !entry.tagNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entry.tagNames, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag)").font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                                Button {
                                    entry.tagNames.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 9))
                                        .foregroundStyle(Paper.inkFaint)
                                }
                            }
                            .padding(.vertical, 5).padding(.horizontal, 10)
                            .background(Capsule().stroke(Paper.line, lineWidth: 1)
                                .background(Capsule().fill(Paper.raised)))
                        }
                    }
                }
            }
            TextField("Add a tag", text: $newTag)
                .font(.calloutSerif)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(addTag)
                .submitLabel(.done)
        }
    }

    private func addTag() {
        let normalized = newTag
            .lowercased()
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
        guard !normalized.isEmpty, !entry.tagNames.contains(normalized) else {
            newTag = ""; return
        }
        entry.tagNames.append(normalized)
        newTag = ""
    }
}

#Preview {
    let container = SampleData.previewContainer()
    let entry = (try? container.mainContext.fetch(FetchDescriptor<Entry>()))?.first
        ?? Entry(title: "Preview", body: "Hello *world*.", collection: .journal)
    return NavigationStack { EntryEditorView(entry: entry) }
        .modelContainer(container)
}
