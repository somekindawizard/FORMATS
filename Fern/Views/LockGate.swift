import SwiftUI

struct LockGate<Content: View>: View {
    @Environment(BiometricLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    /// The "touch the fern" welcome ritual — shown on open even when Face ID /
    /// Touch ID are off. Biometrics, when enabled, layer authentication on top.
    @AppStorage("fern.gate.enabled") private var welcomeGate = true
    @State private var locked = true
    @State private var veilOpacity: Double = 1
    @State private var pulse = false
    @State private var shakeX: CGFloat = 0
    let content: () -> Content

    /// Show the fern when the session hasn't been entered yet and either the
    /// welcome ritual is on or biometrics require it.
    private var gateShown: Bool { locked && (welcomeGate || lock.isEnabled) }

    // A fresh, unique fern grows on every unlock — regenerated when the gate
    // re-locks. Slightly fewer points since it re-draws each frame while swaying.
    @State private var fern = BarnsleyFern.random(count: 11_000)

    var body: some View {
        ZStack {
            content()
                .allowsHitTesting(!gateShown)
            if gateShown {
                veil
                    .opacity(veilOpacity)
                    .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { relock() }
        }
    }

    private var veil: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 22) {
                BarnsleyFernView(fern: fern, sway: true)
                    .frame(maxWidth: 360)
                    .frame(height: 460)
                    .scaleEffect(pulse ? 1.04 : 1.0)
                    .offset(x: shakeX)
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await reactAndUnlock() } }

                VStack(spacing: 4) {
                    Text("Fern")
                        .font(.masthead)
                        .foregroundStyle(Paper.ink)
                    Text(lock.isEnabled ? "Tap the fern to unlock" : "Tap the fern to begin")
                        .font(.calloutSerif)
                        .foregroundStyle(Paper.inkSoft)
                }
            }
        }
    }

    private func relock() {
        // Re-show the fern on return — the welcome ritual (and biometric re-lock).
        guard welcomeGate || lock.isEnabled else { return }
        locked = true
        lock.relock()
        fern = BarnsleyFern.random(count: 11_000)   // a new fern each time
        veilOpacity = 1
        pulse = false
        shakeX = 0
    }

    private func reactAndUnlock() async {
        // The fern blooms slightly as it opens.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { pulse = true }

        if lock.isEnabled {
            let ok = await lock.authenticate()
            if ok {
                dissolve()
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pulse = false }
                await shake()
            }
        } else {
            // No biometrics — the fern touch alone opens the app.
            dissolve()
        }
    }

    /// Fade the veil away, then remove it and reset for next time.
    private func dissolve() {
        withAnimation(.easeOut(duration: 0.5)) { veilOpacity = 0 }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            locked = false
            veilOpacity = 1
        }
    }

    private func shake() async {
        for dx in [CGFloat(-10), 10, -6, 6, 0] {
            withAnimation(.linear(duration: 0.05)) { shakeX = dx }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
