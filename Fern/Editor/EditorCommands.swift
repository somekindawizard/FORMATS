import SwiftUI

/// Exposes the focused editor's controller to app-level menu commands, so Mac
/// menus and keyboard shortcuts can format the note the accessory bar handles on
/// iOS (the accessory bar rides the software keyboard, which Mac doesn't show).
private struct EditorControllerKey: FocusedValueKey {
    typealias Value = MarkdownEditorController
}

extension FocusedValues {
    var editorController: MarkdownEditorController? {
        get { self[EditorControllerKey.self] }
        set { self[EditorControllerKey.self] = newValue }
    }
}

/// A **Format** menu with keyboard shortcuts, shared by both apps. Acts on the
/// currently focused editor.
struct FormatCommands: Commands {
    @FocusedValue(\.editorController) private var controller

    var body: some Commands {
        CommandMenu("Format") {
            Group {
                Button("Bold") { controller?.wrap("**") }
                    .keyboardShortcut("b", modifiers: .command)
                Button("Italic") { controller?.wrap("*") }
                    .keyboardShortcut("i", modifiers: .command)
                Button("Strikethrough") { controller?.wrap("~~") }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                Button("Highlight") { controller?.wrap("==") }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
                Button("Code") { controller?.wrap("`") }
                    .keyboardShortcut("e", modifiers: .command)
            }
            Divider()
            Group {
                Button("Cycle Heading") { controller?.cycleHeading() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Bulleted List") { controller?.setLinePrefix("- ") }
                    .keyboardShortcut("8", modifiers: [.command, .shift])
                Button("Numbered List") { controller?.setLinePrefix("1. ") }
                    .keyboardShortcut("7", modifiers: [.command, .shift])
                Button("Checklist") { controller?.toggleTask() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Quote") { controller?.setLinePrefix("> ") }
                    .keyboardShortcut("'", modifiers: [.command, .shift])
            }
            Divider()
            Button("Insert Link") { controller?.insertLink() }
                .keyboardShortcut("k", modifiers: .command)
            Button("Insert Divider") { controller?.insertRule() }
            Button("Find & Replace…") { controller?.presentFind() }
                .keyboardShortcut("f", modifiers: [.command, .option])
        }
    }
}
