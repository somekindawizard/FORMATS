import SwiftUI

/// A selectable, editorial row describing one output format.
struct FormatRow: View {
    let format: ImageFormat
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(format.name)
                            .font(.titleSerif)
                            .foregroundStyle(Paper.ink)
                        Text(".\(format.ext)")
                            .font(.figure(11))
                            .foregroundStyle(Paper.inkFaint)
                    }
                    Text(format.blurb)
                        .font(.serif(14))
                        .foregroundStyle(Paper.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ForEach(traits, id: \.self) { TraitTag(text: $0) }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                SelectionDot(selected: selected)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var traits: [String] {
        var t: [String] = [format.lossy ? "Lossy" : "Lossless"]
        if format.supportsAlpha { t.append("Alpha") }
        if format.supportsHDR { t.append("HDR") }
        if format.supportsAnimation { t.append("Animation") }
        return t
    }
}

private struct TraitTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.figure(9, .medium))
            .tracking(0.4)
            .foregroundStyle(Paper.inkSoft)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Paper.sunken)
            )
            .overlay(Capsule().stroke(Paper.line, lineWidth: 0.75))
    }
}

private struct SelectionDot: View {
    let selected: Bool
    var body: some View {
        ZStack {
            Circle()
                .stroke(selected ? Paper.accent : Paper.line, lineWidth: 1.5)
                .frame(width: 24, height: 24)
            if selected {
                Circle().fill(Paper.accent).frame(width: 13, height: 13)
            }
        }
        .padding(.top, 4)
    }
}
