import SwiftUI

/// Lets a pushed screen (the editor) ask the custom tab bar to hide. Preferences
/// flow up to RootView; sheets are a separate tree, which is fine — they cover
/// the bar anyway.
struct HidesTabBarKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func hidesFernTabBar(_ hidden: Bool = true) -> some View {
        preference(key: HidesTabBarKey.self, value: hidden)
    }
}

/// A bespoke, paper-and-ink tab bar: a floating raised card with serif labels
/// and a soft sienna selection pill that glides between tabs.
struct FernTabBar: View {
    @Binding var selection: Destination
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Destination.allCases) { dest in
                item(dest)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Paper.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Paper.line, lineWidth: 1)
                )
                .shadow(color: Paper.ink.opacity(0.10), radius: 18, x: 0, y: 8)
        )
        .padding(.horizontal, 26)
        .padding(.bottom, 2)
    }

    private func item(_ dest: Destination) -> some View {
        let active = dest == selection
        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selection = dest
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: active ? dest.symbolActive : dest.symbol)
                    .font(.system(size: 17, weight: active ? .semibold : .regular))
                Text(dest.title)
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .tracking(0.2)
            }
            .foregroundStyle(active ? Paper.accent : Paper.inkFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Paper.accent.opacity(0.10))
                        .matchedGeometryEffect(id: "fern.tab.pill", in: ns)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
