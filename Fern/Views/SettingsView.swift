import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(BiometricLock.self) private var lock
    @Environment(ThemeStore.self) private var theme
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var promptReminder = PromptNotifier.isEnabled
    @State private var shareItems: ShareItems?
    @State private var exporting = false
    @AppStorage("fern.userName") private var userName = ""

    var body: some View {
        @Bindable var lock = lock
        @Bindable var theme = theme
        ZStack {
            PaperBackground()
            Form {
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Your name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .foregroundStyle(Paper.inkSoft)
                            .onChange(of: userName) { _, name in NameSync.push(name) }
                    }
                } footer: {
                    Text("What Fern calls you. Syncs across your devices via iCloud.")
                        .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                }

                Section {
                    NavigationLink {
                        SavedPromptsView()
                    } label: {
                        Label("Saved prompts", systemImage: "heart.text.square")
                    }
                    NavigationLink {
                        WashLabView()
                    } label: {
                        Label("Wash Lab (dev)", systemImage: "slider.horizontal.3")
                    }
                }

                Section {
                    Picker("Display font", selection: $theme.displayFont) {
                        ForEach(DisplayFont.allCases) { f in
                            Text(f.title).tag(f)
                        }
                    }
                    Picker("Paper", selection: $theme.tone) {
                        ForEach(PaperTone.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Lines", selection: $theme.paperRule) {
                        ForEach(PaperRule.allCases) { Text($0.title).tag($0) }
                    }
                    HStack(spacing: 14) {
                        Text("Accent")
                        Spacer()
                        ForEach(AccentTone.allCases) { a in
                            Circle().fill(a.swatch).frame(width: 26, height: 26)
                                .overlay(Circle().stroke(Paper.ink, lineWidth: theme.accent == a ? 2 : 0).padding(1))
                                .onTapGesture { theme.accent = a }
                        }
                    }
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle("Focus mode", isOn: $theme.focusMode).tint(Paper.accent)
                    Toggle("Typewriter scrolling", isOn: $theme.typewriter).tint(Paper.accent)
                } header: {
                    Text("Writing")
                } footer: {
                    Text("Focus dims all but the line you're writing. Typewriter keeps that line centered.")
                        .font(.calloutSerif).foregroundStyle(Paper.inkSoft)
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

                Section {
                    Button {
                        exportAll()
                    } label: {
                        if exporting {
                            HStack { ProgressView(); Text("Preparing\u{2026}") }
                        } else {
                            Label("Export everything", systemImage: "square.and.arrow.up.on.square")
                        }
                    }
                    .disabled(exporting || entries.isEmpty)
                } footer: {
                    Text("A .zip of every entry as a Markdown file.")
                        .font(.calloutSerif)
                        .foregroundStyle(Paper.inkSoft)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .sheet(item: $shareItems) { ActivityView(items: $0.items) }
        .onChange(of: promptReminder) { _, on in
            PromptNotifier.isEnabled = on
            Task { await PromptNotifier.refresh() }
        }
    }

    private func exportAll() {
        exporting = true
        let docs = LibraryExporter.documents(from: entries)   // reads models on main actor
        Task.detached {
            let url = LibraryExporter.makeArchive(docs: docs) // file I/O off main
            await MainActor.run {
                exporting = false
                if let url { shareItems = ShareItems(items: [url]) }
            }
        }
    }
}
