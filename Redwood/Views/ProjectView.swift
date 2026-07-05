import SwiftUI
import SwiftData

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

    /// Words added since this app session began (baseline captured on first open).
    private var sessionWords: Int {
        max(0, totalWords - (RWSession.baselineWords ?? totalWords))
    }

    var body: some View {
        ZStack {
            PaperBackground()
            switch mode {
            case .binder:    binderList
            case .corkboard: corkboard
            case .outline:   outline
            }
        }
        .navigationTitle(parent?.displayTitle ?? project.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if RWSession.baselineWords == nil { RWSession.baselineWords = totalWords }
        }
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
                    if parent == nil {
                        Divider()
                        Button { beginEditTargets() } label: {
                            Label("Word targets…", systemImage: "target")
                        }
                        Button { showingCompile = true } label: {
                            Label("Compile…", systemImage: "square.stack.3d.up")
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
    }

    /// Long-press menu shared by every binder row / card / outline row.
    @ViewBuilder
    private func nodeMenu(_ node: RWDocument) -> some View {
        if !node.isFolder {
            Button { editingSynopsis = node } label: {
                Label("Edit synopsis…", systemImage: "text.alignleft")
            }
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
            Haptics.tap(.medium); deleteRecursively(node)
            project.updatedAt = .now; try? context.save()
        } label: {
            Label("Delete", systemImage: "trash")
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
        .environment(\.editMode, .constant(.active))
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

/// Tracks the word baseline for the current app session (in-memory, resets on
/// relaunch) so "words this session" can be shown.
enum RWSession {
    static var baselineWords: Int?
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
