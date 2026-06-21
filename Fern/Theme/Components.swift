import SwiftUI

/// A single ink hairline — the workhorse divider.
struct Rule: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(Paper.line)
            .frame(height: 1)
            .padding(.horizontal, inset)
    }
}

private struct CardModifier: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Paper.raised))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Paper.line, lineWidth: 1))
            .shadow(color: Paper.ink.opacity(0.05), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View { modifier(CardModifier(padding: padding)) }
}

/// The solid ink call-to-action, set in cream serif.
struct InkButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headlineSerif)
            .tracking(0.3)
            .foregroundStyle(Paper.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(enabled ? Paper.ink : Paper.inkFaint))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// An outlined, quieter action.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headlineSerif)
            .foregroundStyle(Paper.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Paper.raised.opacity(configuration.isPressed ? 1 : 0)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Paper.ink, lineWidth: 1.2))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A small text button for inline, low-emphasis actions.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.calloutSerif)
            .foregroundStyle(configuration.isPressed ? Paper.inkFaint : Paper.inkSoft)
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).sectionLabel()
            Spacer()
            if let trailing {
                Text(trailing).font(.figure(12)).foregroundStyle(Paper.inkFaint)
            }
        }
    }
}

/// Adds a gentle press response to any tappable surface.
struct PressableScale: ViewModifier {
    @GestureState private var pressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: pressed)
            .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { _, state, _ in state = true })
    }
}

extension View {
    func pressable() -> some View { modifier(PressableScale()) }
}
