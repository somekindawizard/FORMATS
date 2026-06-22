import SwiftUI

/// A square, shareable paper-and-ink card of an entry. Rendered to an image by
/// `ImageRenderer`. Uses fixed light colors so the shared image looks the same
/// regardless of the device's appearance.
struct PaperCard: View {
    let entry: Entry

    private let paper   = Color(red: 0.965, green: 0.961, blue: 0.945)
    private let ink     = Color(red: 0.110, green: 0.102, blue: 0.090)
    private let inkSoft = Color(red: 0.357, green: 0.341, blue: 0.314)
    private let accent  = Color(red: 0.604, green: 0.290, blue: 0.176)
    private let line    = Color(red: 0.922, green: 0.914, blue: 0.882)
    private let fern = BarnsleyFern(seed: 4_211, count: 14_000)

    private var excerpt: String {
        let body = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty { return body }
        return entry.prompt ?? ""
    }

    var body: some View {
        ZStack {
            paper
            VStack(alignment: .leading, spacing: 24) {
                Text(entry.createdAt.formatted(.dateTime.month(.wide).day().year()))
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .textCase(.uppercase).tracking(3)
                    .foregroundStyle(inkSoft)

                Text(entry.displayTitle)
                    .font(.system(size: 64, weight: .medium, design: .serif))
                    .foregroundStyle(ink)
                    .lineLimit(3)

                if !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.system(size: 34, design: .serif))
                        .foregroundStyle(inkSoft)
                        .lineLimit(9)
                        .lineSpacing(8)
                }

                Spacer()

                Rectangle().fill(line).frame(height: 1)

                HStack(alignment: .bottom) {
                    Text("Fern")
                        .font(.system(size: 40, design: .serif))
                        .foregroundStyle(ink)
                    + Text(".").font(.system(size: 40, design: .serif)).foregroundStyle(accent)
                    Spacer()
                    BarnsleyFernView(fern: fern, tint: accent, dotSize: 1.0, alpha: 0.7)
                        .frame(width: 130, height: 180)
                }
            }
            .padding(64)
        }
        .frame(width: 1080, height: 1080)
    }
}
