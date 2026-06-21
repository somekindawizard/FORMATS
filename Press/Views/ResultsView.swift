import SwiftUI

struct ResultsView: View {
    @Environment(AppModel.self) private var model

    @State private var shareItems: [Any]? = nil
    @State private var savedIDs: Set<UUID> = []
    @State private var savingID: UUID? = nil

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    VStack(spacing: 0) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                            if index > 0 { Rule() }
                            resultRow(result)
                        }
                    }
                    .card(padding: 18)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: Binding(get: { shareItems != nil },
                                    set: { if !$0 { shareItems = nil } })) {
            if let shareItems { ShareSheet(items: shareItems) }
        }
        .alert("Heads up",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DONE")
                .sectionLabel()
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Pressed")
                    .font(.masthead)
                    .foregroundStyle(Paper.ink)
                Text(".")
                    .font(.masthead)
                    .foregroundStyle(Paper.accent)
            }
            Text(overallSummary)
                .font(.serif(15))
                .italic()
                .foregroundStyle(Paper.inkSoft)
        }
        .padding(.top, 10)
    }

    private var overallSummary: String {
        let inTotal = model.results.reduce(0) { $0 + $1.originalBytes }
        let outTotal = model.results.reduce(0) { $0 + $1.outputBytes }
        guard inTotal > 0 else { return "\(model.results.count) ready." }
        let delta = Double(outTotal - inTotal) / Double(inTotal)
        let count = model.results.count
        return "\(count) image\(count == 1 ? "" : "s") · \(Format.bytes(outTotal)) · \(Format.delta(delta)) overall."
    }

    // MARK: Row

    private func resultRow(_ result: ConversionResult) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(uiImage: result.thumbnail)
                .resizable().scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Paper.line, lineWidth: 1))
                .background(CheckerHint().clipShape(RoundedRectangle(cornerRadius: 9)))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(result.sourceName).\(result.format.ext)")
                    .font(.headline).foregroundStyle(Paper.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(Format.bytes(result.originalBytes))
                        .foregroundStyle(Paper.inkFaint)
                    Image(systemName: "arrow.right").font(.system(size: 9))
                        .foregroundStyle(Paper.inkFaint)
                    Text(Format.bytes(result.outputBytes))
                        .foregroundStyle(Paper.ink)
                }
                .font(.figure(12))
                Text(Format.delta(result.sizeDelta))
                    .font(.figure(11, .medium))
                    .foregroundStyle(result.sizeDelta <= 0 ? Paper.accent : Paper.inkSoft)

                HStack(spacing: 16) {
                    Button {
                        shareItems = [result.url]
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up").font(.calloutSerif)
                    }
                    .buttonStyle(QuietButtonStyle())

                    if result.format.family == .raster {
                        Button {
                            save(result)
                        } label: {
                            if savingID == result.id {
                                ProgressView().controlSize(.small)
                            } else if savedIDs.contains(result.id) {
                                Label("Saved", systemImage: "checkmark").font(.calloutSerif)
                            } else {
                                Label("Save", systemImage: "square.and.arrow.down").font(.calloutSerif)
                            }
                        }
                        .buttonStyle(QuietButtonStyle())
                        .disabled(savedIDs.contains(result.id) || savingID == result.id)
                    }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rule()
            HStack(spacing: 12) {
                Button {
                    shareItems = model.results.map { $0.url }
                } label: {
                    Label("Share All", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(OutlineButtonStyle())

                Button {
                    model.startOver()
                } label: {
                    Text("New Batch")
                }
                .buttonStyle(InkButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func save(_ result: ConversionResult) {
        savingID = result.id
        Task {
            let ok = await PhotoSaver.save(result.url)
            savingID = nil
            if ok { savedIDs.insert(result.id) }
            else { model.errorMessage = "Couldn't save to Photos. You can still share or save to Files." }
        }
    }
}

/// A subtle checkerboard shown behind transparent results so alpha reads.
struct CheckerHint: View {
    var body: some View {
        Canvas { ctx, size in
            let n = 8
            let s = size.width / CGFloat(n)
            for r in 0..<Int(size.height / s) + 1 {
                for c in 0..<n {
                    if (r + c) % 2 == 0 {
                        ctx.fill(Path(CGRect(x: CGFloat(c) * s, y: CGFloat(r) * s, width: s, height: s)),
                                 with: .color(Paper.sunken))
                    }
                }
            }
        }
        .background(Paper.raised)
    }
}
