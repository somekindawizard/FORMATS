import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @State private var draft: Entry?

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        switch h {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default:      return "Hello,"
        }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .sectionLabel()
                        .padding(.top, 8)
                    Text("\(greeting)\nAustin.")
                        .font(.masthead)
                        .foregroundStyle(Paper.ink)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("A prompt for today").sectionLabel()
                        Text("What has quietly stayed with you?")
                            .font(.titleSerif)
                            .foregroundStyle(Paper.ink)
                        Button("Begin writing") {
                            let entry = Entry(title: "", body: "", collection: .journal)
                            context.insert(entry)
                            draft = entry
                        }
                        .buttonStyle(InkButtonStyle())
                        .padding(.top, 4)
                    }
                    .card()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Today")
        .navigationDestination(item: $draft) { entry in
            EntryEditorView(entry: entry)
        }
    }
}

#Preview {
    NavigationStack { TodayView() }
        .modelContainer(SampleData.previewContainer())
}
