import SwiftUI
import Observation

@MainActor
@Observable
final class AppModel {

    // Navigation
    enum Route: Hashable { case convert, results }
    var path: [Route] = []

    // Working set
    var sources: [SourceImage] = []
    var target: ImageFormat
    var settings = ConversionSettings()
    var results: [ConversionResult] = []

    // Run state
    var isWorking = false
    var progress: Double = 0
    var errorMessage: String?

    let availableFormats: [ImageFormat]

    init() {
        let formats = FormatCatalog.available
        availableFormats = formats
        // Prefer a modern, efficient default the device can actually write.
        target = formats.first { $0.uti == "public.avif" }
            ?? formats.first { $0.uti == "public.heic" }
            ?? formats.first { $0.uti == "public.jpeg" }
            ?? formats.first
            ?? FormatCatalog.known[2] // JPEG fallback (always known)
    }

    var hasSources: Bool { !sources.isEmpty }

    // MARK: - Import

    func add(datas: [(data: Data, name: String)]) {
        for item in datas {
            if let s = ImageImporter.makeSource(data: item.data, suggestedName: item.name) {
                sources.append(s)
            }
        }
    }

    func add(urls: [URL]) {
        for url in urls {
            if let s = ImageImporter.makeSource(copying: url) {
                sources.append(s)
            }
        }
    }

    func remove(_ source: SourceImage) {
        sources.removeAll { $0.id == source.id }
    }

    func startOver() {
        sources.removeAll()
        results.removeAll()
        progress = 0
        path.removeAll()
        TempFiles.clearOutputs()
    }

    // MARK: - Convert

    func runConversion() async {
        guard hasSources else { return }
        isWorking = true
        progress = 0
        results.removeAll()
        errorMessage = nil

        let format = target
        let settings = settings
        let items = sources
        var firstError: String?

        for (index, source) in items.enumerated() {
            let outcome: Result<ConversionResult, Error> = await Task.detached(priority: .userInitiated) {
                do { return .success(try ConversionEngine.convert(source, to: format, settings: settings)) }
                catch { return .failure(error) }
            }.value

            switch outcome {
            case .success(let r): results.append(r)
            case .failure(let e): if firstError == nil { firstError = e.localizedDescription }
            }
            progress = Double(index + 1) / Double(items.count)
        }

        isWorking = false
        if results.isEmpty {
            errorMessage = firstError ?? "Nothing could be converted."
        } else {
            path.append(.results)
        }
    }

    // MARK: - Cut out

    func runCutout() async {
        guard hasSources else { return }
        isWorking = true
        progress = 0
        results.removeAll()
        errorMessage = nil

        let items = sources
        var firstError: String?

        for (index, source) in items.enumerated() {
            let outcome: Result<ConversionResult, Error> = await Task.detached(priority: .userInitiated) {
                do { return .success(try BackgroundRemover.cutoutToPNG(source)) }
                catch { return .failure(error) }
            }.value

            switch outcome {
            case .success(let r): results.append(r)
            case .failure(let e): if firstError == nil { firstError = e.localizedDescription }
            }
            progress = Double(index + 1) / Double(items.count)
        }

        isWorking = false
        if results.isEmpty {
            errorMessage = firstError ?? "No subjects could be lifted."
        } else {
            path.append(.results)
        }
    }
}
