import Foundation

/// A small thesaurus the writing strip leans on. Synonyms come from Datamuse
/// (free, no key) so the data never has to ship in the app. Calls are best
/// effort — offline or on failure it simply returns nothing, and the strip
/// quietly hides.
enum Thesaurus {
    private struct Word: Decodable { let word: String }

    static func synonyms(for raw: String, limit: Int = 12) async -> [String] {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard word.count >= 3,
              word.allSatisfy({ $0.isLetter || $0 == "-" }),
              let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.datamuse.com/words?rel_syn=\(encoded)&max=\(limit)")
        else { return [] }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let words = try? JSONDecoder().decode([Word].self, from: data)
        else { return [] }

        // Drop the word itself and any multi-word phrases — the strip swaps a
        // single token in place, so single words read cleanest.
        return words.map(\.word)
            .filter { !$0.contains(" ") && $0.lowercased() != word }
    }
}
