//
//  SettingsPanel.swift
//  The settings screen shown inside the keyboard (gear button).
//  The title and its Done / Back button stay pinned at the top while the
//  options scroll underneath.
//

import UIKit

final class SettingsPanel: UIView {
    var onDone: (() -> Void)?
    var onHeightChanged: (() -> Void)?
    var onClearHistory: (() -> Void)?
    var onThemeChanged: (() -> Void)?
    var onFeedbackChanged: (() -> Void)?
    /// Asks the keyboard to open the emoji page so the user can pick an
    /// emoji for a shortcut key (see KBSettings.shortcutNames).
    var onPickEmoji: ((Int) -> Void)?

    /// Where the panel opens.
    enum Start { case main, spaceKeys }

    private enum Screen { case main, words, remap, pick(String), spaceKeys, spaceKey(Int) }

    private let settings: KBSettings
    private let titleLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var action: (() -> Void)?
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var screen = Screen.main
    private var fullAccess = false
    /// Where add() puts views: the page, or the inside of the Max card.
    private var target: UIStackView?
    private static let headerTag = 900

    init(settings: KBSettings) {
        self.settings = settings
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        // Pinned header: title on the left, Done / Back on the right.
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        actionButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        actionButton.addAction(UIAction { [weak self] _ in self?.action?() }, for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [titleLabel, actionButton])
        header.axis = .horizontal
        header.spacing = 10
        header.alignment = .center
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            header.topAnchor.constraint(equalTo: topAnchor),
            header.heightAnchor.constraint(equalToConstant: 40),

            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.topAnchor.constraint(equalTo: header.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: divider.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Call each time the panel is opened.
    func reload(hasFullAccess: Bool, start: Start = .main) {
        fullAccess = hasFullAccess
        screen = (start == .spaceKeys) ? .spaceKeys : .main
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
        case .main:              renderMain()
        case .words:             renderWords()
        case .remap:             renderRemap()
        case .pick(let letter):  renderPick(letter)
        case .spaceKeys:         renderSpaceKeys()
        case .spaceKey(let side): renderSpaceKey(side)
        }
    }

    private func setHeader(_ title: String, button: String, _ handler: @escaping () -> Void) {
        titleLabel.text = title
        UIView.performWithoutAnimation {
            actionButton.setTitle(button, for: .normal)
            actionButton.layoutIfNeeded()
        }
        action = handler
    }

    // MARK: Screens

    private func renderMain() {
        setHeader("Keyboard settings", button: "Done") { [weak self] in self?.onDone?() }

        add(header("Pro"))

        add(label("Theme"))
        add(choice(["Auto", "Light", "Dark", "Glass"], settings.theme) { [weak self] in
            self?.settings.theme = $0
            self?.onThemeChanged?()
        })

        add(slider(value: Float(settings.longPressMs), min: 150, max: 800,
                   title: { "Long press duration: \(Int(($0 / 10).rounded() * 10)) ms" },
                   changed: { [weak self] in
                       self?.settings.longPressMs = Double(($0 / 10).rounded() * 10)
                   }))

        add(row("Shortcut keys (\((0...2).map(keyName).joined(separator: " ")))",
                button("Edit") { [weak self] in self?.show(.spaceKeys) }))

        add(row("Word suggestions", toggle(settings.suggestionsOn) { [weak self] in
            self?.settings.suggestionsOn = $0
        }))
        add(row("Auto-correct spelling", toggle(settings.autocorrectOn) { [weak self] in
            self?.settings.autocorrectOn = $0
        }))
        add(row("Paste button for copied codes", toggle(settings.pasteCodesOn) { [weak self] in
            self?.settings.pasteCodesOn = $0
        }))

        // Tac Tile: mechanical switch sound + vibration
        if !fullAccess {
            add(note("Sound and vibration need Full Access. Turn it on in Settings → General → "
                     + "Keyboard → Keyboards → Keyboard Pro → Allow Full Access."))
        }
        let profile = SwitchProfile(rawValue: settings.switchProfile) ?? .brown
        add(label("Tac Tile"))
        add(choice(SwitchProfile.allCases.map { $0.title }, profile.rawValue) { [weak self] in
            self?.settings.switchProfile = $0
            self?.onFeedbackChanged?()
            self?.render(keepScroll: true)
        })
        add(note(profile.summary))

        if profile == .custom {
            add(label("Sound"))
            addPackPicker()
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

        let isMax = settings.maxUnlocked
        let card = MaxCard(unlocked: isMax)
        add(card)
        stack.setCustomSpacing(28, after: stack.arrangedSubviews[stack.arrangedSubviews.count - 2])
        target = card.content
        defer { target = nil }

        if !isMax {
            add(note("Remapped symbols, smart suggestions from your typing, and a taller or "
                     + "shorter keyboard."))
        }
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
        setHeader("My words", button: "Back") { [weak self] in self?.show(.main) }
        add(note("To add a word: type it in any app, then tap “+ word” in the bar above the keys."))

        let words = settings.customWords
        if words.isEmpty { add(label("No words yet.")) }
        for word in words {
            add(row(word, button("Remove") { [weak self] in
                guard let self = self else { return }
                self.settings.customWords = self.settings.customWords.filter { $0 != word }
                self.render(keepScroll: true)
            }))
        }
    }

    private func renderRemap() {
        setHeader("Remap symbols", button: "Back") { [weak self] in self?.show(.main) }
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
        setHeader("Symbol for “\(letter)”", button: "Back") { [weak self] in self?.show(.remap) }
        addTiles(KBSettings.symbolChoices) { [weak self] symbol in
            guard let self = self else { return }
            var map = self.settings.symbolMap
            map[letter] = symbol
            self.settings.symbolMap = map
            self.show(.remap)
        }
    }

    // MARK: Shortcut keys (left of space, right of space, end of A–L row)

    private func keyName(_ index: Int) -> String {
        settings.shortcutShown(index) ? KBSettings.displayName(settings.shortcutKey(index)) : "–"
    }

    private func renderSpaceKeys() {
        setHeader("Shortcut keys", button: "Back") { [weak self] in self?.show(.main) }
        add(note("Three keys you choose: either side of the space bar, and at the end of "
                 + "the A–L row. Hide a space-bar key to make the space bar wider."))
        if !fullAccess {
            add(note("A Paste key needs Full Access: Settings → General → Keyboard → "
                     + "Keyboards → Keyboard Pro → Allow Full Access."))
        }

        for index in 0...2 {
            add(header(KBSettings.shortcutNames[index]))
            add(row("Show", toggle(settings.shortcutShown(index)) { [weak self] in
                self?.settings.setShortcutShown(index, $0)
            }))
            add(row("Types:  \(KBSettings.displayName(settings.shortcutKey(index)))",
                    button("Change") { [weak self] in self?.show(.spaceKey(index)) }))
        }

        add(button("Reset to , . Paste") { [weak self] in
            guard let self = self else { return }
            for index in 0...2 {
                self.settings.setShortcutKey(index, KBSettings.shortcutDefaults[index])
                self.settings.setShortcutShown(index, true)
            }
            self.render()
        })
    }

    private func renderSpaceKey(_ side: Int) {
        setHeader("\(KBSettings.shortcutNames[side]) types…", button: "Back") { [weak self] in
            self?.show(.spaceKeys)
        }
        let choose: (String) -> Void = { [weak self] value in
            guard let self = self else { return }
            self.settings.setShortcutKey(side, value)
            self.show(.spaceKeys)
        }

        add(button("Paste button (pastes copied text)") {
            choose(KBSettings.pasteAction)
        })
        add(button("Choose an emoji…") { [weak self] in self?.onPickEmoji?(side) })

        add(header("Symbols"))
        addTiles([",", "."] + KBSettings.symbolChoices.filter { $0 != "," && $0 != "." }, choose)
        add(header("Numbers"))
        addTiles((0...9).map { String($0) }, choose)
        add(header("Letters"))
        addTiles("abcdefghijklmnopqrstuvwxyz".map { String($0) }, choose)
    }

    // MARK: Building blocks

    private func add(_ view: UIView) {
        let into = target ?? stack
        // Extra space above each section title.
        if view.tag == Self.headerTag, let previous = into.arrangedSubviews.last {
            into.setCustomSpacing(28, after: previous)
        }
        into.addArrangedSubview(view)
    }

    /// The Custom sound packs, three per row. Tapping one selects it and
    /// plays a sample; the chosen pack is highlighted.
    private func addPackPicker() {
        let packs = SoundPack.all
        let selected = settings.customPack
        var index = 0
        while index < packs.count {
            let tiles: [UIView] = packs[index..<min(index + 3, packs.count)].map { pack in
                let t = tile(pack.title) { [weak self] in
                    guard let self = self else { return }
                    self.settings.customPack = pack.file
                    self.onFeedbackChanged?()          // reloads and plays a sample
                    self.render(keepScroll: true)
                }
                if pack.file == selected {
                    t.backgroundColor = .systemBlue
                    t.setTitleColor(.white, for: .normal)
                    t.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
                }
                return t
            }
            add(grid(tiles))
            index += 3
        }
    }

    /// A grid of tiles, eight per row.
    private func addTiles(_ values: [String], _ picked: @escaping (String) -> Void) {
        var index = 0
        while index < values.count {
            var tiles: [UIView] = values[index..<min(index + 8, values.count)].map { value in
                tile(value) { picked(value) }
            }
            while tiles.count < 8 { tiles.append(UIView()) }    // keep the last row aligned
            add(grid(tiles))
            index += 8
        }
    }

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
        l.tag = Self.headerTag
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
        s.spacing = 12
        s.alignment = .center
        s.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
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
        v.spacing = 6
        return v
    }
}

// MARK: - Max card

/// The Max section: a glowing card with a gradient border, a crown and a
/// Locked / Unlocked badge, so it stands apart from the free settings.
final class MaxCard: UIView {
    let content = UIStackView()
    private let fill = CAGradientLayer()
    private let border = CAGradientLayer()
    private let borderShape = CAShapeLayer()
    private let radius: CGFloat = 16

