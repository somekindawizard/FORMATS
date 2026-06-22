import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

struct EntryEditorView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) private var context
    @FocusState private var bodyFocused: Bool
    @State private var locator = LocationProvider()

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 8) {
                TextField("Untitled", text: $entry.title, axis: .vertical)
                    .font(.titleSerif)
                    .foregroundStyle(Paper.ink)
                    .padding(.top, 8)

                MetadataRow(entry: entry, locator: locator)

                PhotoStrip(entry: entry)

                TagsEditor(entry: entry)
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: MarkdownExporter.markdown(for: entry)) {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(Paper.accent)
                }
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
        .onDisappear { try? context.save() }
        .onAppear { bodyFocused = true }
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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(entry.photoFileNames, id: \.self) { name in
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
        .frame(height: entry.photoFileNames.isEmpty ? 84 : 84)
        .onChange(of: picks) { _, items in
            Task { await load(items) }
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
