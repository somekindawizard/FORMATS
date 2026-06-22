import SwiftUI

enum Destination: String, CaseIterable, Identifiable {
    case today, library, search
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .today:   return "sun.max"
        case .library: return "books.vertical"
        case .search:  return "magnifyingglass"
        }
    }
    @ViewBuilder var view: some View {
        switch self {
        case .today:   TodayView()
        case .library: LibraryView()
        case .search:  SearchView()
        }
    }
}

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: Destination = .today

    var body: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                List(selection: $selection) {
                    ForEach(Destination.allCases) { dest in
                        Label(dest.title, systemImage: dest.symbol).tag(dest)
                    }
                }
                .navigationTitle("Fern")
            } detail: {
                NavigationStack { selection.view }
            }
            .tint(Paper.accent)
        } else {
            TabView(selection: $selection) {
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
