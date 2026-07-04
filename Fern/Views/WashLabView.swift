import SwiftUI
import PhotosUI
import UIKit

/// A dev tuning screen for the photo color wash. Live-previews the wash on a
/// sample photo (or one you pick) and shows a copy-pasteable value string.
/// Changes save immediately, so the whole app reflects them.
struct WashLabView: View {
    @State private var p = WashParams.current
    @State private var picks: [PhotosPickerItem] = []
    @State private var sample = WashLabView.defaultSample()
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    tile(sample, "Original")
                    tile(EditorPhotos.washed(sample, params: p), "Wash")
                }

                PhotosPicker(selection: $picks, maxSelectionCount: 1, matching: .images) {
                    Label("Choose sample photo", systemImage: "photo")
                        .font(.calloutSerif)
                }
                .onChange(of: picks) { _, items in Task { await loadSample(items) } }

                VStack(spacing: 12) {
                    slider("Exposure (overall lift)", value: $p.exposure, in: -0.5...1.5)
                    slider("Brightness", value: $p.brightness, in: -0.3...0.4)
                    slider("Contrast", value: $p.contrast, in: 0.3...1.2)
                    slider("Tint amount", value: $p.intensity, in: 0...1)
                    slider("Tint → accent", value: $p.tintMix, in: 0...1)
                }

                Text(p.summary)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Paper.inkSoft)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = p.summary
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy values",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(InkButtonStyle())

                    Button("Reset") { p = WashParams() }
                        .buttonStyle(OutlineButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding()
        }
        .background(PaperBackground())
        .navigationTitle("Wash Lab")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: p) { _, v in v.save(); copied = false }
    }

    private func tile(_ image: UIImage, _ caption: String) -> some View {
        VStack(spacing: 6) {
            Image(uiImage: image)
                .resizable().scaledToFill()
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Paper.line, lineWidth: 1))
            Text(caption).font(.label).foregroundStyle(Paper.inkFaint)
        }
    }

    private func slider(_ label: String, value: Binding<Double>, in range: ClosedRange<Double>) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(label).font(.calloutSerif).foregroundStyle(Paper.inkSoft)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(.footnote, design: .monospaced)).foregroundStyle(Paper.ink)
            }
            Slider(value: value, in: range).tint(Paper.accent)
        }
    }

    private func loadSample(_ items: [PhotosPickerItem]) async {
        if let item = items.first,
           let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            sample = img
        }
        picks = []
    }

    /// A tonal test card — a black→white gradient with a few color patches so
    /// the wash's tonal range and tint are easy to judge without a photo.
    static func defaultSample() -> UIImage {
        let size = CGSize(width: 600, height: 380)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor.black.cgColor, UIColor.white.cgColor] as CFArray,
                                  locations: [0, 1])!
            cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            let patches: [(UIColor, CGRect)] = [
                (.systemRed,    CGRect(x: 40,  y: 40, width: 120, height: 120)),
                (.systemGreen,  CGRect(x: 200, y: 60, width: 120, height: 120)),
                (.systemBlue,   CGRect(x: 360, y: 40, width: 120, height: 120)),
                (.systemOrange, CGRect(x: 130, y: 210, width: 140, height: 120)),
                (.systemTeal,   CGRect(x: 320, y: 210, width: 140, height: 120))
            ]
            for (c, r) in patches {
                c.setFill()
                UIBezierPath(roundedRect: r, cornerRadius: 14).fill()
            }
        }
    }
}
