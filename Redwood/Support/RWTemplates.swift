import Foundation

/// Starter documents for common long-form building blocks. Chosen from the +
/// menu; they prefill the body (and sometimes a synopsis).
struct RWTemplate: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let synopsis: String
    let body: String
}

enum RWTemplates {
    static let all: [RWTemplate] = [
        RWTemplate(
            name: "Chapter", symbol: "book.closed",
            synopsis: "",
            body: "# Chapter\n\n"),
        RWTemplate(
            name: "Scene", symbol: "film",
            synopsis: "POV · Setting · What changes",
            body: ""),
        RWTemplate(
            name: "Character sheet", symbol: "person.crop.square",
            synopsis: "Character profile",
            body: """
            # Name

            **Role:** \u{00A0}
            **Age:** \u{00A0}
            **Wants:** \u{00A0}
            **Fears:** \u{00A0}
            **Voice:** \u{00A0}

            ## Backstory

            ## Arc

            """),
        RWTemplate(
            name: "Research note", symbol: "doc.text.magnifyingglass",
            synopsis: "Source note",
            body: """
            ## Source

            ## Summary

            ## Key quotes

            > \u{00A0}

            ## How it's used

            """),
        RWTemplate(
            name: "Beat outline", symbol: "list.number",
            synopsis: "Beats",
            body: "1. \u{00A0}\n2. \u{00A0}\n3. \u{00A0}\n4. \u{00A0}\n5. \u{00A0}\n")
    ]
}
