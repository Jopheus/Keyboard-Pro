//
//  Suggestions.swift
//  Word completion, spelling correction and learning from typing history.
//  Everything stays on the phone; nothing is sent anywhere.
//

import UIKit

struct Suggestion {
    let title: String     // what the bar shows
    let text: String      // the word itself
    let isAdd: Bool       // true = "add this word to my dictionary"
    var isPaste = false   // true = "paste the code I copied"
}

final class SuggestionEngine {
    private struct Store: Codable {
        var words: [String: Int] = [:]              // word -> times typed
        var next: [String: [String: Int]] = [:]     // word -> words typed after it
    }

    private let checker = UITextChecker()
    private let language: String
    private var store = Store()
    private var unsavedChanges = 0

    private let fileURL: URL? = {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("typing-history.json")
    }()

    init() {
        let available = UITextChecker.availableLanguages
        language = available.contains("en_US") ? "en_US"
            : (available.first { $0.hasPrefix("en") } ?? available.first ?? "en_US")
        if let url = fileURL, let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(Store.self, from: data) {
            store = saved
        }
    }

    // MARK: Spelling

    private func isMisspelled(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: (word as NSString).length)
        let found = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0,
                                                  wrap: false, language: language)
        return found.location != NSNotFound
    }

    /// True for dictionary words, the user's custom words and words they type often.
    func isKnown(_ word: String, custom: [String]) -> Bool {
        let lower = word.lowercased()
        if custom.contains(where: { $0.lowercased() == lower }) { return true }
        if (store.words[lower] ?? 0) >= 3 { return true }
        return !isMisspelled(word)
    }

    /// The corrected spelling, or nil when the word should be left alone.
    func correction(for word: String, custom: [String]) -> String? {
        guard word.count >= 2, word.allSatisfy({ $0.isLetter }) else { return nil }
        // Leave names and acronyms (capitals after the first letter) alone.
        guard !word.dropFirst().contains(where: { $0.isUppercase }) else { return nil }
        if isKnown(word, custom: custom) { return nil }

        let range = NSRange(location: 0, length: (word as NSString).length)
        guard let guess = checker.guesses(forWordRange: range, in: word, language: language)?.first,
              !guess.contains(" ") else { return nil }
        return matchCase(guess, to: word)
    }

    // MARK: Suggestions

    /// Up to three words for the suggestion bar.
    /// `prefix` is the word being typed ("" right after a space).
    func suggestions(prefix: String, previous: String?, custom: [String],
                     useHistory: Bool) -> [String] {
        var result: [String] = []
        let lower = prefix.lowercased()

        func add(_ word: String) {
            let w = word.lowercased()
            guard result.count < 3, w != lower,
                  !result.contains(where: { $0.lowercased() == w }) else { return }
            result.append(matchCase(word, to: prefix))
        }

        // After a space: guess the next word from history.
        if prefix.isEmpty {
            guard useHistory, let prev = previous?.lowercased(),
                  let followers = store.next[prev] else { return [] }
            followers.sorted { $0.value > $1.value }.prefix(3).forEach { add($0.key) }
            return result
        }

        for word in custom where word.lowercased().hasPrefix(lower) { add(word) }

        if useHistory {
            store.words
                .filter { $0.value >= 2 && $0.key.hasPrefix(lower) }
                .sorted { $0.value > $1.value }
                .prefix(3)
                .forEach { add($0.key) }
        }

        let range = NSRange(location: 0, length: (prefix as NSString).length)
        if result.count < 3,
           let completions = checker.completions(forPartialWordRange: range, in: prefix,
                                                 language: language) {
            completions.prefix(3).forEach { add($0) }
        }
        if result.count < 3, prefix.count >= 2, isMisspelled(prefix),
           let guesses = checker.guesses(forWordRange: range, in: prefix, language: language) {
            guesses.prefix(3).forEach { add($0) }
        }
        return result
    }

    private func matchCase(_ word: String, to typed: String) -> String {
        guard typed.first?.isUppercase == true, let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }

    // MARK: Learning

    func learn(_ word: String, previous: String?) {
        let w = word.lowercased()
        guard w.count >= 2, w.count <= 24, w.allSatisfy({ $0.isLetter }) else { return }
        store.words[w, default: 0] += 1
        if let prev = previous?.lowercased(), prev.allSatisfy({ $0.isLetter }), !prev.isEmpty {
            store.next[prev, default: [:]][w, default: 0] += 1
        }
        // Keep the history small: forget words typed only once when it grows.
        if store.words.count > 4000 {
            store.words = store.words.filter { $0.value > 1 }
        }
        if store.next.count > 2000 {
            store.next = store.next.filter { $0.value.values.reduce(0, +) > 1 }
        }
        unsavedChanges += 1
        if unsavedChanges >= 40 { save() }
    }

    func save() {
        guard unsavedChanges > 0, let url = fileURL,
              let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: url, options: .atomic)
        unsavedChanges = 0
    }

    func clearHistory() {
        store = Store()
        unsavedChanges = 0
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
    }
}
