import SwiftUI
import UIKit

/// Redwood settings — currently the theme accent, which recolors the app *and*
/// swaps the app icon to a matching tinted redwood.
struct RedwoodSettings: View {
    @Environment(\.dismiss) private var dismiss
    @State private var theme = ThemeStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Accent").sectionLabel()
                        Text("Sets the app's color and its home-screen icon.")
                            .font(.calloutSerif).foregroundStyle(Paper.inkSoft)

                        HStack(spacing: 16) {
                            ForEach(AccentTone.allCases) { tone in
                                swatch(tone)
                            }
                            Spacer()
                        }
                        .padding(.top, 2)

                        // A live preview of the tinted tree.
                        Image("RedwoodTree")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(height: 220)
                            .foregroundStyle(Paper.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Paper.accent)
                }
            }
        }
    }

    private func swatch(_ tone: AccentTone) -> some View {
        let selected = theme.accent == tone
        return Button {
            apply(tone)
        } label: {
            Circle()
                .fill(tone.swatch)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle().stroke(Paper.ink.opacity(selected ? 0.9 : 0), lineWidth: 2)
                        .padding(-4)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(selected ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tone.rawValue)
    }

    /// Recolor the app and swap the home-screen icon to match.
    private func apply(_ tone: AccentTone) {
        Haptics.tap()
        theme.accent = tone
        let iconName = Self.iconName(for: tone)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        if UIApplication.shared.alternateIconName != iconName {
            UIApplication.shared.setAlternateIconName(iconName)
        }
    }

    /// Primary AppIcon is sienna; the rest are alternate icon assets.
    static func iconName(for tone: AccentTone) -> String? {
        switch tone {
        case .sienna: return nil
        case .sage:   return "AppIcon-Sage"
        case .indigo: return "AppIcon-Indigo"
        case .plum:   return "AppIcon-Plum"
        case .ochre:  return "AppIcon-Ochre"
        }
    }
}
