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
    /// Vibration when typing: 0 off, 1 light, 2 medium, 3 strong, 4 soft, 5 crisp
    /// (see TapHaptic). Long press uses 0…3 only.
    var tapHaptic: Int {
        get { int("tapHaptic", 6) }        // Apple preset
        set { d.set(newValue, forKey: "tapHaptic") }
    }
    var longHaptic: Int {
        get { int("longHaptic", 2) }
        set { d.set(newValue, forKey: "longHaptic") }
    }
    /// 0 = follow the iPhone, 1 = light, 2 = dark, 3 = glass (frosted, follows the iPhone)
    var theme: Int {
        get { int("theme", 3) }
        set { d.set(newValue, forKey: "theme") }
    }
    /// Tac Tile sound pack (file prefix, see SoundPack.all). Default: the Apple preset.
    var soundPack: String {
        get { SoundPack.named(d.string(forKey: "soundPack") ?? "Apple").file }
        set { d.set(newValue, forKey: "soundPack") }
    }
    static let themeNames = ["Auto", "Light", "Dark", "Glass"]

    /// Puts every setting back to its default. My words and the Max unlock
    /// are kept: they are the user's data and purchase, not preferences.
    func resetAll() {
        for key in ["longPressMs", "suggestionsOn", "autocorrectOn", "tapHaptic", "longHaptic",
                    "theme", "soundPack", "pasteCodesOn", "leftKey", "rightKey", "rowKey",
                    "leftKeyShown", "rightKeyShown", "rowKeyShown", "symbolMap", "historyOn",
                    "heightScale", "showHints", "oneHanded", "smartPunctuationOn", "showNumberRow", "soundVolume",
                    "emojiSuggestionsOn", "calculatorOn"] {
            d.removeObject(forKey: key)
        }
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
    /// Third Action Key: at the right end of the suggestion bar.
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
    /// 2 right end of the suggestion bar.
    static let shortcutNames = ["Left of space", "Right of space", "Suggestion bar"]
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

    /// Curly quotes and apostrophes, and two hyphens become a dash.
    var smartPunctuationOn: Bool {
        get { bool("smartPunctuationOn", true) }
        set { d.set(newValue, forKey: "smartPunctuationOn") }
    }
    /// Offer an emoji in the suggestion bar for the word being typed.
    var emojiSuggestionsOn: Bool {
        get { bool("emojiSuggestionsOn", true) }
        set { d.set(newValue, forKey: "emojiSuggestionsOn") }
    }
    /// Show the answer to a typed sum ("4+5" -> "= 9") in the suggestion bar.
    var calculatorOn: Bool {
        get { bool("calculatorOn", true) }
        set { d.set(newValue, forKey: "calculatorOn") }
    }
    /// Endings offered when holding the full stop in web and email fields.
    static let webDomains = [".com", ".net", ".org", ".edu", ".my", ".com.my", ".co"]

    /// Small long-press symbol shown in the corner of each letter key.
    /// The 1–0 row above the letters. When hidden, hold q–p for 1–0.
    /// Tac Tile key sound volume, 0…1. The Apple preset plays at the
    /// iPhone's own volume, so only 0 (off) changes it.
    var soundVolume: Double {
        get { min(max(double("soundVolume", 1.0), 0), 1) }
        set { d.set(newValue, forKey: "soundVolume") }
    }
    var showNumberRow: Bool {
        get { bool("showNumberRow", true) }
        set { d.set(newValue, forKey: "showNumberRow") }
    }
    var showHints: Bool {
        get { bool("showHints", true) }
        set { d.set(newValue, forKey: "showHints") }
    }
    /// One-handed keyboard: 0 off, 1 pushed to the left, 2 pushed to the right.
    var oneHanded: Int {
        get { min(max(int("oneHanded", 0), 0), 2) }
        set { d.set(newValue, forKey: "oneHanded") }
    }
    /// Most recently used emoji first.
    var recentEmoji: [String] {
        get {
            // The old WeChat codes such as "[Facepalm]" were removed: drop them once.
            if !bool("wechatRemoved", false) {
                d.set(true, forKey: "wechatRemoved")
                let kept = (d.stringArray(forKey: "recentEmoji") ?? [])
                    .filter { !($0.hasPrefix("[") && $0.hasSuffix("]") && $0.count > 2) }
                d.set(kept, forKey: "recentEmoji")
            }
            return d.stringArray(forKey: "recentEmoji") ?? []
        }
        set { d.set(newValue, forKey: "recentEmoji") }
    }

    /// Emoji combos the user made, newest first.
    var myCombos: [String] {
        get { d.stringArray(forKey: "myCombos") ?? [] }
        set { d.set(newValue, forKey: "myCombos") }
    }
    func addCombo(_ combo: String) {
        let text = combo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var list = myCombos.filter { $0 != text }
        list.insert(text, at: 0)
        myCombos = Array(list.prefix(100))
    }
    func removeCombo(_ combo: String) {
        myCombos = myCombos.filter { $0 != combo }
    }
    func addRecentEmoji(_ emoji: String) {
        var list = recentEmoji.filter { $0 != emoji }
        list.insert(emoji, at: 0)
        recentEmoji = Array(list.prefix(32))
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
    /// The Tac Tile sound and vibration in use. Without Max only the four
    /// presets are available, so any other mix falls back to the Apple preset.
    var effectiveFeel: (pack: String, haptic: Int) {
        let pack = soundPack
        let haptic = tapHaptic
        if maxUnlocked || TacPreset.all.contains(where: { $0.pack == pack && $0.haptic == haptic }) {
            return (pack, haptic)
        }
        let fallback = TacPreset.all[0]           // Apple
        return (fallback.pack, fallback.haptic)
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
