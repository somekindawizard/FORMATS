import SwiftUI

struct LockGate<Content: View>: View {
    @Environment(BiometricLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    @State private var unfurl: Double = 0
    @State private var veilOpacity: Double = 1
    let content: () -> Content

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
        .onAppear { Task { await tryUnlock() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.relock() }
            if phase == .active && lock.isEnabled && !lock.isUnlocked {
                Task { await tryUnlock() }
            }
        }
        .onChange(of: lock.isEnabled) { _, enabled in
            // Toggling off in Settings should also drop the gate immediately.
            if !enabled { lock.isUnlocked = true; veilOpacity = 0 }
        }
    }

    private var veil: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 18) {
                FiddleheadShape(unfurl: unfurl)
                    .stroke(Paper.accent,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: 180, height: 240)
                Text("Fern")
                    .font(.masthead)
                    .foregroundStyle(Paper.ink)
                Button("Unlock") { Task { await tryUnlock() } }
                    .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private func tryUnlock() async {
        let ok = await lock.authenticate()
        guard ok else { return }
        // Unfurl + dissolve sequence.
        withAnimation(.spring(response: 0.95, dampingFraction: 0.78)) {
            unfurl = 1
        }
        try? await Task.sleep(nanoseconds: 600_000_000)
        withAnimation(.easeInOut(duration: 0.45)) {
            veilOpacity = 0
        }
    }
}
