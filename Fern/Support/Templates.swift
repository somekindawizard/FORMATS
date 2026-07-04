import Foundation

/// A structured starting point for an entry — Fern's take on Day One templates.
struct WritingTemplate: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let body: String
    var collection: Collection = .journal
}

enum Templates {
    static let all: [WritingTemplate] = [
        WritingTemplate(title: "Gratitude", icon: "heart", body: """
        # Gratitude

        Three things I'm grateful for today:

        - \u{200B}
        - \u{200B}
        - \u{200B}

        Someone I appreciate, and why:

        \u{200B}
        """),

        WritingTemplate(title: "Daily review", icon: "sun.max", body: """
        # Daily review

        ## Today's high

        \u{200B}

        ## Today's challenge

        \u{200B}

        ## What I learned

        \u{200B}

        ## Tomorrow, one thing
        - [ ] \u{200B}
        """),

        WritingTemplate(title: "Morning pages", icon: "cloud.sun", body: """
        # Morning pages

        > Whatever's on your mind — keep going, don't edit.

        \u{200B}
        """),

        WritingTemplate(title: "Evening reflection", icon: "moon.stars", body: """
        # Evening reflection

        How did today feel?

        \u{200B}

        What am I carrying into tomorrow?

        \u{200B}
        """),

        WritingTemplate(title: "Dream log", icon: "sparkles", body: """
        # Dream log

        What I remember:

        \u{200B}

        How it felt:

        \u{200B}
        """),

        WritingTemplate(title: "Weekly review", icon: "calendar", body: """
        # Weekly review

        ## Wins

        \u{200B}

        ## What drained me

        \u{200B}

        ## Next week's focus
        - [ ] \u{200B}
        - [ ] \u{200B}
        """)
    ]
}
