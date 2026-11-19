//
//  EmailMemory.swift
//  Keyboard Pro
//
//  Remembers email addresses the user has typed, ranked by how often they are used.
//  Stored only on the phone (shared settings store). Never sent anywhere.
//

import Foundation

enum EmailMemory {
    struct Entry: Codable {
        var email: String        // always lower case
        var count: Int           // times used
        var last: Double         // last time used (seconds since 1970)
    }

    private static let limit = 200

    private static func load() -> [Entry] {
        guard let data = KBSettings.shared.emailData,
              let list = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return list
    }

    private static func save(_ list: [Entry]) {
        KBSettings.shared.emailData = try? JSONEncoder().encode(list)
    }

    /// Most used first; ties go to the most recent.
    static func ranked() -> [Entry] {
        load().sorted { $0.count != $1.count ? $0.count > $1.count : $0.last > $1.last }
    }

    /// Adds one use of this address.
    static func record(_ email: String) {
        let key = email.lowercased()
        var list = load()
        let now = Date().timeIntervalSince1970
        if let i = list.firstIndex(where: { $0.email == key }) {
            list[i].count += 1
            list[i].last = now
        } else {
            list.append(Entry(email: key, count: 1, last: now))
        }
        if list.count > limit {
            // Drop the least used, oldest ones.
            list.sort { $0.count != $1.count ? $0.count > $1.count : $0.last > $1.last }
            list = Array(list.prefix(limit))
        }
        save(list)
    }

    static func remove(_ email: String) {
        save(load().filter { $0.email != email.lowercased() })
    }

    static func clear() {
        KBSettings.shared.emailData = nil
    }

    /// Saved addresses that start with what was typed (all of them when nothing was typed).
    static func matching(prefix: String, limit: Int) -> [String] {
        let p = prefix.lowercased()
        return ranked().map { $0.email }
            .filter { $0 != p && (p.isEmpty || $0.hasPrefix(p)) }
            .prefix(limit).map { $0 }
    }

    /// The email address in a typed word, or nil. Ignores brackets and
    /// punctuation around it: "(john@mail.com)," -> "john@mail.com".
    static func extract(fromToken token: String) -> String? {
        let edge = CharacterSet(charactersIn: ".,;:!?()<>[]{}\"'")
        let trimmed = token.trimmingCharacters(in: edge)
        guard trimmed.count <= 254, trimmed.contains("@") else { return nil }
        let pattern = "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9\\-]+(\\.[A-Za-z0-9\\-]+)*\\.[A-Za-z]{2,}$"
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return trimmed.lowercased()
    }
}
