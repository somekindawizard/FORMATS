import SwiftUI
import SwiftData

/// The app root. A NavigationSplitView so iPad and Mac get a desktop layout —
/// projects in a persistent sidebar, the selected project's binder in the
/// detail pane. On iPhone (compact) it collapses to a navigation stack.
struct RedwoodRootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\RWProject.updatedAt, order: .reverse)]) private var projects: [RWProject]

    @State private var selectedProject: RWProject?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingNew = false
    @State private var newProjectTitle = ""
    @State private var showingSettings = false
    @State private var renamingProject: RWProject?
    @State private var renameTitle = ""
    @State private var renameSubtitle = ""

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detail
        }
        .tint(Paper.accent)
        .sheet(isPresented: $showingSettings) { RedwoodSettings() }
        .alert("New project", isPresented: $showingNew) {
            TextField("Title", text: $newProjectTitle)
            Button("Create", action: createProject)
            Button("Cancel", role: .cancel) { newProjectTitle = "" }
        }
        .alert("Rename project", isPresented: Binding(get: { renamingProject != nil },
                                                      set: { if !$0 { renamingProject = nil } })) {
            TextField("Title", text: $renameTitle)
            TextField("Subtitle (optional)", text: $renameSubtitle)
            Button("Save") {
                if let p = renamingProject {
                    let t = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { p.title = t }
                    p.subtitle = renameSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    p.updatedAt = .now; try? context.save()
                }
                renamingProject = nil
            }
            Button("Cancel", role: .cancel) { renamingProject = nil }
        }
        .onAppear { if selectedProject == nil { selectedProject = projects.first } }
        .onChange(of: projects.count) { _, _ in
            if selectedProject == nil { selectedProject = projects.first }
        }
    }

    // MARK: sidebar — the shelf of projects

    private var sidebar: some View {
        Group {
            if projects.isEmpty {
                emptyShelf
            } else {
                List(selection: $selectedProject) {
                    ForEach(projects) { project in
                        ProjectShelfRow(project: project, count: documentCount(project))
                            .tag(project)
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button { beginRename(project) } label: {
                                    Label("Rename…", systemImage: "pencil")
                                }
                                Button(role: .destructive) { deleteProject(project) } label: {
                                    Label("Delete project", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete(perform: deleteProjects)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(PaperBackground())
            }
        }
        .navigationTitle("Redwood")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape").foregroundStyle(Paper.accent)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: {
                    Image(systemName: "plus.circle").foregroundStyle(Paper.accent)
                }
            }
        }
    }

    // MARK: detail — the selected project's binder

    @ViewBuilder
    private var detail: some View {
        if let project = selectedProject {
            NavigationStack {
                ProjectView(project: project)
                    .navigationDestination(for: RWDocument.self) { doc in
                        DocumentEditorView(doc: doc)
                    }
            }
            .id(project.id)   // reset the detail stack when switching projects
        } else {
            emptyDetail
        }
    }

    private var emptyDetail: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 16) {
                Image("RedwoodTree")
                    .renderingMode(.template).resizable().scaledToFit()
                    .frame(height: 300)
                    .foregroundStyle(Paper.accent.opacity(0.85))
                Text("Choose a project, or plant a new one.")
                    .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
            }
            .padding(40)
        }
    }

    private var emptyShelf: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 14) {
                Text("No projects yet")
                    .font(.headlineSerif).foregroundStyle(Paper.ink)
                Button {
                    showingNew = true
                } label: {
                    Text("New project")
                        .font(.calloutSerif).foregroundStyle(Paper.bg)
                        .padding(.vertical, 9).padding(.horizontal, 20)
                        .background(Capsule().fill(Paper.ink))
                }
                .buttonStyle(.plain)
            }
            .padding(30)
        }
    }

    // MARK: actions

    private func documentCount(_ project: RWProject) -> Int {
        let pid = project.id
        return (try? context.fetchCount(FetchDescriptor<RWDocument>(
            predicate: #Predicate<RWDocument> { $0.projectID == pid && $0.isFolder == false }))) ?? 0
    }

    private func createProject() {
        let title = newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        Haptics.tap()
        let project = RWProject(title: title, order: projects.count)
        context.insert(project)
        context.insert(RWDocument(projectID: project.id, title: "", order: 0))
        try? context.save()
        newProjectTitle = ""
        selectedProject = project
    }

    private func beginRename(_ project: RWProject) {
        renameTitle = project.title
        renameSubtitle = project.subtitle
        renamingProject = project
    }

    private func deleteProjects(_ offsets: IndexSet) {
        for i in offsets { deleteProject(projects[i]) }
    }

    /// Permanently delete a project and every node it owns — including each
    /// node's snapshots, drawing, ink prefs, and embedded photos (previously
    /// only the drawing was removed, leaking the rest forever).
    private func deleteProject(_ project: RWProject) {
        Haptics.tap(.medium)
        if selectedProject == project { selectedProject = nil }
        let pid = project.id
        if let docs = try? context.fetch(FetchDescriptor<RWDocument>(
            predicate: #Predicate<RWDocument> { $0.projectID == pid })) {
            for d in docs { RWCleanup.purge(context, d) }
        }
        RWSession.baseline[project.id] = nil
        context.delete(project)
        try? context.save()
    }
}

struct ProjectShelfRow: View {
    let project: RWProject
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Paper.accent.opacity(0.85))
                .frame(width: 6, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.title).font(.headlineSerif).foregroundStyle(Paper.ink)
                    .lineLimit(1)
                if !project.subtitle.isEmpty {
                    Text(project.subtitle).font(.label).italic()
                        .foregroundStyle(Paper.inkSoft).lineLimit(1)
                }
                Text("\(count) document\(count == 1 ? "" : "s")")
                    .font(.label).foregroundStyle(Paper.inkFaint)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
