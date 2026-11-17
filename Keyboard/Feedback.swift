//
//  Feedback.swift
//  "Tac Tile" sound engine: mechanical-switch profiles that pair a recorded
//  key sound with a matching vibration on every key press.
//
//  All sounds are recordings bundled in Keyboard/Sounds (from kbsim, MIT
//  licence, see ThirdParty/kbsim-LICENSE.md). Blue, Brown, Red and Tofu use a
//  fixed pack; Custom lets the user pick any of the twelve packs and their own
//  vibration strength. iOS only lets a keyboard make sound or vibrate when
//  "Allow Full Access" is on, and sounds follow the ring/silent switch.
//

import UIKit
import AudioToolbox

/// Which key was pressed, so space, return and delete can sound different.
enum KeySound: CaseIterable {
    case generic, space, enter, delete

    /// Part of the bundled file name, e.g. Cream_press_space.caf
    var fileKey: String {
        switch self {
        case .generic: return "generic"
        case .space:   return "space"
        case .enter:   return "enter"
        case .delete:  return "backspace"
        }
    }
}

/// A recorded sound pack: the name shown in settings and the file prefix in
/// Keyboard/Sounds (file names must be unique, so prefixes have no spaces).
struct SoundPack {
    let title: String
    let file: String

    /// The packs offered in Custom, in the order shown.
    static let all: [SoundPack] = [
        SoundPack(title: "Cream",      file: "Cream"),       // NovelKeys Cream
        SoundPack(title: "Panda",      file: "Panda"),       // Holy Panda
        SoundPack(title: "Alpaca",     file: "Alpaca"),      // Alpaca
        SoundPack(title: "Tea",        file: "Tea"),         // Turquoise Tealios
        SoundPack(title: "Black Ink",  file: "BlackInk"),    // Gateron Black Ink
        SoundPack(title: "Red Ink",    file: "RedInk"),      // Gateron Red Ink
        SoundPack(title: "Clacky",     file: "Clacky"),      // SKCM Blue Alps
        SoundPack(title: "Typewriter", file: "Typewriter"),  // Cherry MX Brown
        SoundPack(title: "Clicky",     file: "Clicky"),      // Cherry MX Blue
        SoundPack(title: "Spring",     file: "Spring"),      // Buckling Spring
        SoundPack(title: "Hollow",     file: "Hollow"),      // Cherry MX Black
        SoundPack(title: "Tofu",       file: "Tofu"),        // Topre
    ]

    static func named(_ file: String) -> SoundPack {
        all.first { $0.file == file } ?? all[0]
    }
}

enum SwitchProfile: Int, CaseIterable {
    case blue, brown, red, tofu, custom

    var title: String {
        switch self {
        case .blue:   return "Blue"
        case .brown:  return "Brown"
        case .red:    return "Red"
        case .tofu:   return "Tofu"
        case .custom: return "Custom"
        }
    }

    var summary: String {
        switch self {
        case .blue:   return "Loud, sharp click with a crisp vibration."
        case .brown:  return "Softer tactile bump."
        case .red:    return "Smooth, quiet, low thud."
        case .tofu:   return "Almost soundless, light vibration."
        case .custom: return "Pick any sound pack and your own vibration below."
        }
    }

    /// File prefix of the fixed pack. Custom uses the pack chosen in settings.
    var soundPack: String? {
        switch self {
        case .blue:   return "Clicky"
        case .brown:  return "Typewriter"
        case .red:    return "Cream"
        case .tofu:   return "Tofu"
        case .custom: return nil
        }
    }
}

final class SwitchFeedback {
    static let shared = SwitchFeedback()

    /// Recorded sounds for the current profile. Ordinary keys have several
    /// takes; one is picked at random each press so typing sounds natural.
    private var packSounds: [KeySound: [SystemSoundID]] = [:]

    private var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle?
    private var hapticIntensity: CGFloat = 1
    private var generators: [Int: UIImpactFeedbackGenerator] = [:]

    // MARK: Public

    /// Reloads the sounds for the chosen profile. Call after settings change.
    func reload(_ settings: KBSettings) {
        dispose()

        let profile = SwitchProfile(rawValue: settings.switchProfile) ?? .brown
        switch profile {
        case .blue:
            hapticStyle = .rigid
            hapticIntensity = 1.0
        case .brown:
            hapticStyle = .medium
            hapticIntensity = 0.8
        case .red:
            hapticStyle = .soft
            hapticIntensity = 0.7
        case .tofu:
            hapticStyle = .light
            hapticIntensity = 0.5
        case .custom:
            switch settings.tapHaptic {
            case 1:  hapticStyle = .light;  hapticIntensity = 0.7
            case 2:  hapticStyle = .medium; hapticIntensity = 0.9
            case 3:  hapticStyle = .heavy;  hapticIntensity = 1.0
            default: hapticStyle = nil
            }
        }

        loadPack(profile.soundPack ?? settings.customPack)
    }

    /// Call when a key goes down.
    func keyDown(_ key: KeySound = .generic) {
        let takes = packSounds[key] ?? packSounds[.generic] ?? []
        if let sound = takes.randomElement() { AudioServicesPlaySystemSound(sound) }

        if let style = hapticStyle {
            let generator = generators[style.rawValue] ?? UIImpactFeedbackGenerator(style: style)
            generators[style.rawValue] = generator
            generator.impactOccurred(intensity: hapticIntensity)
            generator.prepare()
        }
    }

    // MARK: Recorded sounds

    /// Loads <pack>_press_generic_0…4 plus space / enter / backspace.
    /// A missing special key falls back to the ordinary key sound.
    private func loadPack(_ pack: String) {
        let bundle = Bundle(for: SwitchFeedback.self)
        func sound(_ name: String) -> SystemSoundID? {
            guard let url = bundle.url(forResource: name, withExtension: "caf") else { return nil }
            var id: SystemSoundID = 0
            guard AudioServicesCreateSystemSoundID(url as CFURL, &id) == noErr, id != 0 else { return nil }
            return id
        }
        for key in KeySound.allCases {
            let base = "\(pack)_press_\(key.fileKey)"
            let takes = key == .generic
                ? (0..<5).compactMap { sound("\(base)_\($0)") }
                : [sound(base)].compactMap { $0 }
            if !takes.isEmpty { packSounds[key] = takes }
        }
    }

    private func dispose() {
        packSounds.values.joined().forEach { AudioServicesDisposeSystemSoundID($0) }
        packSounds.removeAll()
    }
}
