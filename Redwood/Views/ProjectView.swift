import SwiftUI
import SwiftData

/// A project's binder — the tree of folders and documents. Recurses into
/// folders. New nodes, reorder, and delete all live here.
struct ProjectView: View {
    let project: RWProject
    var parent: RWDocument? = nil

    @Environment(\.modelContext) private var context
    @Query private var allDocs: [RWDocument]

    init(project: RWProject, parent: RWDocument? = nil) {
        self.project = project
        self.parent = parent
        let pid = project.id
        _allDocs = Query(filter: #Predicate<RWDocument> { $0.projectID == pid },
                         sort: [SortDescriptor(\RWDocument.order)])
    }

    /// Direct children of this level (nil parent = project root).
    private var nodes: [RWDocument] {
        allDocs.filter { $0.parentID == parent?.id }.sorted { $0.order < $1.order }
    }

    private var totalWords: Int {
        allDocs.filter { !$0.isFolder }.reduce(0) { $0 + $1.wordCount }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            List {
                ForEach(nodes) { node in
                    binderRow(node)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)

                if parent == nil {
                    footer
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
        .navigationTitle(parent?.displayTitle ?? project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { add(isFolder: false) } label: {
                        Label("New document", systemImage: "doc")
                    }
                    Button { add(isFolder: true) } label: {
                        Label("New folder", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "plus.circle").foregroundStyle(Paper.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func binderRow(_ node: RWDocument) -> some View {
        if node.isFolder {
            NavigationLink {
                ProjectView(project: project, parent: node)
            } label: {
                BinderNodeRow(node: node, childCount: childCount(of: node))
            }
        } else {
            NavigationLink(value: node) {
                BinderNodeRow(node: node, childCount: 0)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(totalWords) words")
                .font(.label).foregroundStyle(Paper.inkFaint)
            Spacer()
        }
        .padding(.top, 8)
    }

    private func childCount(of folder: RWDocument) -> Int {
        allDocs.filter { $0.parentID == folder.id }.count
    }

    // MARK: mutations

    private func add(isFolder: Bool) {
        Haptics.tap()
        let order = (nodes.map(\.order).max() ?? -1) + 1
        let node = RWDocument(projectID: project.id, isFolder: isFolder,
                              order: order, parentID: parent?.id)
        context.insert(node)
        project.updatedAt = .now
        try? context.save()
    }

    private func move(_ offsets: IndexSet, _ destination: Int) {
        var ordered = nodes
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (i, node) in ordered.enumerated() { node.order = i }
        try? context.save()
    }

    private func delete(_ offsets: IndexSet) {
        Haptics.tap(.medium)
        for i in offsets {
            let node = nodes[i]
            deleteRecursively(node)
        }
        project.updatedAt = .now
        try? context.save()
    }

    /// Delete a node and, if it's a folder, everything beneath it.
    private func deleteRecursively(_ node: RWDocument) {
        if node.isFolder {
            for child in allDocs.filter({ $0.parentID == node.id }) {
                deleteRecursively(child)
            }
        }
        DrawingStore.delete(node.id)
        context.delete(node)
    }
}

private struct BinderNodeRow: View {
    let node: RWDocument
    let childCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: node.isFolder ? "folder" : "doc.text")
                .font(.system(size: 15))
                .foregroundStyle(node.isFolder ? Paper.accent : Paper.inkSoft)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.displayTitle)
                    .font(.bodySerif).foregroundStyle(Paper.ink)
                    .lineLimit(1)
                if node.isFolder {
                    Text("\(childCount) item\(childCount == 1 ? "" : "s")")
                        .font(.label).foregroundStyle(Paper.inkFaint)
                } else if !node.synopsis.isEmpty {
                    Text(node.synopsis)
                        .font(.label).foregroundStyle(Paper.inkFaint).lineLimit(1)
                } else if node.wordCount > 0 {
                    Text("\(node.wordCount) words")
                        .font(.label).foregroundStyle(Paper.inkFaint)
                }
            }
            Spacer()
            if node.status != .none {
                Text(node.status.label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Paper.accent)
                    .padding(.vertical, 2).padding(.horizontal, 6)
                    .background(Capsule().stroke(Paper.accent.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(.vertical, 5)
    }
}
