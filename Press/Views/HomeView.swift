import SwiftUI
import PhotosUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    @State private var picks: [PhotosPickerItem] = []
    @State private var showFiles = false
    @State private var loadingPicks = false

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    masthead
                    Rule()
                    importBlock

                    if model.hasSources {
                        selectedBlock
                        actionsBlock
                    } else {
                        emptyNote
                    }

                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(isPresented: $showFiles,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { model.add(urls: urls) }
        }
        .onChange(of: picks) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task { await load(newValue) }
        }
        .alert("Couldn't convert",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: Sections

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE IMAGE CONVERTER")
                .sectionLabel()
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Press")
                    .font(.mastheadXL)
                    .foregroundStyle(Paper.ink)
                Text(".")
                    .font(.mastheadXL)
                    .foregroundStyle(Paper.accent)
            }
            Text("Convert any image into the format you need — beautifully, privately, on your device.")
                .font(.serif(17))
                .italic()
                .foregroundStyle(Paper.inkSoft)
                .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    private var importBlock: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $picks, maxSelectionCount: 40, matching: .images,
                         photoLibrary: .shared()) {
                Label("Choose Photos", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(InkButtonStyle())

            Button {
                showFiles = true
            } label: {
                Label("Browse Files", systemImage: "folder")
            }
            .buttonStyle(OutlineButtonStyle())

            if loadingPicks {
                HStack(spacing: 8) {
                    ProgressView().tint(Paper.inkSoft)
                    Text("Loading…").font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                }
                .padding(.top, 2)
            }
        }
    }

    private var selectedBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Selected",
                          trailing: "\(model.sources.count) image\(model.sources.count == 1 ? "" : "s")")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(model.sources) { source in
                        SourceThumb(source: source) { model.remove(source) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var actionsBlock: some View {
        VStack(spacing: 12) {
            Button {
                model.path.append(.convert)
            } label: {
                Label("Convert Format", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(InkButtonStyle())

            Button {
                Task { await model.runCutout() }
            } label: {
                Label("Remove Background", systemImage: "person.and.background.dotted")
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(model.isWorking)

            Button("Clear selection") { model.startOver() }
                .buttonStyle(QuietButtonStyle())
                .padding(.top, 2)
        }
        .overlay {
            if model.isWorking { WorkingOverlay(progress: model.progress) }
        }
    }

    private var emptyNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rule()
            Text("Add photos to begin. Everything happens on this iPhone — nothing is uploaded.")
                .font(.serif(15))
                .foregroundStyle(Paper.inkFaint)
        }
        .padding(.top, 4)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rule()
            HStack {
                Text("\(model.availableFormats.count) output formats")
                Spacer()
                Text("On-device · Private")
            }
            .font(.figure(11))
            .foregroundStyle(Paper.inkFaint)
            .padding(.top, 6)
        }
    }

    // MARK: Loading

    private func load(_ items: [PhotosPickerItem]) async {
        loadingPicks = true
        var collected: [(Data, String)] = []
        for (i, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                collected.append((data, "Image \(model.sources.count + i + 1)"))
            }
        }
        model.add(datas: collected.map { (data: $0.0, name: $0.1) })
        picks.removeAll()
        loadingPicks = false
    }
}

/// A small framed thumbnail with a remove affordance.
struct SourceThumb: View {
    let source: SourceImage
    var onRemove: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: source.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Paper.line, lineWidth: 1)
                    )
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Paper.bg)
                            .padding(6)
                            .background(Circle().fill(Paper.ink.opacity(0.85)))
                    }
                    .padding(5)
                }
            }
            Text(source.formatName)
                .font(.figure(10))
                .foregroundStyle(Paper.inkSoft)
            if source.hasGainMap {
                Text("HDR")
                    .font(.figure(9, .bold))
                    .foregroundStyle(Paper.accent)
            }
        }
        .frame(width: 104)
    }
}

/// A quiet working veil shown over the action area.
struct WorkingOverlay: View {
    let progress: Double
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Paper.bg.opacity(0.7))
            VStack(spacing: 8) {
                ProgressView(value: progress).tint(Paper.accent).frame(width: 160)
                Text("Working…").font(.calloutSerif).foregroundStyle(Paper.inkSoft)
            }
        }
        .allowsHitTesting(true)
    }
}
