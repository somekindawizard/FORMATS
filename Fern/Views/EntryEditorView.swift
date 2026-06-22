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
                TextField("Untitled", text: $entry.title, axis: .vertical)
                    .font(.titleSerif)
                    .foregroundStyle(Paper.ink)
                    .padding(.top, 8)

                ChipRow(entry: entry)

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
/// arrive in Plan 4 — for now they render as read-only chips when set.
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