    init(unlocked: Bool) {
        super.init(frame: .zero)

        fill.startPoint = CGPoint(x: 0, y: 0)
        fill.endPoint = CGPoint(x: 1, y: 1)
        fill.cornerRadius = radius
        layer.addSublayer(fill)

        border.startPoint = CGPoint(x: 0, y: 0)
        border.endPoint = CGPoint(x: 1, y: 1)
        borderShape.lineWidth = 2
        borderShape.fillColor = UIColor.clear.cgColor
        borderShape.strokeColor = UIColor.black.cgColor
        border.mask = borderShape
        layer.addSublayer(border)

        layer.shadowOffset = .zero
        layer.shadowRadius = 10
        layer.shadowOpacity = unlocked ? 0.45 : 0.25

        // Title row: crown, MAX, badge.
        let crown = UIImageView(image: UIImage(systemName: "crown.fill"))
        crown.tintColor = .systemOrange
        crown.contentMode = .scaleAspectFit
        crown.setContentHuggingPriority(.required, for: .horizontal)

        let title = UILabel()
        title.attributedText = NSAttributedString(string: "MAX", attributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .black),
            .foregroundColor: UIColor.systemPurple,
            .kern: 2.5,
        ])
        title.setContentHuggingPriority(.required, for: .horizontal)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let badge = BadgeLabel()
        badge.text = unlocked ? "UNLOCKED" : "LOCKED"
        badge.backgroundColor = unlocked ? .systemPurple : .systemGray
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let titleRow = UIStackView(arrangedSubviews: [crown, title, spacer, badge])
        titleRow.axis = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .center

