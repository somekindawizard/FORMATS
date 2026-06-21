import SwiftUI
import UIKit
import Photos

/// A thin wrapper over `UIActivityViewController` for sharing files.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Saves a converted file to the photo library (raster formats only).
enum PhotoSaver {
    @discardableResult
    static func save(_ url: URL) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: url, options: nil)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
