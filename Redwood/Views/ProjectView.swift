import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// A project's binder — the tree of folders and documents. Recurses into
/// folders. New nodes, reorder, and delete all live here.
struct ProjectView: View {
    let project: RWProject
    var parent: RWDocument? = nil

    @Environment(\.modelContext) private var context
    @Query private var allDocs: [RWDocument]
    @AppStorage("redwood.sessionGoal") private var sessionGoal = 0
    @AppStorage("redwood.binderMode") private var mode = BinderMode.binder
    @State private var editingTargets = false
    @State private var targetText = ""
    @State private var goalText = ""
    @State private var showingCompile = false
    @State private var editingSynopsis: RWDocument?
    /// Rename flow (documents, folders, and the current folder via the menu).
    @State private var renamingNode: RWDocument?
    @State private var renameText = ""
    @State private var showingRename = false
    /// Edit mode for drag-reordering. The list previously sat PERMANENTLY in
    /// edit mode, which silently swallowed row taps — nothing in Binder view
    /// could be opened.
    @State private var arranging = false
    @State private var pendingDelete: RWDocument?   // folder delete confirmation
    @State private var showingTrash = false
    @State private var targetNode: RWDocument?      // per-doc word target editor
    @State private var nodeTargetText = ""
    @State private var searchQuery = ""
    @State private var showingImporter = false

    init(project: RWProject, parent: RWDocument? = nil) {
        self.project = project
        self.parent = parent
        let pid = project.id
        // Trashed nodes (deletedAt != nil) are excluded from the binder.
        _allDocs = Query(filter: #Predicate<RWDocument> { $0.projectID == pid && $0.deletedAt == nil },
                         sort: [SortDescriptor(\RWDocument.order)])
    }

    /// Direct children of this level (nil parent = project root).
    private var nodes: [RWDocument] {
        allDocs.filter { $0.parentID == parent?.id }.sorted { $0.order < $1.order }
    }

    // Cached: summing wordCount (which renders plainText) over every document
    // on each render — while the root view sits alive under a pushed editor —
    // was O(manuscript) per keystroke. Recomputed on appear / structural change.
    @State private var totalWords = 0

    private func recomputeTotal() {
        totalWords = allDocs.filter { !$0.isFolder }.reduce(0) { $0 + $1.wordCount }
    }

    /// Words added since this app session began — baseline is PER PROJECT
    /// (a single global baseline made the session count wrong for every
    /// project opened after the first).
    private var sessionWords: Int {
        max(0, totalWords - (RWSession.baseline[project.id] ?? totalWords))
    }

