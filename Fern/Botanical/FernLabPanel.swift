import SwiftUI

#if DEBUG
/// A live tuning panel for the interactive fern's physics — DEBUG builds only.
/// Slide to change the feel in real time; read the values off the bottom and
/// they can be baked into `FernPhysicsParams.defaults`.
struct FernLabPanel: View {
    @ObservedObject var tuning: FernTuning
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Fern Lab").font(.system(size: 15, weight: .semibold, design: .monospaced))
                Spacer()
                Button("Reset") { tuning.params = .defaults }
                    .font(.system(size: 12, weight: .medium))
                Button {
                    onClose()
                } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18)) }
            }
            .foregroundStyle(.white)

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
                .foregroundStyle(.white.opacity(0.7))
                .textSelection(.enabled)
                .padding(.top, 2)
        }
        .padding(14)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
    }

    private func row(_ label: String, value: Binding<Float>,
                     in range: ClosedRange<Float>, fmt: String) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white).frame(width: 74, alignment: .leading)
            Slider(value: value, in: range).tint(.white)
            Text(String(format: fmt, value.wrappedValue))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85)).frame(width: 54, alignment: .trailing)
        }
    }

    private var summary: String {
        let p = tuning.params
        return String(format: "springK:%.0f damping:%.1f globalDamp:%.3f fingerRadius:%.0f pushStrength:%.0f dragCoupling:%.2f pointSize:%.2f toneFloor:%.2f densityDenom:%.2f",
                      p.springK, p.damping, p.globalDamp, p.fingerRadius,
                      p.pushStrength, p.dragCoupling, p.pointSize, p.toneFloor, p.densityDenom)
    }
}
#endif
