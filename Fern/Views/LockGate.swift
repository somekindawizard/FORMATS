import SwiftUI

struct LockGate<Content: View>: View {
    @Environment(BiometricLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    @State private var veilOpacity: Double = 1
    @State private var pulse = false
    @State private var shakeX: CGFloat = 0
    let content: () -> Content

    // The lock fern — deterministic, same seed as the icon/empty state.
    // Slightly fewer points since it re-draws every frame while swaying.
    private let fern = BarnsleyFern(seed: 4_211, count: 11_000)

    var body: some View {
        ZStack {
            content()
                .allowsHitTesting(lock.isUnlocked)
            if lock.isEnabled && !lock.isUnlocked {
                veil
                    .opacity(veilOpacity)
                    .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { relock() }
        }
        .onChange(of: lock.isEnabled) { _, enabled in
            // Toggling off in Settings drops the gate immediately.
            if !enabled { lock.isUnlocked = true; veilOpacity = 0 }
        }
    }

    private var veil: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 22) {
                BarnsleyFernView(fern: fern, sway: true)
                    .frame(width: 200, height: 280)
                    .scaleEffect(pulse ? 1.05 : 1.0)
                    .offset(x: shakeX)
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await reactAndUnlock() } }

                VStack(spacing: 4) {
                    Text("Fern")
                        .font(.masthead)
                        .foregroundStyle(Paper.ink)
                    Text("Tap the fern to unlock")
                        .font(.calloutSerif)
                        .foregroundStyle(Paper.inkSoft)
                }
            }
        }
    }

    private func relock() {
        guard lock.isEnabled else { return }
        lock.isUnlocked = false
        veilOpacity = 1
        pulse = false
        shakeX = 0
    }

    private func reactAndUnlock() async {
        // The fern blooms slightly as the system prompt comes up.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { pulse = true }

        let ok = await lock.authenticate()

        if ok {
            // Hold the bloom, then dissolve the veil to reveal the library.
            withAnimation(.easeOut(duration: 0.5)) { veilOpacity = 0 }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pulse = false }
            await shake()
        }
    }

    private func shake() async {
        for dx in [CGFloat(-10), 10, -6, 6, 0] {
            withAnimation(.linear(duration: 0.05)) { shakeX = dx }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