    var body: some View {
        ZStack {
            PaperBackground()
            if parent == nil, !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                searchResults
            } else {
                switch mode {
                case .binder:    binderList
                case .corkboard: corkboard
                case .outline:   outline
                }
            }
        }
        .modifier(RootSearchable(enabled: parent == nil, text: $searchQuery))
        .navigationTitle(parent?.displayTitle ?? project.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            recomputeTotal()
            if RWSession.baseline[project.id] == nil { RWSession.baseline[project.id] = totalWords }
        }
        .onChange(of: allDocs) { _, _ in recomputeTotal() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("View", selection: $mode) {
                        ForEach(BinderMode.allCases) { m in
                            Label(m.label, systemImage: m.symbol).tag(m)
                        }
                    }
                } label: {
                    Image(systemName: mode.symbol).foregroundStyle(Paper.accent)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { add(isFolder: false) } label: {
                        Label("New document", systemImage: "doc")
                    }
                    Button { add(isFolder: true) } label: {
                        Label("New folder", systemImage: "folder")
                    }
                    Menu {
                        ForEach(RWTemplates.all) { t in
                            Button { addFromTemplate(t) } label: {
                                Label(t.name, systemImage: t.symbol)
                            }
                        }
                    } label: {
                        Label("New from template", systemImage: "doc.badge.plus")
                    }
                    Button { showingImporter = true } label: {
                        Label("Import Markdown…", systemImage: "square.and.arrow.down")
                    }
                    Divider()
                    if mode == .binder {
                        Button { withAnimation { arranging.toggle() } } label: {
                            Label(arranging ? "Done arranging" : "Arrange",
                                  systemImage: arranging ? "checkmark" : "arrow.up.arrow.down")
                        }
                    }
                    if let parent {
                        Button { beginRename(parent) } label: {
                            Label("Rename folder…", systemImage: "pencil")
                        }
                    }
                    if parent == nil {
                        Divider()
                        Button { beginEditTargets() } label: {
                            Label("Word targets…", systemImage: "target")
                        }
                        Button { showingCompile = true } label: {
                            Label("Compile…", systemImage: "square.stack.3d.up")
                        }
                        Button { showingTrash = true } label: {
                            Label("Trash…", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle").foregroundStyle(Paper.accent)
                }
            }
        }
        .alert("Word targets", isPresented: $editingTargets) {
            TextField("Manuscript target (words)", text: $targetText)
                .keyboardType(.numberPad)
            TextField("Session goal (words)", text: $goalText)
                .keyboardType(.numberPad)
            Button("Save", action: saveTargets)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Set an optional target for the whole manuscript and a per-session writing goal. Leave a field at 0 to turn it off.")
        }
        .sheet(isPresented: $showingCompile) {
            CompileView(project: project, docs: allDocs)
        }
        .sheet(item: $editingSynopsis) { doc in
            SynopsisEditor(doc: doc)
        }
        .sheet(isPresented: $showingTrash) {
            TrashView(project: project)
        }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.plainText, .text,
                                            UTType(filenameExtension: "md") ?? .plainText,
                                            UTType(filenameExtension: "markdown") ?? .plainText],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { importFiles(urls) }
        }
        .confirmationDialog(
            pendingDelete.map { "Delete “\($0.displayTitle)” and everything inside it?" } ?? "",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                if let node = pendingDelete { softDelete(node) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("It goes to the Trash — you can restore it until you empty it.")
        }
        .alert("Word target", isPresented: Binding(get: { targetNode != nil },
                                                   set: { if !$0 { targetNode = nil } })) {
            TextField("Words (0 = none)", text: $nodeTargetText).keyboardType(.numberPad)
            Button("Save") {
                if let node = targetNode {
                    node.wordTarget = Int(nodeTargetText.filter(\.isNumber)) ?? 0
                    node.updatedAt = .now; try? context.save()
                }
                targetNode = nil
            }
            Button("Cancel", role: .cancel) { targetNode = nil }
        }
        .alert("Rename", isPresented: $showingRename) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let node = renamingNode {
                    node.title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    node.updatedAt = .now
                    project.updatedAt = .now
                    try? context.save()
                }
                renamingNode = nil
            }
            Button("Cancel", role: .cancel) { renamingNode = nil }
        }
    }

    private func beginNodeTarget(_ node: RWDocument) {
        nodeTargetText = node.wordTarget > 0 ? "\(node.wordTarget)" : ""
        targetNode = node
    }

    private func beginRename(_ node: RWDocument) {
        renamingNode = node
        // Seed from the actual title only (blank if untitled) — don't string-
        // match the derived "Untitled" fallback, which could blank a real title.
        renameText = node.title
        showingRename = true
    }

    /// Long-press menu shared by every binder row / card / outline row.
    @ViewBuilder
    private func nodeMenu(_ node: RWDocument) -> some View {
        Button { beginRename(node) } label: {
            Label("Rename…", systemImage: "pencil")
        }
        if !node.isFolder {
            Button { editingSynopsis = node } label: {
                Label("Edit synopsis…", systemImage: "text.alignleft")
            }
            Button { beginNodeTarget(node) } label: {
                Label("Word target…", systemImage: "target")
            }
        }
        Button { duplicate(node) } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        let targets = moveTargets(for: node)
        if !targets.isEmpty || node.parentID != nil {
            Menu {
                if node.parentID != nil {
                    Button { move(node, to: nil) } label: { Label("Top level", systemImage: "tray") }
                }
                ForEach(targets) { folder in
                    Button { move(node, to: folder) } label: {
                        Label(folder.displayTitle, systemImage: "folder")
                    }
                }
            } label: {
                Label("Move to…", systemImage: "folder")
            }
        }
        Divider()
        Button(role: .destructive) {
            requestDelete(node)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    /// Folders can bury a lot of writing — confirm before trashing one. Single
    /// documents trash straight away (recoverable from Trash).
    private func requestDelete(_ node: RWDocument) {
        if node.isFolder, !allDocs.filter({ $0.parentID == node.id }).isEmpty {
            pendingDelete = node
        } else {
            softDelete(node)
        }
    }

    /// Folders this node may move into — excludes the node itself, its current
    /// parent, and (for folders) its own descendants, to prevent cycles.
    private func moveTargets(for node: RWDocument) -> [RWDocument] {
        let banned = descendantIDs(of: node).union([node.id])
        return allDocs
            .filter { $0.isFolder && !banned.contains($0.id) && $0.id != node.parentID }
            .sorted { $0.displayTitle < $1.displayTitle }
    }

    private func descendantIDs(of node: RWDocument) -> Set<UUID> {
        var ids = Set<UUID>()
        for child in allDocs where child.parentID == node.id {
            ids.insert(child.id)
            ids.formUnion(descendantIDs(of: child))
        }
        return ids
    }

    private func move(_ node: RWDocument, to folder: RWDocument?) {
        Haptics.tap()
        node.parentID = folder?.id
        let siblings = allDocs.filter { $0.parentID == folder?.id && $0.id != node.id }
        node.order = (siblings.map(\.order).max() ?? -1) + 1
        project.updatedAt = .now
        try? context.save()
    }

    private func beginEditTargets() {
        targetText = project.wordTarget > 0 ? "\(project.wordTarget)" : ""
        goalText = sessionGoal > 0 ? "\(sessionGoal)" : ""
        editingTargets = true
    }

    private func saveTargets() {
        project.wordTarget = Int(targetText.filter(\.isNumber)) ?? 0
        sessionGoal = Int(goalText.filter(\.isNumber)) ?? 0
        try? context.save()
        Haptics.tap()
    }

    // MARK: — Search (whole manuscript, root only)

    private var searchMatches: [RWDocument] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return allDocs.filter { d in
            d.title.lowercased().contains(q)
            || d.synopsis.lowercased().contains(q)
            || d.body.lowercased().contains(q)
        }
    }

    private var searchResults: some View {
        let matches = searchMatches
        return Group {
            if matches.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(Paper.inkFaint)
                    Text("Nothing matches “\(searchQuery)”")
                        .font(.bodySerif).foregroundStyle(Paper.inkSoft)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(matches) { node in
                        Group {
                            if node.isFolder {
                                NavigationLink { ProjectView(project: project, parent: node) } label: {
                                    OutlineRow(node: node, depth: 0, childCount: childCount(of: node))
                                }
                            } else {
                                NavigationLink(value: node) {
                                    OutlineRow(node: node, depth: 0, childCount: 0)
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: — Binder (list) mode

    private var binderList: some View {
        List {
            if parent == nil {
                TargetsBar(project: project, totalWords: totalWords,
                           sessionWords: sessionWords, sessionGoal: sessionGoal) {
                    beginEditTargets()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .moveDisabled(true)
            }
            ForEach(nodes) { node in
                binderRow(node)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onMove(perform: move)
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // Edit mode only while arranging — leaving it always-on made every
        // row un-tappable (NavigationLinks don't fire in edit mode).
        .environment(\.editMode, .constant(arranging ? .active : .inactive))
    }

    // MARK: — Corkboard mode

    private var corkboard: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 14)],
                      spacing: 14) {
                ForEach(nodes) { node in
                    Group {
                        if node.isFolder {
                            NavigationLink { ProjectView(project: project, parent: node) } label: {
                                IndexCard(node: node, childCount: childCount(of: node))
                            }
                        } else {
                            NavigationLink(value: node) {
                                IndexCard(node: node, childCount: 0)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu { nodeMenu(node) }
                }
            }
            .padding(16)
        }
    }

    // MARK: — Outline mode

    /// The whole subtree in reading order, with depth for indentation.
    private func flatten(parent pid: UUID?, depth: Int) -> [(node: RWDocument, depth: Int)] {
        var out: [(RWDocument, Int)] = []
        for n in allDocs.filter({ $0.parentID == pid }).sorted(by: { $0.order < $1.order }) {
            out.append((n, depth))
            if n.isFolder { out += flatten(parent: n.id, depth: depth + 1) }
        }
        return out
    }

    private var outline: some View {
        List {
            ForEach(flatten(parent: parent?.id, depth: 0), id: \.node.id) { item in
                Group {
                    if item.node.isFolder {
                        NavigationLink { ProjectView(project: project, parent: item.node) } label: {
                            OutlineRow(node: item.node, depth: item.depth,
                                       childCount: childCount(of: item.node))
                        }
                    } else {
                        NavigationLink(value: item.node) {
                            OutlineRow(node: item.node, depth: item.depth, childCount: 0)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .contextMenu { nodeMenu(item.node) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func binderRow(_ node: RWDocument) -> some View {
        if node.isFolder {
            NavigationLink {
                ProjectView(project: project, parent: node)
            } label: {
                BinderNodeRow(node: node, childCount: childCount(of: node))
            }
            .contextMenu { nodeMenu(node) }
        } else {
            NavigationLink(value: node) {
                BinderNodeRow(node: node, childCount: 0)
            }
            .contextMenu { nodeMenu(node) }
        }
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

    /// Import one or more Markdown/text files as documents at this level —
    /// e.g. a Fern entry saved via "Share as Markdown."
    private func importFiles(_ urls: [URL]) {
        Haptics.tap()
        var order = (nodes.map(\.order).max() ?? -1) + 1
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let (title, body) = RWImport.parse(text: text, filename: url.lastPathComponent)
            let node = RWDocument(projectID: project.id, title: title,
                                  isFolder: false, order: order, parentID: parent?.id)
            node.body = body
            context.insert(node)
            order += 1
        }
        project.updatedAt = .now
        try? context.save()
    }

    private func addFromTemplate(_ template: RWTemplate) {
        Haptics.tap()
        let order = (nodes.map(\.order).max() ?? -1) + 1
        let node = RWDocument(projectID: project.id, isFolder: false,
                              order: order, parentID: parent?.id)
        node.synopsis = template.synopsis
        node.body = template.body
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
        for i in offsets { softDelete(nodes[i]) }
    }

    /// Move a node (and, if a folder, its whole subtree) to the Trash. Nothing
    /// is destroyed until the Trash is emptied, so a mis-swipe is recoverable.
    private func softDelete(_ node: RWDocument) {
        Haptics.tap(.medium)
        let now = Date.now
        func mark(_ n: RWDocument) {
            n.deletedAt = now
            for child in allDocs.filter({ $0.parentID == n.id }) { mark(child) }
        }
        mark(node)
        project.updatedAt = .now
        try? context.save()
    }

    /// Duplicate a document (or a whole folder subtree) as a sibling.
    private func duplicate(_ node: RWDocument) {
        Haptics.tap()
        let baseOrder = (nodes.map(\.order).max() ?? node.order) + 1
        copyNode(node, into: node.parentID, order: baseOrder, appendCopy: true)
        project.updatedAt = .now
        try? context.save()
    }

    @discardableResult
    private func copyNode(_ node: RWDocument, into newParent: UUID?, order: Int,
                          appendCopy: Bool) -> RWDocument {
        let copy = RWDocument(projectID: project.id, title: node.title.isEmpty ? "" : node.title + (appendCopy ? " copy" : ""),
                              isFolder: node.isFolder, order: order, parentID: newParent)
        copy.synopsis = node.synopsis
        copy.body = node.body
        copy.statusRaw = node.statusRaw
        copy.wordTarget = node.wordTarget
        context.insert(copy)
        if node.isFolder {
            let children = allDocs.filter { $0.parentID == node.id }.sorted { $0.order < $1.order }
            for (i, child) in children.enumerated() {
                copyNode(child, into: copy.id, order: i, appendCopy: false)
            }
        }
        return copy
    }
}

/// The Trash — soft-deleted nodes for a project, restorable until emptied.
/// Emptying permanently purges each node's snapshots, drawing, ink prefs, and
/// embedded photos (see RWCleanup).
private struct TrashView: View {
    let project: RWProject
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var trashed: [RWDocument]

    init(project: RWProject) {
        self.project = project
        let pid = project.id
        _trashed = Query(filter: #Predicate<RWDocument> { $0.projectID == pid && $0.deletedAt != nil },
                         sort: [SortDescriptor(\RWDocument.deletedAt, order: .reverse)])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                if trashed.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "trash").font(.system(size: 34)).foregroundStyle(Paper.inkFaint)
                        Text("Trash is empty").font(.headlineSerif).foregroundStyle(Paper.inkSoft)
                    }
                } else {
                    List {
                        ForEach(trashed) { node in
                            HStack(spacing: 12) {
                                Image(systemName: node.isFolder ? "folder" : "doc.text")
                                    .foregroundStyle(Paper.inkSoft)
                                Text(node.displayTitle).font(.bodySerif).foregroundStyle(Paper.ink)
                                    .lineLimit(1)
                                Spacer()
                                Button("Restore") { restore(node) }
                                    .font(.label).foregroundStyle(Paper.accent).buttonStyle(.plain)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Trash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.tint(Paper.accent)
                }
                if !trashed.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Empty", role: .destructive) { empty() }.tint(.red)
                    }
                }
            }
        }
    }

    /// Un-trash a node and its trashed descendants.
    private func restore(_ node: RWDocument) {
        Haptics.tap()
        let pid = project.id
        let all = (try? context.fetch(FetchDescriptor<RWDocument>(
            predicate: #Predicate<RWDocument> { $0.projectID == pid }))) ?? []
        func unmark(_ n: RWDocument) {
            n.deletedAt = nil
            for child in all where child.parentID == n.id && child.deletedAt != nil { unmark(child) }
        }
        unmark(node)
        try? context.save()
    }

    /// Permanently purge everything in the Trash (rows + off-model assets).
    private func empty() {
        Haptics.tap(.medium)
        for node in trashed { RWCleanup.purge(context, node) }
        try? context.save()
    }
}

/// A small sheet for writing a document's index-card synopsis without opening it.
private struct SynopsisEditor: View {
    @Bindable var doc: RWDocument
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                VStack(alignment: .leading, spacing: 10) {
                    Text(doc.displayTitle).font(.headlineSerif).foregroundStyle(Paper.ink)
                        .padding(.horizontal, 4)
                    TextEditor(text: $doc.synopsis)
                        .font(.calloutSerif)
                        .foregroundStyle(Paper.inkSoft)
                        .scrollContentBackground(.hidden)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .topLeading) {
                            if doc.synopsis.isEmpty {
                                Text("A sentence or two on what happens here…")
                                    .font(.calloutSerif).foregroundStyle(Paper.inkFaint)
                                    .padding(.top, 8).padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                .padding(18)
            }
            .navigationTitle("Synopsis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        doc.updatedAt = .now; try? context.save(); dismiss()
                    }
                    .tint(Paper.accent).fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Adds `.searchable` only for the root project view (nested folders don't get
/// their own search bar).
private struct RootSearchable: ViewModifier {
    let enabled: Bool
    @Binding var text: String
    func body(content: Content) -> some View {
        if enabled {
            content.searchable(text: $text, placement: .navigationBarDrawer(displayMode: .automatic),
                               prompt: "Search this manuscript")
        } else {
            content
        }
    }
}

/// How the binder is shown: list, corkboard of index cards, or flat outline.
enum BinderMode: String, CaseIterable, Identifiable {
    case binder, corkboard, outline
    var id: String { rawValue }
    var label: String {
        switch self {
        case .binder:    return "Binder"
        case .corkboard: return "Corkboard"
        case .outline:   return "Outline"
        }
    }
    var symbol: String {
        switch self {
        case .binder:    return "list.bullet"
        case .corkboard: return "rectangle.grid.2x2"
        case .outline:   return "list.bullet.indent"
        }
    }
}

/// Tracks each project's word baseline for the current app session (in-memory,
/// resets on relaunch) so "words this session" is correct per project.
enum RWSession {
    static var baseline: [UUID: Int] = [:]
}

/// A corkboard index card: title, a ruled line, the synopsis, and a footer.
private struct IndexCard: View {
    let node: RWDocument
    let childCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: node.isFolder ? "folder.fill" : "doc.text")
                    .font(.system(size: 11))
                    .foregroundStyle(node.isFolder ? Paper.accent : Paper.inkFaint)
                Text(node.displayTitle)
                    .font(.headlineSerif).foregroundStyle(Paper.ink)
                    .lineLimit(2)
            }
            Rectangle().fill(Paper.accent.opacity(0.5)).frame(height: 1)
            if node.isFolder {
                Text("\(childCount) item\(childCount == 1 ? "" : "s")")
                    .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
            } else {
                Text(node.synopsis.isEmpty ? "No synopsis yet" : node.synopsis)
                    .font(.calloutSerif)
                    .foregroundStyle(node.synopsis.isEmpty ? Paper.inkFaint : Paper.inkSoft)
                    .lineLimit(5)
            }
            Spacer(minLength: 0)
            HStack {
                if !node.isFolder {
                    Text("\(node.wordCount) words")
                        .font(.label).foregroundStyle(Paper.inkFaint)
                }
                Spacer()
                if node.status != .none {
                    Text(node.status.label.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Paper.accent)
                }
            }
        }
        .padding(12)
        .frame(height: 158, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Paper.raised)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Paper.line, lineWidth: 1))
                .shadow(color: Paper.ink.opacity(0.06), radius: 4, y: 2)
        )
    }
}

/// A compact outline row: indented by depth, with word count and status.
private struct OutlineRow: View {
    let node: RWDocument
    let depth: Int
    let childCount: Int

    var body: some View {
        HStack(spacing: 8) {
            if depth > 0 {
                Rectangle().fill(.clear).frame(width: CGFloat(depth) * 16)
            }
            Image(systemName: node.isFolder ? "folder" : "doc.text")
                .font(.system(size: 12))
                .foregroundStyle(node.isFolder ? Paper.accent : Paper.inkSoft)
            Text(node.displayTitle)
                .font(node.isFolder ? .bodySerif.weight(.medium) : .bodySerif)
                .foregroundStyle(Paper.ink).lineLimit(1)
            Spacer()
            if node.isFolder {
                Text("\(childCount)")
                    .font(.label).foregroundStyle(Paper.inkFaint)
            } else {
                if node.status != .none {
                    Text(node.status.label.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Paper.accent)
                }
                Text("\(node.wordCount)")
                    .font(.label).foregroundStyle(Paper.inkFaint)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Manuscript progress + session progress, shown atop the project binder.
private struct TargetsBar: View {
    let project: RWProject
    let totalWords: Int
    let sessionWords: Int
    let sessionGoal: Int
    let onEdit: () -> Void

    private var manuscriptProgress: Double {
        guard project.wordTarget > 0 else { return 0 }
        return min(1, Double(totalWords) / Double(project.wordTarget))
    }
    private var sessionProgress: Double {
        guard sessionGoal > 0 else { return 0 }
        return min(1, Double(sessionWords) / Double(sessionGoal))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Manuscript total / target
            if project.wordTarget > 0 {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("\(totalWords) / \(project.wordTarget) words")
                            .font(.calloutSerif).foregroundStyle(Paper.ink)
                        Spacer()
                        Text("\(Int(manuscriptProgress * 100))%")
                            .font(.label).foregroundStyle(Paper.accent)
                    }
                    ProgressBar(value: manuscriptProgress)
                }
            } else {
                HStack {
                    Text("\(totalWords) words")
                        .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                    Spacer()
                    Button("Set a target", action: onEdit)
                        .font(.label).foregroundStyle(Paper.accent)
                }
            }

            // Session
            HStack(spacing: 10) {
                Image(systemName: "flame")
                    .font(.system(size: 12)).foregroundStyle(Paper.accent)
                if sessionGoal > 0 {
                    Text("\(sessionWords) / \(sessionGoal) this session")
                        .font(.label).foregroundStyle(Paper.inkSoft)
                    ProgressBar(value: sessionProgress).frame(maxWidth: 120)
                    if sessionWords >= sessionGoal {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12)).foregroundStyle(Paper.accent)
                    }
                } else {
                    Text("+\(sessionWords) words this session")
                        .font(.label).foregroundStyle(Paper.inkSoft)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Paper.raised)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Paper.line, lineWidth: 1))
        )
        .padding(.vertical, 4)
    }
}

/// A thin rounded progress track in the accent color.
private struct ProgressBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Paper.line)
                Capsule().fill(Paper.accent)
                    .frame(width: max(0, geo.size.width * value))
            }
        }
        .frame(height: 5)
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
