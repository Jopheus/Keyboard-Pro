//
//  Feedback.swift
//  "Tac Tile" sound engine: pairs a recorded key sound with a vibration on
//  every key press.
//
//  Blue, Brown, Red and Tofu are presets that set a sound pack and a vibration
//  together; they are free. Picking any pack or vibration separately is Max. All sounds are recordings
//  bundled in Keyboard/Sounds (from kbsim, MIT licence, see
//  ThirdParty/kbsim-LICENSE.md). iOS only lets a keyboard make sound or
//  vibrate when "Allow Full Access" is on, and sounds follow the ring/silent
//  switch.
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

    /// Every pack, in the order shown in settings.
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

/// Vibration strength for ordinary typing. The numbers are what is saved.
enum TapHaptic {
    /// (saved value, name) in the order shown in settings.
    static let choices: [(value: Int, title: String)] = [
        (0, "Off"), (4, "Soft"), (1, "Light"), (2, "Medium"), (3, "Strong"), (5, "Crisp"),
    ]

    static func style(_ value: Int) -> (UIImpactFeedbackGenerator.FeedbackStyle, CGFloat)? {
        switch value {
        case 1:  return (.light, 0.6)
        case 2:  return (.medium, 0.85)
        case 3:  return (.heavy, 1.0)
        case 4:  return (.soft, 0.7)
        case 5:  return (.rigid, 1.0)
        default: return nil
        }
    }
}

/// A preset: one tap sets both the sound pack and the vibration.
struct TacPreset {
    let title: String
    let summary: String
    let pack: String        // SoundPack.file
    let haptic: Int         // TapHaptic value

    static let all: [TacPreset] = [
        TacPreset(title: "Blue", summary: "Loud, sharp click with a crisp vibration.",
                  pack: "Clicky", haptic: 5),
        TacPreset(title: "Brown", summary: "Softer tactile bump.",
                  pack: "Typewriter", haptic: 2),
        TacPreset(title: "Red", summary: "Smooth, quiet, low thud.",
                  pack: "Cream", haptic: 4),
        TacPreset(title: "Tofu", summary: "Almost soundless, light vibration.",
                  pack: "Tofu", haptic: 1),
    ]

    /// The preset matching the current sound and vibration, if any.
    static func current(_ settings: KBSettings) -> TacPreset? {
        let feel = settings.effectiveFeel
        return all.first { $0.pack == feel.pack && $0.haptic == feel.haptic }
    }
}

final class SwitchFeedback {
    static let shared = SwitchFeedback()

    /// Recorded sounds for the current pack. Ordinary keys have several
    /// takes; one is picked at random each press so typing sounds natural.
    private var packSounds: [KeySound: [SystemSoundID]] = [:]

    private var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle?
    private var hapticIntensity: CGFloat = 1
    private var generators: [Int: UIImpactFeedbackGenerator] = [:]

    // MARK: Public

    /// Reloads the chosen sound and vibration. Call after settings change.
    func reload(_ settings: KBSettings) {
        dispose()
        let feel = settings.effectiveFeel       // presets only without Max
        if let (style, intensity) = TapHaptic.style(feel.haptic) {
            hapticStyle = style
            hapticIntensity = intensity
        } else {
            hapticStyle = nil
        }
        loadPack(feel.pack)
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
