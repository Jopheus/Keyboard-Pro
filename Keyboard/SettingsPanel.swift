//
//  SettingsPanel.swift
//  The settings screen shown inside the keyboard (gear button).
//

import UIKit

final class SettingsPanel: UIView {
    var onDone: (() -> Void)?
    var onHeightChanged: (() -> Void)?
    var onClearHistory: (() -> Void)?
    var onThemeChanged: (() -> Void)?
    var onFeedbackChanged: (() -> Void)?

    private enum Screen { case main, words, remap, pick(String) }

    private let settings: KBSettings
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var screen = Screen.main
    private var fullAccess = false

    init(settings: KBSettings) {
        self.settings = settings
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -10),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -20),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Call each time the panel is opened.
    func reload(hasFullAccess: Bool) {
        fullAccess = hasFullAccess
        screen = .main
        render()
    }

    private func show(_ next: Screen) {
        screen = next
        render()
    }

    private func render(keepScroll: Bool = false) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if !keepScroll { scroll.setContentOffset(.zero, animated: false) }
        switch screen {
        case .main:             renderMain()
        case .words:            renderWords()
        case .remap:            renderRemap()
        case .pick(let letter): renderPick(letter)
        }
    }

    // MARK: Screens

    private func renderMain() {
        add(titleBar("Keyboard settings", button: "Done") { [weak self] in self?.onDone?() })

        add(header("Pro"))

        add(label("Theme"))
        add(choice(["Same as iPhone", "Light", "Dark"], settings.theme) { [weak self] in
            self?.settings.theme = $0
            self?.onThemeChanged?()
        })

        add(slider(value: Float(settings.longPressMs), min: 150, max: 800,
                   title: { "Long press duration: \(Int(($0 / 10).rounded() * 10)) ms" },
                   changed: { [weak self] in
                       self?.settings.longPressMs = Double(($0 / 10).rounded() * 10)
                   }))

        add(row("Word suggestions", toggle(settings.suggestionsOn) { [weak self] in
            self?.settings.suggestionsOn = $0
        }))
        add(row("Auto-correct spelling", toggle(settings.autocorrectOn) { [weak self] in
            self?.settings.autocorrectOn = $0
        }))

        // Tac Tile: mechanical switch sound + vibration
        if !fullAccess {
            add(note("Sound and vibration need Full Access. Turn it on in Settings → General → "
                     + "Keyboard → Keyboards → Keyboard Pro → Allow Full Access."))
        }
        let profile = SwitchProfile(rawValue: settings.switchProfile) ?? .brown
        add(label("Switch feel (Tac Tile)"))
        add(choice(SwitchProfile.allCases.map { $0.title }, profile.rawValue) { [weak self] in
            self?.settings.switchProfile = $0
            self?.onFeedbackChanged?()
            self?.render(keepScroll: true)
        })
        add(note(profile.summary))

        if profile == .custom {
            let refresh: () -> Void = { [weak self] in self?.onFeedbackChanged?() }
            add(slider(value: Float(settings.customVolume * 100), min: 0, max: 100,
                       title: { "Sound volume: \(Int($0.rounded()))%" },
                       changed: { [weak self] in self?.settings.customVolume = Double($0) / 100 },
                       ended: refresh))
            add(slider(value: Float(settings.customPitch * 100), min: 0, max: 100,
                       title: { "Pitch (low to high): \(Int($0.rounded()))%" },
                       changed: { [weak self] in self?.settings.customPitch = Double($0) / 100 },
                       ended: refresh))
            add(slider(value: Float(settings.customClick * 100), min: 0, max: 100,
                       title: { "Clickiness (smooth to clicky): \(Int($0.rounded()))%" },
                       changed: { [weak self] in self?.settings.customClick = Double($0) / 100 },
                       ended: refresh))
            add(label("Vibration when typing"))
            add(levels(settings.tapHaptic) { [weak self] in
                self?.settings.tapHaptic = $0
                self?.onFeedbackChanged?()
            })
        }

        add(label("Vibration on long press"))
        add(levels(settings.longHaptic) { [weak self] in self?.settings.longHaptic = $0 })

        add(row("My words (\(settings.customWords.count))",
                button("Manage") { [weak self] in self?.show(.words) }))

        add(header("Max"))
        let isMax = settings.maxUnlocked
        add(row("Max unlocked (test switch)", toggle(isMax) { [weak self] in
            self?.settings.maxUnlocked = $0
            self?.onHeightChanged?()
            self?.render(keepScroll: true)
        }))

        let remap = button("Edit") { [weak self] in self?.show(.remap) }
        remap.isEnabled = isMax
        add(row("Remap long-press symbols", remap))

        add(row("Learn from my typing", toggle(settings.historyOn, enabled: isMax) { [weak self] in
            self?.settings.historyOn = $0
        }))
        let clear = button("Clear") { [weak self] in self?.onClearHistory?() }
        clear.isEnabled = isMax
        add(row("Typing history", clear))

        add(slider(value: Float(settings.heightScale * 100), min: 85, max: 125, enabled: isMax,
                   title: { "Keyboard height: \(Int($0.rounded()))%" },
                   changed: { [weak self] in
                       self?.settings.heightScale = Double($0.rounded()) / 100
                   },
                   ended: { [weak self] in self?.onHeightChanged?() }))
    }

    private func renderWords() {
        add(titleBar("My words", button: "Back") { [weak self] in self?.show(.main) })
        add(note("To add a word: type it in any app, then tap “+ word” in the bar above the keys."))

        let words = settings.customWords
        if words.isEmpty { add(label("No words yet.")) }
        for word in words {
            add(row(word, button("Remove") { [weak self] in
                guard let self = self else { return }
                self.settings.customWords = self.settings.customWords.filter { $0 != word }
                self.render()
            }))
        }
    }

    private func renderRemap() {
        add(titleBar("Remap symbols", button: "Back") { [weak self] in self?.show(.main) })
        add(note("Tap a letter to choose its long-press symbol."))

        let symbols = settings.effectiveSymbols
        for letters in ["qwertyuiop", "asdfghjkl", "zxcvbnm"] {
            add(grid(letters.map { String($0) }.map { letter in
                tile("\(letter) \(symbols[letter] ?? "")") { [weak self] in self?.show(.pick(letter)) }
            }))
        }
        add(button("Reset all to default") { [weak self] in
            self?.settings.symbolMap = [:]
            self?.render()
        })
    }

    private func renderPick(_ letter: String) {
        add(titleBar("Symbol for “\(letter)”", button: "Back") { [weak self] in self?.show(.remap) })

        let choices = KBSettings.symbolChoices
        var index = 0
        while index < choices.count {
            var tiles: [UIView] = choices[index..<min(index + 8, choices.count)].map { symbol in
                tile(symbol) { [weak self] in
                    guard let self = self else { return }
                    var map = self.settings.symbolMap
                    map[letter] = symbol
                    self.settings.symbolMap = map
                    self.show(.remap)
                }
            }
            while tiles.count < 8 { tiles.append(UIView()) }    // keep the last row aligned
            add(grid(tiles))
            index += 8
        }
    }

    // MARK: Building blocks

    private func add(_ view: UIView) { stack.addArrangedSubview(view) }

    private func label(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 15)
        l.textColor = .label
        l.numberOfLines = 0
        return l
    }

    private func header(_ text: String) -> UILabel {
        let l = label(text)
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .secondaryLabel
        return l
    }

    private func note(_ text: String) -> UILabel {
        let l = label(text)
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        return l
    }

    private func button(_ title: String, _ action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }

    private func tile(_ title: String, _ action: @escaping () -> Void) -> UIButton {
        let b = button(title, action)
        b.setTitleColor(.label, for: .normal)
        b.backgroundColor = KeyButton.normalColor
        b.layer.cornerRadius = 6
        b.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return b
    }

    private func grid(_ views: [UIView]) -> UIStackView {
        let s = UIStackView(arrangedSubviews: views)
        s.axis = .horizontal
        s.spacing = 4
        s.distribution = .fillEqually
        return s
    }

    private func row(_ title: String, _ control: UIView) -> UIStackView {
        let l = label(title)
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        let s = UIStackView(arrangedSubviews: [l, control])
        s.axis = .horizontal
        s.spacing = 10
        s.alignment = .center
        return s
    }

    private func titleBar(_ title: String, button text: String,
                          _ action: @escaping () -> Void) -> UIStackView {
        let s = row(title, button(text, action))
        (s.arrangedSubviews.first as? UILabel)?.font = .systemFont(ofSize: 17, weight: .semibold)
        return s
    }

    private func toggle(_ isOn: Bool, enabled: Bool = true,
                        _ changed: @escaping (Bool) -> Void) -> UISwitch {
        let s = UISwitch()
        s.isOn = isOn
        s.isEnabled = enabled
        s.addAction(UIAction { [weak s] _ in changed(s?.isOn ?? false) }, for: .valueChanged)
        return s
    }

    private func choice(_ items: [String], _ selected: Int,
                        _ changed: @escaping (Int) -> Void) -> UISegmentedControl {
        let s = UISegmentedControl(items: items)
        s.selectedSegmentIndex = min(max(selected, 0), items.count - 1)
        s.addAction(UIAction { [weak s] _ in changed(s?.selectedSegmentIndex ?? 0) },
                    for: .valueChanged)
        return s
    }

    private func levels(_ selected: Int, _ changed: @escaping (Int) -> Void) -> UISegmentedControl {
        let s = UISegmentedControl(items: ["Off", "Light", "Medium", "Strong"])
        s.selectedSegmentIndex = min(max(selected, 0), 3)
        s.addAction(UIAction { [weak s] _ in
            let level = s?.selectedSegmentIndex ?? 0
            changed(level)
            Haptics.play(level)             // let the user feel the chosen level
        }, for: .valueChanged)
        return s
    }

    private func slider(value: Float, min: Float, max: Float, enabled: Bool = true,
                        title: @escaping (Float) -> String,
                        changed: @escaping (Float) -> Void,
                        ended: (() -> Void)? = nil) -> UIStackView {
        let l = label(title(value))
        let s = UISlider()
        s.minimumValue = min
        s.maximumValue = max
        s.value = value
        s.isEnabled = enabled
        s.addAction(UIAction { [weak s, weak l] _ in
            guard let s = s else { return }
            l?.text = title(s.value)
            changed(s.value)
        }, for: .valueChanged)
        if let ended = ended {
            s.addAction(UIAction { _ in ended() },
                        for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        let v = UIStackView(arrangedSubviews: [l, s])
        v.axis = .vertical
        v.spacing = 2
        return v
    }
}
