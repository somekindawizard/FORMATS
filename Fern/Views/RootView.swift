import SwiftUI
import SwiftData
import CoreSpotlight

enum Destination: String, CaseIterable, Identifiable {
    case today, library, search, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .today:    return "sun.max"
        case .library:  return "books.vertical"
        case .search:   return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }
    var symbolActive: String {
        switch self {
        case .today:    return "sun.max.fill"
        case .library:  return "books.vertical.fill"
        case .search:   return "magnifyingglass"
        case .settings: return "gearshape.fill"
        }
    }
    @ViewBuilder var view: some View {
        switch self {
        case .today:    TodayView()
        case .library:  LibraryView()
        case .search:   SearchView()
        case .settings: SettingsView()
        }
    }
}

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var context
    @Query private var entries: [Entry]
    // Sidebar selection on iOS requires an optional binding; default to Today.
    @State private var sidebarSelection: Destination? = .today
    // Persisted so a theme change (which rebuilds the tree) keeps you on the tab.
    @AppStorage("fern.tab") private var tabSelection: Destination = .today
    @State private var spotlightEntry: Entry?
    @State private var hideTabBar = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("fern.onboarded") private var onboarded = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    List(selection: $sidebarSelection) {
                        ForEach(Destination.allCases) { dest in
                            Label(dest.title, systemImage: dest.symbol).tag(dest)
                        }
                    }
                    .navigationTitle("Fern")
                } detail: {
                    NavigationStack { (sidebarSelection ?? .today).view }
                }
                .tint(Paper.accent)
            } else {
                NavigationStack { tabSelection.view }
                    .tint(Paper.accent)
                    .onPreferenceChange(HidesTabBarKey.self) { hidden in
                        withAnimation(.easeInOut(duration: 0.22)) { hideTabBar = hidden }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if !hideTabBar {
                            FernTabBar(selection: $tabSelection)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
            }
        }
        .task {
            await PromptNotifier.refresh()
            SpotlightIndexer.reindexAll(entries)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
               let uuid = UUID(uuidString: id) {
                openEntry(uuid)
            }
        }
        .sheet(item: $spotlightEntry) { entry in
            NavigationStack { EntryEditorView(entry: entry) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { consumeQuickCompose() }
        }
        .onOpenURL { url in
            if url.scheme == "fern" && url.host == "new" { startQuickCompose() }
        }
        .fullScreenCover(isPresented: .constant(!onboarded)) {
            OnboardingView { onboarded = true }
        }
    }

    private func openEntry(_ uuid: UUID) {
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.id == uuid })
        spotlightEntry = try? context.fetch(descriptor).first
    }

    /// Honor a "New Fern entry" App Intent that ran while the app was backgrounded.
    private func consumeQuickCompose() {
        guard UserDefaults.standard.bool(forKey: "fern.quickCompose") else { return }
        UserDefaults.standard.set(false, forKey: "fern.quickCompose")
        startQuickCompose()
    }

    private func startQuickCompose() {
        let entry = Entry(title: "", body: "", collection: .piece)
        context.insert(entry)
        spotlightEntry = entry
    }
}
