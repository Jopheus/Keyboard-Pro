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
import AVFoundation

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
        SoundPack(title: "Apple",      file: "Apple"),       // the iPhone's own key clicks
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
        (6, "Apple"), (0, "Off"), (4, "Soft"), (1, "Light"), (2, "Medium"), (3, "Strong"),
        (5, "Crisp"),
    ]

    static func style(_ value: Int) -> (UIImpactFeedbackGenerator.FeedbackStyle, CGFloat)? {
        switch value {
        case 1:  return (.light, 0.6)
        case 2:  return (.medium, 0.85)
        case 3:  return (.heavy, 1.0)
        case 4:  return (.soft, 0.7)
        case 5:  return (.rigid, 1.0)
        case 6:  return (.light, 0.75)      // close to the iPhone keyboard's tap
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
        TacPreset(title: "Apple", summary: "The iPhone keyboard's own click and light tap.",
                  pack: "Apple", haptic: 6),
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

    /// Recorded sounds for the current pack: for each key, its takes (one is
    /// picked at random each press so typing sounds natural), and for each
    /// take a few copies so fast typing can overlap without cutting off.
    private var players: [KeySound: [[AVAudioPlayer]]] = [:]
    /// The Apple preset uses iOS's own key sounds, which play at system volume.
    private var systemSounds: [KeySound: SystemSoundID] = [:]
    private var volume: Float = 1

    private var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle?
    private var hapticIntensity: CGFloat = 1
    private var generators: [Int: UIImpactFeedbackGenerator] = [:]
    private var sessionReady = false

    // Adaptive Tac Tile (see Settings.swift): small changes to each press.
    private var variation = true
    private var fastSoften = false
    private var autoQuiet = true
    private var nightQuiet = false
    private var nightFrom = 22
    private var nightTo = 7
    private var lastPress: TimeInterval = 0
    private var nightCheckedAt: TimeInterval = 0
    private var nightNow = false

    /// Set by the keyboard: true while typing in a password field.
    var secureField = false

    // MARK: Public

    /// Reloads the chosen sound, volume and vibration. Call after settings change.
    func reload(_ settings: KBSettings) {
        dispose()
        volume = Float(settings.soundVolume)
        variation = settings.adaptiveVariation
        fastSoften = settings.effectiveAdaptiveFast
        autoQuiet = settings.adaptiveQuiet
        nightQuiet = settings.adaptiveNight
        nightFrom = settings.nightFrom
        nightTo = settings.nightTo
        nightCheckedAt = 0
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
        // How this press is adjusted: loudness and vibration strength (1 = as chosen).
        var loudness: Float = 1
        var strength: CGFloat = 1
        var rate: Float = 1
        var silent = false

        let now = ProcessInfo.processInfo.systemUptime
        let gap = now - lastPress
        lastPress = now

        // Auto-quiet: no sound in password fields, softer at night, lighter vibration in Low Power Mode.
        if autoQuiet {
            if secureField { silent = true; strength *= 0.6 }
            if ProcessInfo.processInfo.isLowPowerModeEnabled { strength *= 0.6 }
        }
        if nightQuiet, isNight(now) { loudness *= 0.4; strength *= 0.7 }

        // Fast typing: quicker than ~0.18 s between keys gets softer, down to 60%.
        if fastSoften, gap < 0.18 {
            let t = Float(max(gap, 0.06) - 0.06) / 0.12          // 0 (very fast) … 1
            let soft = 0.6 + 0.4 * t
            loudness *= soft
            strength *= CGFloat(soft)
        }

        // Variation: no two presses are exactly the same.
        if variation {
            loudness *= Float.random(in: 0.92...1.08)
            rate = Float.random(in: 0.97...1.03)
            strength *= CGFloat.random(in: 0.9...1.1)
        }

        if volume > 0.001, !silent {
            if let sound = systemSounds[key] ?? systemSounds[.generic] {
                AudioServicesPlaySystemSound(sound)
            } else if let takes = players[key] ?? players[.generic],
                      let copies = takes.randomElement(), let first = copies.first {
                let player = copies.first(where: { !$0.isPlaying }) ?? first
                player.currentTime = 0
                player.volume = min(volume * loudness, 1)
                if player.enableRate { player.rate = rate }
                player.play()
            }
        }

        if let style = hapticStyle {
            let generator = generators[style.rawValue] ?? UIImpactFeedbackGenerator(style: style)
            generators[style.rawValue] = generator
            generator.impactOccurred(intensity: min(max(hapticIntensity * strength, 0.1), 1))
            generator.prepare()
        }
    }

    /// True inside the chosen night hours. Checked at most once a minute.
    private func isNight(_ now: TimeInterval) -> Bool {
        if now - nightCheckedAt > 60 || nightCheckedAt == 0 {
            nightCheckedAt = now
            let hour = Calendar.current.component(.hour, from: Date())
            if nightFrom == nightTo {
                nightNow = false
            } else if nightFrom < nightTo {
                nightNow = hour >= nightFrom && hour < nightTo
            } else {
                nightNow = hour >= nightFrom || hour < nightTo      // past midnight
            }
        }
        return nightNow
    }

    // MARK: Sounds

    /// Loads <pack>_press_generic_0…4 plus space / enter / backspace.
    /// A missing special key falls back to the ordinary key sound.
    private func loadPack(_ pack: String) {
        // Apple: the sounds iOS itself plays for key presses (no files needed).
        if pack == "Apple" {
            systemSounds = [.generic: 1104, .delete: 1155, .space: 1156, .enter: 1156]
            return
        }
        prepareSession()
        let bundle = Bundle(for: SwitchFeedback.self)
        func take(_ name: String) -> [AVAudioPlayer]? {
            guard let url = bundle.url(forResource: name, withExtension: "caf") else { return nil }
            let copies = (0..<3).compactMap { _ -> AVAudioPlayer? in
                guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                player.enableRate = true        // lets each press vary slightly in pitch
                player.prepareToPlay()
                return player
            }
            return copies.isEmpty ? nil : copies
        }
        for key in KeySound.allCases {
            let base = "\(pack)_press_\(key.fileKey)"
            let takes = key == .generic
                ? (0..<5).compactMap { take("\(base)_\($0)") }
                : [take(base)].compactMap { $0 }
            if !takes.isEmpty { players[key] = takes }
        }
    }

    /// Key sounds mix with music and follow the ring/silent switch, like the
    /// system keyboard's clicks, instead of pausing whatever is playing.
    private func prepareSession() {
        guard !sessionReady else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        sessionReady = true
    }

    private func dispose() {
        players.values.joined().joined().forEach { $0.stop() }
        players.removeAll()
        systemSounds.removeAll()
    }
}
