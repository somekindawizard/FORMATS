import SwiftUI
import SwiftData

/// Version history for a document — every snapshot you've taken, newest first.
/// Read one, restore it (the current text is snapshotted first, so nothing is
/// lost), or delete it.
struct SnapshotsView: View {
    let doc: RWDocument
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var snapshots: [RWSnapshot]
    @State private var previewing: RWSnapshot?

    init(doc: RWDocument) {
        self.doc = doc
        let did = doc.id
        _snapshots = Query(filter: #Predicate<RWSnapshot> { $0.documentID == did },
                           sort: [SortDescriptor(\RWSnapshot.createdAt, order: .reverse)])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                if snapshots.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(snapshots) { snap in
                            Button { previewing = snap } label: { row(snap) }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteSnapshots)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Version history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.tint(Paper.accent)
                }
            }
            .sheet(item: $previewing) { snap in
                SnapshotPreview(snapshot: snap) { restore(snap) }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34)).foregroundStyle(Paper.accent.opacity(0.7))
            Text("No snapshots yet")
                .font(.headlineSerif).foregroundStyle(Paper.ink)
            Text("Take a snapshot before a big revision — you can always come back to it.")
                .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func row(_ snap: RWSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(snap.createdAt.formatted(.dateTime.month().day().hour().minute()))
                    .font(.bodySerif).foregroundStyle(Paper.ink)
                if !snap.label.isEmpty {
                    Text("· \(snap.label)")
                        .font(.label).foregroundStyle(Paper.accent)
                }
            }
            Text("\(snap.wordCount) words")
                .font(.label).foregroundStyle(Paper.inkFaint)
        }
        .padding(.vertical, 5)
    }

    private func restore(_ snap: RWSnapshot) {
        // Snapshot the current text first so a restore is itself reversible.
        let current = RWSnapshot(documentID: doc.id, title: doc.title,
                                 synopsis: doc.synopsis, body: doc.body,
                                 label: "before restore", wordCount: doc.wordCount)
        context.insert(current)
        doc.title = snap.title
        doc.synopsis = snap.synopsis
        doc.body = snap.body
        doc.updatedAt = .now
        try? context.save()
        Haptics.success()
        previewing = nil
        dismiss()
    }

    private func deleteSnapshots(_ offsets: IndexSet) {
        Haptics.tap()
        for i in offsets { context.delete(snapshots[i]) }
        try? context.save()
    }
}

/// Read a snapshot's text, with a Restore action.
private struct SnapshotPreview: View {
    let snapshot: RWSnapshot
    let onRestore: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !snapshot.title.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(snapshot.title).font(.masthead).foregroundStyle(Paper.ink)
                        }
                        RenderedBody(markdown: snapshot.body, wash: false)
                    }
                    .padding(.horizontal, 26).padding(.vertical, 16)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle(snapshot.createdAt.formatted(.dateTime.month().day().hour().minute()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.tint(Paper.inkSoft)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore", action: onRestore)
                        .tint(Paper.accent).fontWeight(.semibold)
                }
            }
        }
    }
}
