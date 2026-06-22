import SwiftUI
import UIKit

/// A small Identifiable wrapper so we can drive a share sheet from `.sheet(item:)`.
struct ShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

/// Bridges UIActivityViewController (the system share sheet) into SwiftUI.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
