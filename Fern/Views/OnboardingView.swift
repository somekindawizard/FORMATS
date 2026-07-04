import SwiftUI

/// A quiet first-run welcome — the fern, a line about what Fern is for, and a
/// single button to begin. Shown once (gated by AppStorage in RootView).
struct OnboardingView: View {
    /// Called with the entered name when the person taps Begin.
    var onBegin: (String) -> Void
    @State private var name = ""
    @FocusState private var nameFocused: Bool
    private let fern = BarnsleyFern(seed: 4_211, count: 26_000)

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 26) {
                Spacer()
                BarnsleyFernView(fern: fern, tint: Paper.accent, dotSize: 1.1, alpha: 0.7)
                    .frame(width: 140, height: 196)

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

                VStack(spacing: 8) {
                    Text("What should Fern call you?")
                        .font(.calloutSerif)
                        .foregroundStyle(Paper.inkSoft)
                    TextField("Your name", text: $name)
                        .font(.serif(20))
                        .foregroundStyle(Paper.ink)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit(begin)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 280)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Paper.raised)
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Paper.line, lineWidth: 1))
                        )
                }
                .padding(.top, 4)

                Spacer()

                Button(action: begin) { Text("Begin") }
                    .buttonStyle(InkButtonStyle())
                    .frame(maxWidth: 240)
                    .disabled(trimmedName.isEmpty)
                    .opacity(trimmedName.isEmpty ? 0.5 : 1)
                    .padding(.bottom, 40)
            }
        }
        .onAppear { nameFocused = true }
    }

    private func begin() {
        guard !trimmedName.isEmpty else { return }
        Haptics.tap()
        onBegin(trimmedName)
    }
}
