import SwiftUI

/// A quiet celebration when a writing streak reaches a milestone — the fern
/// grows, a haptic lands, and it fades on its own.
struct StreakFlourish: View {
    let days: Int
    let onDismiss: () -> Void
    @State private var appear = false
    private let fern = BarnsleyFern.random(count: 800_000)

    var body: some View {
        ZStack {
            Color.black.opacity(appear ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 14) {
                FlameFernView(fern: fern)
                    .frame(width: 120, height: 168)
                    .scaleEffect(appear ? 1 : 0.5, anchor: .bottom)
                VStack(spacing: 4) {
                    Text("\(days)")
                        .font(.display(56, .semibold))
                        .foregroundStyle(Paper.accent)
                    Text(days == 1 ? "day streak" : "days in a row")
                        .font(.label).textCase(.uppercase).tracking(1.6)
                        .foregroundStyle(Paper.inkSoft)
                }
                Text("Keep the thread going.")
                    .font(.bodySerif).foregroundStyle(Paper.inkSoft)
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Paper.raised)
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Paper.line, lineWidth: 1))
                    .shadow(color: Paper.ink.opacity(0.12), radius: 24, y: 10)
            )
            .scaleEffect(appear ? 1 : 0.88)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { appear = true }
            Task {
                try? await Task.sleep(for: .seconds(3.2))
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) { appear = false }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            onDismiss()
        }
    }
}
