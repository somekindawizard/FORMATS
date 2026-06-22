import SwiftUI

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
    // Sidebar selection on iOS requires an optional binding; default to Today.
    @State private var sidebarSelection: Destination? = .today
    @State private var tabSelection: Destination = .today

    var body: some View {
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
            TabView(selection: $tabSelection) {
                ForEach(Destination.allCases) { dest in
                    NavigationStack { dest.view }
                        .tabItem { Label(dest.title, systemImage: dest.symbol) }
                        .tag(dest)
                }
            }
            .tint(Paper.accent)
        }
    }
}