        content.axis = .vertical
        content.spacing = 18
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addArrangedSubview(titleRow)
        addSubview(content)

        NSLayoutConstraint.activate([
            crown.widthAnchor.constraint(equalToConstant: 22),
            crown.heightAnchor.constraint(equalToConstant: 20),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Colours are set here so they follow light / dark mode.
        let t = traitCollection
        let purple = UIColor.systemPurple.resolvedColor(with: t)
        let pink = UIColor.systemPink.resolvedColor(with: t)
        let orange = UIColor.systemOrange.resolvedColor(with: t)
        let dark = t.userInterfaceStyle == .dark

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame = bounds
        fill.colors = [purple.withAlphaComponent(dark ? 0.26 : 0.14).cgColor,
                       pink.withAlphaComponent(dark ? 0.14 : 0.07).cgColor,
                       orange.withAlphaComponent(dark ? 0.20 : 0.12).cgColor]
        border.frame = bounds
        border.colors = [purple.cgColor, pink.cgColor, orange.cgColor]
        borderShape.frame = bounds
        borderShape.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                        cornerRadius: radius - 1).cgPath
        layer.shadowColor = purple.cgColor
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        CATransaction.commit()
    }
}

/// A small rounded label with padding, used for the Max badge.
final class BadgeLabel: UILabel {
    private let inset = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .systemFont(ofSize: 11, weight: .bold)
        textColor = .white
        layer.cornerRadius = 9
        layer.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: inset))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + inset.left + inset.right,
                      height: size.height + inset.top + inset.bottom)
    }
}
