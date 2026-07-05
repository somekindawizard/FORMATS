import SwiftUI
import PencilKit

/// Shows a note's Apple Pencil ink, with a play button that replays the
/// handwriting stroke by stroke — the page filling in as it was written.
struct InkReplay: View {
    let drawing: PKDrawing
    var maxWidth: CGFloat

    /// nil = show the whole drawing; a number reveals that many strokes.
    @State private var revealed: Int?
    @State private var player: Task<Void, Never>?

    private var displayImage: UIImage {
        let strokes = drawing.strokes
        let shown = revealed.map { Array(strokes.prefix($0)) } ?? Array(strokes)
        let bounds = drawing.bounds
        guard bounds.width > 1, bounds.height > 1 else { return UIImage() }
        return PKDrawing(strokes: shown).image(from: bounds, scale: UIScreen.main.scale)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: displayImage)
                .resizable().scaledToFit()
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
            Button { play() } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Paper.accent, Paper.bg)
                    .shadow(color: Paper.ink.opacity(0.15), radius: 3, y: 1)
            }
            .padding(6)
            .accessibilityLabel("Replay handwriting")
        }
        .onDisappear { player?.cancel() }
    }

    private func play() {
        player?.cancel()
        let total = drawing.strokes.count
        guard total > 0 else { return }
        Haptics.tap()
        player = Task { @MainActor in
            revealed = 0
            for i in 1...total {
                revealed = i
                // Faster when there are many strokes so long notes don't drag.
                let step = total > 40 ? 0.05 : 0.12
                try? await Task.sleep(for: .seconds(step))
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .seconds(0.4))
            revealed = nil   // settle on the finished drawing
        }
    }
}
