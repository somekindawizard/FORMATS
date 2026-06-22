import SwiftUI

struct SettingsView: View {
    @Environment(BiometricLock.self) private var lock

    var body: some View {
        @Bindable var lock = lock
        ZStack {
            PaperBackground()
            Form {
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
    }
}
