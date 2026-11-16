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
        get { min(max(double("longPressMs", 300), 150), 800) }
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
    /// 0 = follow the iPhone, 1 = light, 2 = dark
    var theme: Int {
        get { int("theme", 0) }
        set { d.set(newValue, forKey: "theme") }
    }
    /// Switch feel: 0 blue, 1 brown, 2 red, 3 silent, 4 custom
    var switchProfile: Int {
        get { int("switchProfile", 1) }
        set { d.set(newValue, forKey: "switchProfile") }
    }
    /// Custom profile sound, each 0…1
    var customVolume: Double {
        get { min(max(double("customVolume", 0.7), 0), 1) }
        set { d.set(newValue, forKey: "customVolume") }
    }
    var customPitch: Double {
        get { min(max(double("customPitch", 0.5), 0), 1) }
        set { d.set(newValue, forKey: "customPitch") }
    }
    var customClick: Double {
        get { min(max(double("customClick", 0.5), 0), 1) }
        set { d.set(newValue, forKey: "customClick") }
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
