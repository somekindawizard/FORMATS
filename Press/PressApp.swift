import SwiftUI

@main
struct PressApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Paper.accent)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: AppModel.Route.self) { route in
                    switch route {
                    case .convert: ConvertView()
                    case .results: ResultsView()
                    }
                }
        }
    }
}
