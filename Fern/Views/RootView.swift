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

/// Shared navigation state so the Today masthead can toggle the sidebar and the
/// editor can collapse it — mirrors the `ThemeStore.shared` convention.
@Observable final class FernNav {
    static let shared = FernNav()
    var columnVisibility: NavigationSplitViewVisibility = .automatic
}

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var context
    @Environment(BiometricLock.self) private var lock
    @Query private var entries: [Entry]
    /// A Spotlight-opened entry that arrived while the gate was up — presented
    /// only once the gate is passed (sheets would otherwise float above it).
    @State private var pendingSpotlightID: UUID?
    @State private var pendingQuickCompose = false
    // Sidebar selection on iOS requires an optional binding; default to Today.
    @State private var sidebarSelection: Destination? = .today
    // Persisted so a theme change (which rebuilds the tree) keeps you on the tab.
    @AppStorage("fern.tab") private var tabSelection: Destination = .today
    @State private var spotlightEntry: Entry?
    @State private var hideTabBar = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("fern.onboarded") private var onboarded = false
    @AppStorage("fern.userName") private var userName = ""

    var body: some View {
        @Bindable var nav = FernNav.shared
        return Group {
            if sizeClass == .regular {
                NavigationSplitView(columnVisibility: $nav.columnVisibility) {
                    List(selection: $sidebarSelection) {
                        ForEach(Destination.allCases) { dest in
                            Label(dest.title, systemImage: dest.symbol).tag(dest)
                        }
                    }
                    .navigationTitle("Fern")
                    // Swipe left anywhere on the sidebar to tuck it away —
                    // simultaneous so the list still scrolls vertically; only a
                    // clearly horizontal leftward drag closes it.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { v in
                                if v.translation.width < -50,
                                   abs(v.translation.width) > abs(v.translation.height) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        nav.columnVisibility = .detailOnly
                                    }
                                }
                            }
                    )
                } detail: {
                    NavigationStack { (sidebarSelection ?? .today).view }
                        // Tint the detail bar too, so the system-provided
                        // sidebar-toggle button picks up the accent instead of
                        // defaulting to white (the custom toolbar buttons set
                        // their color explicitly; the system toggle follows tint).
                        .tint(Paper.accent)
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
            // The notification permission dialog must not fire underneath the
            // onboarding cover — it waits until onboarding completes.
            if onboarded { await PromptNotifier.refresh() }
            SpotlightIndexer.reindexChanged(entries)   // incremental — not the whole corpus
            AssetSync.sync(context.container)   // photos/ink sync on a background context
        }
        .onChange(of: onboarded) { _, done in
            if done { Task { await PromptNotifier.refresh() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            AssetSync.sync(context.container)
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
            if phase == .active {
                consumeQuickCompose()
                AssetSync.sync(context.container)
            }
        }
        .onOpenURL { url in
            if url.scheme == "fern" && url.host == "new" { startQuickCompose() }
        }
        .onChange(of: lock.gateVisible) { _, visible in
            if visible {
                // Relocked — anything presented above the veil must come down.
                spotlightEntry = nil
            } else {
                // Gate passed — deliver whatever arrived while it was up.
                if let id = pendingSpotlightID { pendingSpotlightID = nil; openEntry(id) }
                if pendingQuickCompose { pendingQuickCompose = false; startQuickCompose() }
            }
        }
        .fullScreenCover(isPresented: .constant(!onboarded || userName.isEmpty)) {
            OnboardingView { name in
                userName = name
                NameSync.push(name)
                onboarded = true
            }
        }
    }

    private func openEntry(_ uuid: UUID) {
        // Never present journal content above the lock veil — hold it until
        // the gate is passed.
        guard !lock.gateVisible else { pendingSpotlightID = uuid; return }
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
        guard !lock.gateVisible else { pendingQuickCompose = true; return }
        let entry = Entry(title: "", body: "", collection: .piece)
        context.insert(entry)
        spotlightEntry = entry
    }
}
