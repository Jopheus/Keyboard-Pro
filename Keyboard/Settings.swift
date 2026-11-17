//
//  Settings.swift
//  Everything the user can change, saved on the phone inside the keyboard.
//

import UIKit

final class KBSettings {
    static let shared = KBSettings()
    private let d = UserDefaults.standard

    /// Default long-press symbol for each letter.
    static let defaultSymbols: [String: String] = [
        "q": "%", "w": "=", "e": "[", "r": "]", "t": "<",
        "y": ">", "u": "{", "i": "}", "o": ",", "p": ".",
        "a": "@", "s": "#", "d": "$", "f": "_", "g": "&",
        "h": "-", "j": "+", "k": "(", "l": ")",
        "z": "*", "x": "\"", "c": "'", "v": ":", "b": ";",
        "n": "!", "m": "?",
    ]

    /// Symbols offered when remapping a letter.
    static let symbolChoices: [String] =
        "%=[]<>{},.@#$_&-+()*\"':;!?/\\|~^`•°€£¥¢§©®™✓…÷×√π¿¡".map { String($0) }

    private func double(_ key: String, _ fallback: Double) -> Double {
        d.object(forKey: key) as? Double ?? fallback
    }
    private func bool(_ key: String, _ fallback: Bool) -> Bool {
        d.object(forKey: key) as? Bool ?? fallback
    }
    private func int(_ key: String, _ fallback: Int) -> Int {
        d.object(forKey: key) as? Int ?? fallback
    }

    // MARK: Pro (every user)

    /// How long a key must be held before the symbol is typed (milliseconds).
    var longPressMs: Double {
        get { min(max(double("longPressMs", 250), 150), 800) }
        set { d.set(newValue, forKey: "longPressMs") }
    }
    var suggestionsOn: Bool {
        get { bool("suggestionsOn", true) }
        set { d.set(newValue, forKey: "suggestionsOn") }
    }
    var autocorrectOn: Bool {
        get { bool("autocorrectOn", true) }
        set { d.set(newValue, forKey: "autocorrectOn") }
    }
    /// 0 = off, 1 = light, 2 = medium, 3 = strong
    var tapHaptic: Int {
        get { int("tapHaptic", 1) }
        set { d.set(newValue, forKey: "tapHaptic") }
    }
    var longHaptic: Int {
        get { int("longHaptic", 2) }
        set { d.set(newValue, forKey: "longHaptic") }
    }
    /// 0 = follow the iPhone, 1 = light, 2 = dark, 3 = glass (frosted, follows the iPhone)
    var theme: Int {
        get { int("theme", 0) }
        set { d.set(newValue, forKey: "theme") }
    }
    /// Tac Tile profile: 0 blue, 1 brown, 2 red, 3 tofu, 4 custom
    var switchProfile: Int {
        get { int("switchProfile", 1) }
        set { d.set(newValue, forKey: "switchProfile") }
    }
    /// Sound pack used by the Custom profile (file prefix, see SoundPack.all).
    var customPack: String {
        get { SoundPack.named(d.string(forKey: "customPack") ?? "Cream").file }
        set { d.set(newValue, forKey: "customPack") }
    }
    /// Offer a "Paste code" button when a copied number is on the clipboard.
    var pasteCodesOn: Bool {
        get { bool("pasteCodesOn", true) }
        set { d.set(newValue, forKey: "pasteCodesOn") }
    }
    /// The keys either side of the space bar: what they type, and whether they show.
    var leftKey: String {
        get { nonEmpty(d.string(forKey: "leftKey")) ?? Self.defaultLeftKey }
        set { d.set(newValue, forKey: "leftKey") }
    }
    var rightKey: String {
        get { nonEmpty(d.string(forKey: "rightKey")) ?? Self.defaultRightKey }
        set { d.set(newValue, forKey: "rightKey") }
    }
    var leftKeyShown: Bool {
        get { bool("leftKeyShown", true) }
        set { d.set(newValue, forKey: "leftKeyShown") }
    }
    var rightKeyShown: Bool {
        get { bool("rightKeyShown", true) }
        set { d.set(newValue, forKey: "rightKeyShown") }
    }
    /// Third shortcut key: at the end of the A–L row.
    var rowKey: String {
        get { nonEmpty(d.string(forKey: "rowKey")) ?? Self.defaultRowKey }
        set { d.set(newValue, forKey: "rowKey") }
    }
    var rowKeyShown: Bool {
        get { bool("rowKeyShown", true) }
        set { d.set(newValue, forKey: "rowKeyShown") }
    }
    static let defaultLeftKey = ","
    static let defaultRightKey = "."
    /// Special value: the key pastes the copied text instead of typing a character.
    static let pasteAction = "{paste}"
    static let defaultRowKey = KBSettings.pasteAction

