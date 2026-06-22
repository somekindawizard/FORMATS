import SwiftUI

struct SearchView: View {
    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(Paper.inkFaint)
                Text("Search arrives soon")
                    .font(.bodySerif)
                    .foregroundStyle(Paper.inkSoft)
            }
        }
        .navigationTitle("Search")
    }
}
