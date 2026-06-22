import SwiftUI

struct SettingsView: View {
    @Environment(BiometricLock.self) private var lock
    @State private var promptReminder = PromptNotifier.isEnabled

    var body: some View {
        @Bindable var lock = lock
        ZStack {
            PaperBackground()
            Form {
                Section {
                    NavigationLink {
                        SavedPromptsView()
                    } label: {
                        Label("Saved prompts", systemImage: "heart.text.square")
                    }
                }

                Section {
                    Toggle("Evening prompt reminder", isOn: $promptReminder)
                        .tint(Paper.accent)
                } footer: {
                    Text("A gentle nudge at 7 pm with the day's prompt.")
                        .font(.calloutSerif)
                        .foregroundStyle(Paper.inkSoft)
                }

                Section {
                    Toggle("Lock with Face ID", isOn: $lock.isEnabled)
                        .tint(Paper.accent)
                } footer: {
                    Text("When on, Fern asks for Face ID each time you open the app.")
                        .font(.calloutSerif)
                        .foregroundStyle(Paper.inkSoft)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .onChange(of: promptReminder) { _, on in
            PromptNotifier.isEnabled = on
            Task { await PromptNotifier.refresh() }
        }
    }
}
