import SwiftUI
import SwiftData

/// The shelf of projects — Redwood's home. Each project opens into its binder.
struct BinderView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\RWProject.updatedAt, order: .reverse)]) private var projects: [RWProject]
    @State private var newProjectTitle = ""
    @State private var showingNew = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                if projects.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(projects) { project in
                            NavigationLink(value: project) {
                                ProjectShelfRow(project: project, count: documentCount(project))
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteProjects)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Redwood")
            .navigationDestination(for: RWProject.self) { ProjectView(project: $0) }
            .navigationDestination(for: RWDocument.self) { DocumentEditorView(doc: $0) }
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
            .sheet(isPresented: $showingSettings) { RedwoodSettings() }
            .alert("New project", isPresented: $showingNew) {
                TextField("Title", text: $newProjectTitle)
                Button("Create", action: createProject)
                Button("Cancel", role: .cancel) { newProjectTitle = "" }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("RedwoodTree")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(height: 360)
                .foregroundStyle(Paper.accent.opacity(0.9))
            Text("Plant a project")
                .font(.display(24)).foregroundStyle(Paper.ink)
            Text("A novel, an essay, a thesis — a home for the long work.")
                .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                showingNew = true
            } label: {
                Text("New project")
                    .font(.calloutSerif).foregroundStyle(Paper.bg)
                    .padding(.vertical, 10).padding(.horizontal, 22)
                    .background(Capsule().fill(Paper.ink))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(40)
    }

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
        // Seed with a first document so the binder isn't empty.
        context.insert(RWDocument(projectID: project.id, title: "", order: 0))
        try? context.save()
        newProjectTitle = ""
    }

    private func deleteProjects(_ offsets: IndexSet) {
        Haptics.tap(.medium)
        for i in offsets {
            let project = projects[i]
            let pid = project.id
            if let docs = try? context.fetch(FetchDescriptor<RWDocument>(
                predicate: #Predicate<RWDocument> { $0.projectID == pid })) {
                for d in docs { DrawingStore.delete(d.id); context.delete(d) }
            }
            context.delete(project)
        }
        try? context.save()
    }
}

private struct ProjectShelfRow: View {
    let project: RWProject
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Paper.accent.opacity(0.85))
                .frame(width: 6, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.title).font(.headlineSerif).foregroundStyle(Paper.ink)
                Text("\(count) document\(count == 1 ? "" : "s")")
                    .font(.label).foregroundStyle(Paper.inkFaint)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
