import SwiftUI

/// A quiet first-run welcome — the fern, a line about what Fern is for, and a
/// single button to begin. Shown once (gated by AppStorage in RootView).
struct OnboardingView: View {
    var onBegin: () -> Void
    private let fern = BarnsleyFern(seed: 4_211, count: 26_000)

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 28) {
                Spacer()
                BarnsleyFernView(fern: fern, tint: Paper.accent, dotSize: 1.1, alpha: 0.7)
                    .frame(width: 150, height: 210)

                VStack(spacing: 12) {
                    Text("Fern")
                        .font(.mastheadXL)
                        .foregroundStyle(Paper.ink)
                    Text("A quiet place to write, sketch, and remember. Paper and ink, nothing louder.")
                        .font(.bodySerif)
                        .foregroundStyle(Paper.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()

                Button {
                    Haptics.tap()
                    onBegin()
                } label: {
                    Text("Begin")
                }
                .buttonStyle(InkButtonStyle())
                .frame(maxWidth: 240)
                .padding(.bottom, 50)
            }
        }
    }
}
