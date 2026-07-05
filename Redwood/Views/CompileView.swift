import SwiftUI

/// Compile — assemble the whole binder into one manuscript, preview it, and
/// share it as Markdown or a paginated PDF.
struct CompileView: View {
    let project: RWProject
    let docs: [RWDocument]
    @Environment(\.dismiss) private var dismiss

    @AppStorage("redwood.compile.titles") private var includeTitles = true
    @AppStorage("redwood.compile.folders") private var foldersAsHeadings = true

    @State private var mdURL: URL?
    @State private var pdfURL: URL?
    @State private var epubURL: URL?
    @State private var building = false

    private var options: RedwoodCompiler.Options {
        .init(includeTitles: includeTitles, foldersAsHeadings: foldersAsHeadings)
    }
    private var combined: String {
        RedwoodCompiler.markdown(project: project, docs: docs, options: options)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Include document titles", isOn: $includeTitles)
                        Toggle("Folder names as headings", isOn: $foldersAsHeadings)
                        Text("\(RedwoodCompiler.wordCount(combined)) words · US Letter PDF")
                            .font(.label).foregroundStyle(Paper.inkFaint)

                        Rectangle().fill(Paper.line).frame(height: 1).padding(.vertical, 2)

                        if combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Nothing to compile yet — write some documents first.")
                                .font(.calloutSerif).foregroundStyle(Paper.inkFaint)
                        } else {
                            RenderedBody(markdown: combined, wash: false)
                        }
                    }
                    .padding(.horizontal, 22).padding(.vertical, 16)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.calloutSerif)
            .tint(Paper.accent)
            .navigationTitle("Compile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.tint(Paper.inkSoft)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    if let mdURL {
                        ShareLink(item: mdURL) {
                            shareLabel("Markdown", "doc.plaintext")
                        }
                    }
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            shareLabel("PDF", "doc.richtext")
                        }
                    }
                    if let epubURL {
                        ShareLink(item: epubURL) {
                            shareLabel("EPUB", "book")
                        }
                    }
                    if building { ProgressView().tint(Paper.accent) }
                }
                .padding(.horizontal, 22).padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
            .task(id: "\(includeTitles)-\(foldersAsHeadings)") { await rebuild() }
        }
    }

    private func shareLabel(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.calloutSerif).foregroundStyle(Paper.bg)
            .padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(Capsule().fill(Paper.ink))
    }

    private func rebuild() async {
        building = true
        defer { building = false }
        let base = RedwoodCompiler.safeName(project.title)
        let md = combined
        mdURL = RedwoodCompiler.writeTemp(md, name: "\(base).md")
        // PDF rendering off the main actor (String is Sendable; models are not).
        let pdfData = await Task.detached(priority: .userInitiated) {
            RedwoodCompiler.pdf(markdown: md)
        }.value
        pdfURL = RedwoodCompiler.writeTemp(pdfData, name: "\(base).pdf")
        // EPUB reads the document tree (models) — build on the main actor.
        let author = UserDefaults.standard.string(forKey: "fern.userName") ?? ""
        let stamp = ISO8601DateFormatter().string(from: .now)
        let epubData = RedwoodCompiler.epub(project: project, docs: docs, options: options,
                                            author: author, modified: stamp)
        epubURL = RedwoodCompiler.writeTemp(epubData, name: "\(base).epub")
    }
}
