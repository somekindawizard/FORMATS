import SwiftUI
import CloudKit

/// The shared "Austin & me" notebook — a list of collaborative notes, an invite
/// button (CloudKit share sheet), and a lightweight editor that saves to
/// CloudKit. Separate from the SwiftData library.
struct SharedNotebookView: View {
    @State private var store = SharedNotebookStore.shared
    @State private var share: CKShare?
    @State private var showInvite = false
    @State private var editing: SharedNote?
    @State private var loading = true

    var body: some View {
        ZStack {
            PaperBackground()
            if store.notes.isEmpty && !loading {
                emptyState
            } else {
                List {
                    ForEach(store.notes) { note in
                        Button { editing = note } label: { row(note) }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { idx in
                        let targets = idx.map { store.notes[$0] }
                        Task { for n in targets { await store.delete(n) } }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("You & \(store.partnerName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { invite() } label: { Image(systemName: "person.crop.circle.badge.plus") }
                    .foregroundStyle(Paper.accent)
                Button { addNote() } label: { Image(systemName: "square.and.pencil") }
                    .foregroundStyle(Paper.accent)
            }
        }
        .task { await refresh() }
        .refreshable { await store.refresh() }
        .sheet(isPresented: $showInvite) {
            if let share {
                CloudSharingView(share: share, container: store.containerForSharing)
                    .ignoresSafeArea()
            }
        }
        .sheet(item: $editing, onDismiss: { Task { await store.refresh() } }) { note in
            SharedNoteEditor(note: note)
        }
    }

    private func refresh() async {
        await store.refresh()
        loading = false
    }

    private func invite() {
        Task {
            share = try? await store.ensureShare()
            showInvite = share != nil
        }
    }

    private func addNote() {
        Task { if let note = await store.addNote() { editing = note } }
    }

    private func row(_ note: SharedNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(note.modified.formatted(.dateTime.month(.abbreviated).day())).sectionLabel()
                if !note.author.isEmpty {
                    Text("· \(note.author.lowercased())").font(.label).foregroundStyle(Paper.accent)
                }
            }
            Text(note.displayTitle).font(.headlineSerif).foregroundStyle(Paper.ink)
            if !note.body.isEmpty {
                Text(MarkdownRender.plainText(note.body))
                    .font(.calloutSerif).foregroundStyle(Paper.inkSoft).lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 34)).foregroundStyle(Paper.inkFaint)
            Text("A notebook you and \(store.partnerName) share")
                .font(.titleSerif).foregroundStyle(Paper.ink)
                .multilineTextAlignment(.center)
            Text("Invite \(store.partnerName), then start a note — you'll both see and edit it.")
                .font(.bodySerif).foregroundStyle(Paper.inkSoft)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Invite \(store.partnerName)") { invite() }
                .buttonStyle(InkButtonStyle()).frame(width: 240)
        }
    }
}

/// The collaborative note editor — same Markdown editor, saving to CloudKit
/// (debounced) instead of SwiftData.
private struct SharedNoteEditor: View {
    let note: SharedNote
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var bodyText: String
    @State private var controller = MarkdownEditorController()
    @State private var saveTask: Task<Void, Never>?
    private let store = SharedNotebookStore.shared

    init(note: SharedNote) {
        self.note = note
        _title = State(initialValue: note.title)
        _bodyText = State(initialValue: note.body)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Untitled", text: $title, axis: .vertical)
                        .font(.titleSerif).foregroundStyle(Paper.ink).padding(.top, 8)
                    MarkdownTextView(text: $bodyText, controller: controller)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 22)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { save(); dismiss() }.foregroundStyle(Paper.accent)
                }
            }
        }
        .onChange(of: title) { _, _ in scheduleSave() }
        .onChange(of: bodyText) { _, _ in scheduleSave() }
        .onDisappear { save() }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await store.save(note, title: title, body: bodyText)
        }
    }

    private func save() {
        saveTask?.cancel()
        Task { await store.save(note, title: title, body: bodyText) }
    }
}

/// Presents the system CloudKit share sheet to invite people.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? { "Fern — a shared notebook" }
        func cloudSharingController(_ csc: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {}
    }
}
