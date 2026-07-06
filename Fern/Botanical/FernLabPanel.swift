import SwiftUI

#if DEBUG
/// A live tuning panel for the interactive fern's physics — DEBUG builds only.
/// Slide to change the feel in real time; values persist across launches
/// (see FernTuning) and Copy puts them on the clipboard to be baked into
/// `FernPhysicsParams.defaults`. Forced-white card so it reads over any paper.
struct FernLabPanel: View {
    @ObservedObject var tuning: FernTuning
    let onClose: () -> Void
    @State private var showHelp = false
    @State private var copied = false

    /// One entry per slider: label, explanation for the help legend.
    private static let legend: [(String, String)] = [
        ("spring",    "How hard each point is pulled back to its home spot. Higher = snappier return, lower = lazy drift."),
        ("damping",   "How quickly motion dies out. Lower = more wobble and overshoot when the fern settles; higher = syrupy."),
        ("glblDamp",  "A per-frame brake on all velocity (stability). 1.0 = none; lower values calm runaway jiggle."),
        ("fingerR",   "Radius of your finger's influence, in points. Bigger = a wider wake sweeps through the fronds."),
        ("push",      "How hard points are shoved out of the finger's way. The 'splash' strength."),
        ("dragCpl",   "How much points get carried along with a moving finger. Higher = fast swipes fling points further."),
        ("pointSz",   "Size of each drawn point (px at 3x). Bigger = softer, denser-looking fern; smaller = finer grain."),
        ("toneFloor", "Minimum darkness of any inked pixel. Raise if sparse feathery areas look too light."),
        ("densDenom", "Overall tone normalizer. Raise = lighter fern everywhere; lower = darker."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Fern Lab").font(.system(size: 15, weight: .semibold, design: .monospaced))
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showHelp.toggle() }
                } label: {
                    Image(systemName: showHelp ? "questionmark.circle.fill" : "questionmark.circle")
                        .font(.system(size: 15))
                }
                Spacer()
                Button(copied ? "Copied" : "Copy") { copyValues() }
                    .font(.system(size: 12, weight: .medium))
                Button("Reset") { tuning.params = .defaults }
                    .font(.system(size: 12, weight: .medium))
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 18))
                }
            }
            .foregroundStyle(.black)

            if showHelp {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Self.legend, id: \.0) { name, blurb in
                        (Text(name + "  ").font(.system(size: 10, weight: .bold, design: .monospaced))
                         + Text(blurb).font(.system(size: 10)))
                            .foregroundStyle(.black.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity)
            }

            row("spring",     value: $tuning.params.springK,      in: 20...400,     fmt: "%.0f")
            row("damping",    value: $tuning.params.damping,      in: 0...20,       fmt: "%.1f")
            row("glblDamp",   value: $tuning.params.globalDamp,   in: 0.90...1.0,   fmt: "%.3f")
            row("fingerR",    value: $tuning.params.fingerRadius, in: 30...220,     fmt: "%.0f")
            row("push",       value: $tuning.params.pushStrength, in: 0...80000,    fmt: "%.0f")
            row("dragCpl",    value: $tuning.params.dragCoupling, in: 0...8,        fmt: "%.2f")
            row("pointSz",    value: $tuning.params.pointSize,    in: 1...6,        fmt: "%.2f")
            row("toneFloor",  value: $tuning.params.toneFloor,    in: 0...0.9,      fmt: "%.2f")
            row("densDenom",  value: $tuning.params.densityDenom, in: 2...12,       fmt: "%.2f")

            Text(summary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.black.opacity(0.55))
                .textSelection(.enabled)
                .padding(.top, 2)
        }
        .padding(14)
        // Forced white regardless of paper tone or dark mode, so the lab is
        // always legible over the fern.
        .background(.white.opacity(0.97), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(.black.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 5)
        .environment(\.colorScheme, .light)
        .padding(.horizontal, 12)
    }

    private func row(_ label: String, value: Binding<Float>,
                     in range: ClosedRange<Float>, fmt: String) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.black).frame(width: 74, alignment: .leading)
            Slider(value: value, in: range).tint(.black)
            Text(String(format: fmt, value.wrappedValue))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.black.opacity(0.8)).frame(width: 54, alignment: .trailing)
        }
    }

    private var summary: String {
        let p = tuning.params
        return String(format: "springK:%.0f damping:%.1f globalDamp:%.3f fingerRadius:%.0f pushStrength:%.0f dragCoupling:%.2f pointSize:%.2f toneFloor:%.2f densityDenom:%.2f",
                      p.springK, p.damping, p.globalDamp, p.fingerRadius,
                      p.pushStrength, p.dragCoupling, p.pointSize, p.toneFloor, p.densityDenom)
    }

    private func copyValues() {
        UIPasteboard.general.string = summary
        Haptics.tap()
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }
}
#endif
