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
    /// True while the Face ID sheet is up — it makes the scene .inactive, and
    /// the privacy cover must not react to that.
    @State private var authenticating = false
    /// Covers content in the app switcher / on interruption (.inactive) so a
    /// journal page is never captured in the system snapshot.
    @State private var privacyCover = false
    let content: () -> Content

    /// Show the fern when the session hasn't been entered yet and either the
    /// welcome ritual is on or biometrics require it.
    private var gateShown: Bool { locked && (welcomeGate || lock.isEnabled) }

    // A fresh, unique fern grows on every unlock — regenerated when the gate
    // re-locks. High point count so the flame render reads as solid ink, not speckle.
    @State private var fern = BarnsleyFern.random(count: 800_000)

    var body: some View {
        ZStack {
            content()
                .allowsHitTesting(!gateShown)
                // Veiled content must be invisible to VoiceOver too.
                .accessibilityHidden(gateShown || privacyCover)
            if gateShown {
                veil
                    .opacity(veilOpacity)
                    .transition(.opacity)
            } else if privacyCover {
                // Quiet cover for the app-switcher snapshot — no auth needed;
                // it lifts as soon as the app is active again.
                ZStack {
                    PaperBackground()
                    Text("Fern")
                        .font(.masthead)
                        .foregroundStyle(Paper.ink)
                }
                .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                relock()
                privacyCover = false   // gate (if any) takes over from here
            case .inactive:
                // Cover content on interruption — but not while the Face ID
                // sheet (which makes us .inactive) is up, and not under the veil.
                if !gateShown && !authenticating { privacyCover = true }
            case .active:
                privacyCover = false
            @unknown default:
                break
            }
        }
        .onAppear { lock.gateVisible = gateShown }
        .onChange(of: gateShown) { _, shown in lock.gateVisible = shown }
    }

    private var veil: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 22) {
                InteractiveFernView(fern: fern, tint: Paper.accent) {
                    Task { await reactAndUnlock() }
                }
                    .frame(maxWidth: 360)
                    .frame(height: 460)
                    .scaleEffect(pulse ? 1.04 : 1.0)
                    .offset(x: shakeX)

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
        fern = BarnsleyFern.random(count: 800_000)   // a new fern each time
        veilOpacity = 1
        pulse = false
        shakeX = 0
    }

    private func reactAndUnlock() async {
        // The fern blooms slightly as it opens.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { pulse = true }

        if lock.isEnabled {
            authenticating = true
            let ok = await lock.authenticate()
            authenticating = false
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