    /// How a shortcut key's value is shown in settings.
    static func displayName(_ value: String) -> String {
        value == pasteAction ? "Paste" : value
    }

    /// The three shortcut keys by number: 0 left of space, 1 right of space,
    /// 2 end of the A–L row.
    static let shortcutNames = ["Left of space", "Right of space", "End of A–L row"]
    static let shortcutDefaults = [KBSettings.defaultLeftKey, KBSettings.defaultRightKey, KBSettings.defaultRowKey]

    func shortcutKey(_ index: Int) -> String {
        switch index {
        case 0:  return leftKey
        case 1:  return rightKey
        default: return rowKey
        }
    }
    func setShortcutKey(_ index: Int, _ value: String) {
        switch index {
        case 0:  leftKey = value
        case 1:  rightKey = value
        default: rowKey = value
        }
    }
    func shortcutShown(_ index: Int) -> Bool {
        switch index {
        case 0:  return leftKeyShown
        case 1:  return rightKeyShown
        default: return rowKeyShown
        }
    }
    func setShortcutShown(_ index: Int, _ value: Bool) {
        switch index {
        case 0:  leftKeyShown = value
        case 1:  rightKeyShown = value
        default: rowKeyShown = value
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        return value
    }

    var customWords: [String] {
        get { d.stringArray(forKey: "customWords") ?? [] }
        set { d.set(newValue, forKey: "customWords") }
    }

    // MARK: Max (paid users)

    /// Test switch. A real purchase would set this instead.
    var maxUnlocked: Bool {
        get { bool("maxUnlocked", false) }
        set { d.set(newValue, forKey: "maxUnlocked") }
    }
    /// Only the letters the user changed.
    var symbolMap: [String: String] {
        get { (d.dictionary(forKey: "symbolMap") as? [String: String]) ?? [:] }
        set { d.set(newValue, forKey: "symbolMap") }
    }
    var historyOn: Bool {
        get { bool("historyOn", true) }
        set { d.set(newValue, forKey: "historyOn") }
    }
    /// 0.85 … 1.25
    var heightScale: Double {
        get { min(max(double("heightScale", 1.0), 0.85), 1.25) }
        set { d.set(newValue, forKey: "heightScale") }
    }

    // MARK: What the keyboard actually uses (Max features fall back when locked)

    var effectiveSymbols: [String: String] {
        guard maxUnlocked else { return Self.defaultSymbols }
        return Self.defaultSymbols.merging(symbolMap) { _, custom in custom }
    }
    var effectiveHeightScale: CGFloat {
        maxUnlocked ? CGFloat(heightScale) : 1
    }
    var effectiveHistory: Bool {
        maxUnlocked && historyOn
    }
}

/// Vibration feedback. iOS only allows this when "Allow Full Access" is on.
enum Haptics {
    private static let generators: [UIImpactFeedbackGenerator] = [
        UIImpactFeedbackGenerator(style: .light),
        UIImpactFeedbackGenerator(style: .medium),
        UIImpactFeedbackGenerator(style: .heavy),
    ]

    static func play(_ level: Int) {
        guard level >= 1, level <= generators.count else { return }
        let generator = generators[level - 1]
        generator.impactOccurred()
        generator.prepare()
    }
}
