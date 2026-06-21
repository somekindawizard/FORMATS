import SwiftUI

struct ConvertView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model

        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    sourceSummary

                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader(title: "Convert to")
                        formatList
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Options")
                        optionsCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.calloutSerif)
                    .foregroundStyle(Paper.inkSoft)
                    .labelStyle(.titleAndIcon)
            }
            Spacer()
        }
        .padding(.top, 6)
    }

    private var sourceSummary: some View {
        HStack(spacing: 12) {
            if let first = model.sources.first {
                Image(uiImage: first.thumbnail)
                    .resizable().scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Paper.line, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(model.sources.count == 1
                     ? (model.sources.first?.displayName ?? "1 image")
                     : "\(model.sources.count) images")
                    .font(.headline)
                    .foregroundStyle(Paper.ink)
                Text(summaryDetail)
                    .font(.figure(12))
                    .foregroundStyle(Paper.inkSoft)
            }
            Spacer()
        }
    }

    private var summaryDetail: String {
        let total = model.sources.reduce(0) { $0 + $1.byteSize }
        if let only = model.sources.first, model.sources.count == 1 {
            return "\(only.formatName) · \(Format.dimensions(only.pixelSize)) · \(Format.bytes(total))"
        }
        return "Total \(Format.bytes(total))"
    }

    private var formatList: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.availableFormats.enumerated()), id: \.element.id) { index, format in
                if index > 0 { Rule() }
                FormatRow(format: format, selected: model.target.id == format.id) {
                    withAnimation(.easeOut(duration: 0.18)) { model.target = format }
                }
            }
        }
        .card(padding: 18)
    }

    // MARK: Options

    private var optionsCard: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            if model.target.hasQuality {
                qualityRow
                Rule()
            }
            resolutionRow
            Rule()
            toggleRow(title: "Keep metadata",
                      subtitle: "EXIF, date and location. Off strips it for privacy.",
                      isOn: $model.settings.preserveMetadata)
            if model.target.supportsHDR {
                Rule()
                toggleRow(title: "Preserve HDR",
                          subtitle: "Keep the ISO 21496-1 gain map when present.",
                          isOn: $model.settings.preserveHDR)
            }
        }
        .card(padding: 18)
    }

    private var qualityRow: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Quality").font(.headline).foregroundStyle(Paper.ink)
                Spacer()
                Text("\(model.settings.qualityLabel) · \(Int(model.settings.quality * 100))%")
                    .font(.figure(12))
                    .foregroundStyle(Paper.inkSoft)
            }
            Slider(value: $model.settings.quality, in: 0.1...1.0)
                .tint(Paper.accent)
        }
        .padding(.vertical, 14)
    }

    private var resolutionRow: some View {
        @Bindable var model = model
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Resolution").font(.headline).foregroundStyle(Paper.ink)
                Text("Downscale large images on the way out.")
                    .font(.serif(13)).foregroundStyle(Paper.inkSoft)
            }
            Spacer()
            Menu {
                Picker("Resolution", selection: $model.settings.resize) {
                    ForEach(ConversionSettings.ResizeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(model.settings.resize.rawValue)
                        .font(.calloutSerif)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                }
                .foregroundStyle(Paper.ink)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Paper.sunken))
                .overlay(Capsule().stroke(Paper.line, lineWidth: 1))
            }
        }
        .padding(.vertical, 14)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Paper.ink)
                Text(subtitle).font(.serif(13)).foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Paper.accent)
        }
        .padding(.vertical, 14)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rule()
            Button {
                Task { await model.runConversion() }
            } label: {
                if model.isWorking {
                    HStack(spacing: 10) {
                        ProgressView().tint(Paper.bg)
                        Text("Converting \(Int(model.progress * 100))%")
                    }
                } else {
                    Text(model.sources.count > 1
                         ? "Convert \(model.sources.count) to \(model.target.name)"
                         : "Convert to \(model.target.name)")
                }
            }
            .buttonStyle(InkButtonStyle())
            .disabled(model.isWorking)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }
}
