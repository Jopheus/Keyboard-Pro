//
//  SettingsPanel.swift
//  The settings screen shown inside the keyboard (gear button).
//
//  - A short main menu (Appearance, Typing, Tac Tile, Action Keys) with one
//    page each. The title and its Done / Back button stay pinned on top.
//  - Appearance, Typing and Tac Tile show a strip of sample keys under the
//    title so changes can be seen, heard and felt straight away.
//  - Going back returns to where the previous page was scrolled.
//  - Max features sit with the settings they belong to, marked MAX, and are
//    greyed out until Max is unlocked.
//  - Clear / Reset buttons need a second tap to confirm.
//  - Text follows the iPhone's text-size setting; rows are at least 44 pt.
//

import UIKit

final class SettingsPanel: UIView {
    var onDone: (() -> Void)?
    var onHeightChanged: (() -> Void)?
    var onClearHistory: (() -> Void)?
    var onThemeChanged: (() -> Void)?
    var onFeedbackChanged: (() -> Void)?
    /// Asks the keyboard to open the emoji page so the user can pick an
    /// emoji for an Action Key (see KBSettings.shortcutNames).
    var onPickEmoji: ((Int) -> Void)?
    /// A sample key was pressed: play the Tac Tile sound and vibration.
    var onPreviewKey: ((KeySound) -> Void)?

    /// Where the panel opens.
    enum Start { case main, spaceKeys }

    private enum Screen {
        case main, appearance, typing, tacTile
        case words, remap, pick(String), spaceKeys, spaceKey(Int)

        /// How deep in the menus this page is. Moving to a smaller number is "back".
        var depth: Int {
            switch self {
            case .main:                                       return 0
            case .appearance, .typing, .tacTile, .spaceKeys: return 1
            case .words, .remap, .spaceKey:                   return 2
            case .pick:                                       return 3
            }
        }

        var key: String {
            switch self {
            case .main:              return "main"
            case .appearance:        return "appearance"
            case .typing:            return "typing"
            case .tacTile:           return "tacTile"
            case .words:             return "words"
            case .remap:             return "remap"
            case .pick(let letter):  return "pick-" + letter
            case .spaceKeys:         return "actionKeys"
            case .spaceKey(let i):   return "actionKey-\(i)"
            }
        }

        /// Pages that show the sample keys.
        var showsPreview: Bool {
            switch self {
            case .appearance, .typing, .tacTile: return true
            default:                             return false
            }
        }
    }

    private let settings: KBSettings
    private let titleLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var action: (() -> Void)?
    private let previewBar = UIStackView()
    private var previewTimer: Timer?
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var screen = Screen.main
    private var fullAccess = false
    /// Scroll position of each page, restored when coming back to it.
    private var offsets: [String: CGFloat] = [:]
    /// Where add() puts views: the page, or the inside of a card.
    private var target: UIStackView?
    private static let headerTag = 900

    // MARK: Fonts (follow the iPhone's text-size setting, within limits)

    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: size, weight: weight),
                                         maximumPointSize: size * 1.4)
    }

    // MARK: Set-up

    init(settings: KBSettings) {
        self.settings = settings
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        // Pinned header: title on the left, Done / Back on the right.
        titleLabel.font = Self.font(17, .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.accessibilityTraits = .header
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        actionButton.titleLabel?.font = Self.font(17, .semibold)
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        actionButton.contentHorizontalAlignment = .trailing
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        actionButton.addAction(UIAction { [weak self] _ in self?.action?() }, for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [titleLabel, actionButton])
        header.axis = .horizontal
        header.spacing = 10
        header.alignment = .fill
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        let divider = UIView()
        divider.backgroundColor = .separator

        // Sample keys, shown on some pages only.
        previewBar.axis = .horizontal
        previewBar.spacing = 8
        previewBar.alignment = .center
        previewBar.isLayoutMarginsRelativeArrangement = true
        previewBar.layoutMargins = UIEdgeInsets(top: 6, left: 16, bottom: 4, right: 16)
        previewBar.isHidden = true

        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        let column = UIStackView(arrangedSubviews: [header, divider, previewBar, scroll])
        column.axis = .vertical
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),

            soft(header.heightAnchor.constraint(equalToConstant: 44)),
            soft(divider.heightAnchor.constraint(equalToConstant: 0.5)),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// A constraint that gives way instead of clashing while views are hidden.
    private func soft(_ constraint: NSLayoutConstraint) -> NSLayoutConstraint {
        constraint.priority = UILayoutPriority(999)
        return constraint
    }

    /// Call each time the panel is opened.
    func reload(hasFullAccess: Bool, start: Start = .main) {
        fullAccess = hasFullAccess
        offsets.removeAll()
        screen = (start == .spaceKeys) ? .spaceKeys : .main
        render()
    }

    // MARK: Navigation

    private func show(_ next: Screen) {
        offsets[screen.key] = scroll.contentOffset.y
        let goingBack = next.depth < screen.depth
        screen = next
        render(restore: goingBack ? offsets[next.key] : nil)
    }

    /// Rebuilds the current page. `keepScroll` stays where it is (a value on
    /// this page changed); `restore` returns to a remembered position (back).
    private func render(keepScroll: Bool = false, restore: CGFloat? = nil) {
        let current = scroll.contentOffset.y
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        target = nil

        previewBar.isHidden = !screen.showsPreview
        rebuildPreview()

        switch screen {
        case .main:               renderMain()
        case .appearance:         renderAppearance()
        case .typing:             renderTyping()
        case .tacTile:            renderTacTile()
        case .words:              renderWords()
        case .remap:              renderRemap()
        case .pick(let letter):   renderPick(letter)
        case .spaceKeys:          renderSpaceKeys()
        case .spaceKey(let side): renderSpaceKey(side)
        }

        let wanted = keepScroll ? current : (restore ?? 0)
        layoutIfNeeded()
        let limit = max(0, scroll.contentSize.height - scroll.bounds.height)
        scroll.setContentOffset(CGPoint(x: 0, y: min(max(0, wanted), limit)), animated: false)
    }

    private func setHeader(_ title: String, button: String, _ handler: @escaping () -> Void) {
        titleLabel.text = title
        UIView.performWithoutAnimation {
            actionButton.setTitle(button, for: .normal)
            actionButton.layoutIfNeeded()
        }
        action = handler
    }

    // MARK: Sample keys

    private func rebuildPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        previewBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard screen.showsPreview else { return }

        let symbols = settings.effectiveSymbols
        let samples: [(KeyButton, KeySound)] = [
            (KeyButton(kind: .char, title: "a", output: "a", alternate: symbols["a"]), .generic),
            (KeyButton(kind: .char, title: "g", output: "g", alternate: symbols["g"]), .generic),
            (KeyButton(kind: .ret, icon: "return", function: true), .enter),
        ]
        for (key, sound) in samples {
            key.addAction(UIAction { [weak self, weak key] _ in
                guard let self = self, let key = key else { return }
                self.previewDown(key, sound)
            }, for: .touchDown)
            key.addAction(UIAction { [weak self, weak key] _ in
                guard let self = self, let key = key else { return }
                self.previewUp(key)
            }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
            NSLayoutConstraint.activate([
                key.widthAnchor.constraint(equalToConstant: 40),
                soft(key.heightAnchor.constraint(equalToConstant: 42)),
            ])
            previewBar.addArrangedSubview(key)
        }
        let hint = note("Try it: tap or hold a key")
        hint.numberOfLines = 2
        previewBar.addArrangedSubview(hint)
    }

    private func previewDown(_ key: KeyButton, _ sound: KeySound) {
        onPreviewKey?(sound)
        key.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        previewTimer?.invalidate()
        previewTimer = nil
        guard let alternate = key.alternate else { return }

        // Holding shows the long-press symbol after the chosen duration.
        let timer = Timer(timeInterval: settings.longPressMs / 1000, repeats: false) { [weak self, weak key] _ in
            guard let self = self, let key = key else { return }
            key.setTitle(alternate)
            Haptics.play(self.settings.longHaptic)
        }
        RunLoop.main.add(timer, forMode: .common)
        previewTimer = timer
    }

    private func previewUp(_ key: KeyButton) {
        previewTimer?.invalidate()
        previewTimer = nil
        key.transform = .identity
        if key.kind == .char { key.setTitle(key.output) }
    }

    // MARK: Main menu

    private func renderMain() {
        setHeader("Keyboard settings", button: "Done") { [weak self] in self?.onDone?() }

        if !fullAccess { add(accessBanner()) }

        let theme = KBSettings.themeNames[min(max(settings.theme, 0), KBSettings.themeNames.count - 1)]
        add(menuRow("paintbrush", "Appearance", value: theme) { [weak self] in self?.show(.appearance) })
        add(menuRow("keyboard", "Typing", value: "") { [weak self] in self?.show(.typing) })
        let feel = TacPreset.current(settings)?.title
            ?? SoundPack.named(settings.effectiveFeel.pack).title
        add(menuRow("speaker.wave.2", "Tac Tile", value: feel) { [weak self] in self?.show(.tacTile) })
        add(menuRow("square.grid.2x2", "Action Keys",
                    value: (0...2).map(keyName).joined(separator: "  ")) { [weak self] in
            self?.show(.spaceKeys)
        })
        add(row("Max unlocked (test switch)", toggle(settings.maxUnlocked) { [weak self] in
            self?.settings.maxUnlocked = $0
            self?.onHeightChanged?()
            self?.onFeedbackChanged?()
            self?.render(keepScroll: true)
        }, badge: true))

        add(confirmButton("Reset all settings", confirm: "Tap again to reset all settings") { [weak self] in
            guard let self = self else { return }
            self.settings.resetAll()
            self.onThemeChanged?()
            self.onHeightChanged?()
            self.onFeedbackChanged?()
            self.render()
        })

        let info = Bundle(for: SettingsPanel.self).infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        let about = note("Keyboard Pro \(version) (\(build))")
        about.textAlignment = .center
        add(about)
    }

    // MARK: Appearance

    private func renderAppearance() {
        setHeader("Appearance", button: "Back") { [weak self] in self?.show(.main) }

        add(label("Theme"))
        add(choice(KBSettings.themeNames, settings.theme) { [weak self] in
            self?.settings.theme = $0
            self?.onThemeChanged?()
        })

        add(label("One-handed keyboard"))
        add(choice(["Off", "Left", "Right"], settings.oneHanded) { [weak self] in
            self?.settings.oneHanded = $0
        })
        add(note("Pushes the keys to one side. Use the arrows beside the keys to switch "
                 + "sides or go back to full width. Off in landscape."))

        add(slider(value: Float(settings.heightScale * 100), min: 85, max: 125,
                   enabled: settings.maxUnlocked, badge: true,
                   title: { "Keyboard height: \(Int($0.rounded()))%" },
                   changed: { [weak self] in
                       self?.settings.heightScale = Double($0.rounded()) / 100
                   },
                   ended: { [weak self] in self?.onHeightChanged?() }))
    }

    // MARK: Typing

    private func renderTyping() {
        setHeader("Typing", button: "Back") { [weak self] in self?.show(.main) }
        let isMax = settings.maxUnlocked

        add(header("Suggestions"))
        add(row("Word suggestions", toggle(settings.suggestionsOn) { [weak self] in
            self?.settings.suggestionsOn = $0
        }))
        add(row("Auto-correct spelling", toggle(settings.autocorrectOn) { [weak self] in
            self?.settings.autocorrectOn = $0
        }))
        add(row("Paste button for copied codes", toggle(settings.pasteCodesOn) { [weak self] in
            self?.settings.pasteCodesOn = $0
        }))
        add(row("My words (\(settings.customWords.count))",
                button("Manage") { [weak self] in self?.show(.words) }))

        add(row("Learn from my typing", toggle(settings.historyOn, enabled: isMax) { [weak self] in
            self?.settings.historyOn = $0
        }, badge: true, dimmed: !isMax))
        add(row("Typing history",
                locked(confirmButton("Clear", confirm: "Tap again to clear", done: "Cleared") { [weak self] in
                    self?.onClearHistory?()
                }, !isMax), badge: true, dimmed: !isMax))

        add(header("Long press"))
        add(row("Show symbol hints on keys", toggle(settings.showHints) { [weak self] in
            self?.settings.showHints = $0
        }))
        add(label("Vibration on long press"))
        add(levels(settings.longHaptic) { [weak self] in self?.settings.longHaptic = $0 })

        add(slider(value: Float(settings.longPressMs), min: 150, max: 800,
                   title: { "Long press duration: \(Int(($0 / 10).rounded() * 10)) ms" },
                   changed: { [weak self] in
                       self?.settings.longPressMs = Double(($0 / 10).rounded() * 10)
                   }))

        add(row("Remap long-press symbols",
                locked(button("Edit") { [weak self] in self?.show(.remap) }, !isMax),
                badge: true, dimmed: !isMax))
    }

    private func renderWords() {
        setHeader("My words", button: "Back") { [weak self] in self?.show(.typing) }
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
        setHeader("Remap symbols", button: "Back") { [weak self] in self?.show(.typing) }
        add(note("Tap a letter to choose its long-press symbol."))

        let symbols = settings.effectiveSymbols
        for letters in ["qwertyuiop", "asdfghjkl", "zxcvbnm"] {
            add(grid(letters.map { String($0) }.map { letter -> UIView in
                let t = tile("\(letter) \(symbols[letter] ?? "")") { [weak self] in
                    self?.show(.pick(letter))
                }
                t.accessibilityLabel = "\(letter), long press types \(symbols[letter] ?? "")"
                return t
            }))
        }
        add(confirmButton("Reset all to default", confirm: "Tap again to reset symbols") { [weak self] in
            self?.settings.symbolMap = [:]
            self?.render(keepScroll: true)
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

    // MARK: Tac Tile (sound + vibration)

    private func renderTacTile() {
        setHeader("Tac Tile", button: "Back") { [weak self] in self?.show(.main) }

        if !fullAccess { add(accessBanner()) }

        let changed: () -> Void = { [weak self] in
            self?.onFeedbackChanged?()              // reloads and plays a sample
            self?.render(keepScroll: true)
        }
        let preset = TacPreset.current(settings)
        let isMax = settings.maxUnlocked
        let feel = settings.effectiveFeel

        // Presets set the sound and the vibration together. They are free.
        add(header("Presets"))
        add(grid(TacPreset.all.map { item -> UIView in
            selectable(item.title, selected: item.title == preset?.title) { [weak self] in
                self?.settings.soundPack = item.pack
                self?.settings.tapHaptic = item.haptic
                changed()
            }
        }))
        add(note(preset?.summary ?? "Your own mix of sound and vibration."))

        // Max: choose any sound pack and any vibration separately.
        add(header("Sound", badge: true))
        addGrid(SoundPack.all.map { item -> UIView in
            locked(selectable(item.title, selected: item.file == feel.pack) { [weak self] in
                self?.settings.soundPack = item.file
                self?.settings.tapHaptic = feel.haptic
                changed()
            }, !isMax)
        }, perRow: 3)

        add(header("Vibration when typing", badge: true))
        addGrid(TapHaptic.choices.map { item -> UIView in
            locked(selectable(item.title, selected: item.value == feel.haptic) { [weak self] in
                self?.settings.tapHaptic = item.value
                self?.settings.soundPack = feel.pack
                changed()
            }, !isMax)
        }, perRow: 3)
    }

    // MARK: Action Keys (left of space, right of space, right of the suggestion bar)

    private func keyName(_ index: Int) -> String {
        settings.shortcutShown(index) ? KBSettings.displayName(settings.shortcutKey(index)) : "–"
    }

    private func renderSpaceKeys() {
        setHeader("Action Keys", button: "Back") { [weak self] in self?.show(.main) }
        if !fullAccess {
            add(note("A Paste key needs Full Access: Settings → General → Keyboard → "
                     + "Keyboards → Keyboard Pro → Allow Full Access."))
        }

        for index in 0...2 {
            add(header(KBSettings.shortcutNames[index]))
            add(row("Show", toggle(settings.shortcutShown(index)) { [weak self] in
                self?.settings.setShortcutShown(index, $0)
            }))
            add(row(KBSettings.displayName(settings.shortcutKey(index)),
                    button("Change") { [weak self] in self?.show(.spaceKey(index)) }))
        }

        add(confirmButton("Reset to , . Paste", confirm: "Tap again to reset Action Keys") { [weak self] in
            guard let self = self else { return }
            for index in 0...2 {
                self.settings.setShortcutKey(index, KBSettings.shortcutDefaults[index])
                self.settings.setShortcutShown(index, true)
            }
            self.render(keepScroll: true)
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

    /// A grid of tiles, eight per row (symbol pickers).
    private func addTiles(_ values: [String], _ picked: @escaping (String) -> Void) {
        addGrid(values.map { value -> UIView in tile(value) { picked(value) } }, perRow: 8)
    }

    /// Lays views out in equal columns; the last row is padded to stay aligned.
    private func addGrid(_ views: [UIView], perRow: Int) {
        var index = 0
        while index < views.count {
            var line = Array(views[index..<min(index + perRow, views.count)])
            while line.count < perRow { line.append(UIView()) }
            add(grid(line))
            index += perRow
        }
    }

    private func label(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = Self.font(15)
        l.adjustsFontForContentSizeCategory = true
        l.textColor = .label
        l.numberOfLines = 0
        return l
    }

    private func header(_ text: String, badge: Bool = false) -> UIView {
        let l = label(text)
        l.font = Self.font(13, .semibold)
        l.textColor = .secondaryLabel
        l.accessibilityTraits = .header
        guard badge else {
            l.tag = Self.headerTag
            return l
        }
        // Section title followed by a MAX badge.
        l.accessibilityLabel = text + ", Max feature"
        l.setContentHuggingPriority(.required, for: .horizontal)
        let s = UIStackView(arrangedSubviews: [l, maxBadge(), UIView()])
        s.axis = .horizontal
        s.spacing = 8
        s.alignment = .center
        s.tag = Self.headerTag
        return s
    }

    /// Greys out a control and stops it responding (Max feature without Max).
    private func locked<T: UIControl>(_ control: T, _ isLocked: Bool) -> T {
        if isLocked {
            control.isEnabled = false
            control.alpha = 0.4
            control.accessibilityHint = "Needs Max"
        }
        return control
    }

    private func note(_ text: String) -> UILabel {
        let l = label(text)
        l.font = Self.font(13)
        l.textColor = .secondaryLabel
        return l
    }

    private func button(_ title: String, _ action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = Self.font(15, .medium)
        b.titleLabel?.adjustsFontForContentSizeCategory = true
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        soft(b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)).isActive = true
        b.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return b
    }

    /// A destructive button that needs a second tap within a few seconds.
    private func confirmButton(_ title: String, confirm: String, done: String? = nil,
                               _ action: @escaping () -> Void) -> ConfirmButton {
        let b = ConfirmButton(type: .system)
        b.configure(title: title, confirm: confirm, done: done, action: action)
        soft(b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)).isActive = true
        return b
    }

    private func tile(_ title: String, _ action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = Self.font(15, .medium)
        b.titleLabel?.adjustsFontForContentSizeCategory = true
        b.titleLabel?.adjustsFontSizeToFitWidth = true
        b.titleLabel?.minimumScaleFactor = 0.7
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        b.setTitleColor(.label, for: .normal)
        b.backgroundColor = KeyButton.normalColor
        b.layer.cornerRadius = 8
        soft(b.heightAnchor.constraint(equalToConstant: 44)).isActive = true
        return b
    }

    /// A tile that is highlighted when it is the current choice.
    private func selectable(_ title: String, selected: Bool,
                            _ action: @escaping () -> Void) -> UIButton {
        let t = tile(title, action)
        if selected {
            t.backgroundColor = .systemBlue
            t.setTitleColor(.white, for: .normal)
            t.titleLabel?.font = Self.font(15, .bold)
            t.accessibilityTraits.insert(.selected)
        }
        return t
    }

    private func grid(_ views: [UIView]) -> UIStackView {
        let s = UIStackView(arrangedSubviews: views)
        s.axis = .horizontal
        s.spacing = 6
        s.distribution = .fillEqually
        return s
    }

    /// A title on the left and a control on the right. `badge` marks a Max
    /// feature; `dimmed` greys the title when that feature is locked.
    private func row(_ title: String, _ control: UIView, badge: Bool = false,
                     dimmed: Bool = false) -> UIStackView {
        let l = label(title)
        if dimmed { l.textColor = .tertiaryLabel }
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)

        var views: [UIView] = [l]
        if badge {
            l.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            views.append(maxBadge())
            let spacer = UIView()
            spacer.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
            spacer.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
            views.append(spacer)
        } else {
            l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        views.append(control)

        let s = UIStackView(arrangedSubviews: views)
        s.axis = .horizontal
        s.spacing = 8
        s.alignment = .center
        soft(s.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)).isActive = true
        return s
    }

    private func maxBadge() -> BadgeLabel {
        let badge = BadgeLabel()
        badge.text = "MAX"
        badge.backgroundColor = .systemPurple
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        return badge
    }

    /// One line of the main menu: icon, name, current value, chevron.
    private func menuRow(_ icon: String, _ title: String, value: String, tint: UIColor = .label,
                         _ action: @escaping () -> Void) -> UIView {
        let image = UIImageView(image: UIImage(systemName: icon))
        image.tintColor = tint
        image.contentMode = .scaleAspectFit

        let name = label(title)
        name.font = Self.font(16, .medium)
        name.numberOfLines = 1
        name.setContentHuggingPriority(.required, for: .horizontal)
        name.setContentCompressionResistancePriority(.required, for: .horizontal)

        let current = note(value)
        current.numberOfLines = 1
        current.textAlignment = .right
        current.lineBreakMode = .byTruncatingTail
        current.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        current.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit

        let tap = TapRow(card: true)
        let parts: [UIView] = [image, name, current, chevron]
        parts.forEach { tap.content.addArrangedSubview($0) }
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 24),
            chevron.widthAnchor.constraint(equalToConstant: 10),
        ])
        tap.accessibilityLabel = title
        tap.accessibilityValue = value
        tap.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return tap
    }

    /// Shown while "Allow Full Access" is off.
    private func accessBanner() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor = .systemOrange
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let title = label("Full Access is off")
        title.font = Self.font(15, .semibold)
        let head = UIStackView(arrangedSubviews: [icon, title])
        head.axis = .horizontal
        head.spacing = 8
        head.alignment = .center

        let text = note("Sound, vibration and the Paste key need it. Turn it on in Settings → "
                        + "General → Keyboard → Keyboards → Keyboard Pro → Allow Full Access.")
        text.textColor = .label

        let content = UIStackView(arrangedSubviews: [head, text])
        content.axis = .vertical
        content.spacing = 6
        content.translatesAutoresizingMaskIntoConstraints = false

        let box = UIView()
        box.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.18)
        box.layer.cornerRadius = 10
        box.addSubview(content)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 20),
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10),
        ])
        return box
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
        soft(s.heightAnchor.constraint(equalToConstant: 44)).isActive = true
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
        soft(s.heightAnchor.constraint(equalToConstant: 44)).isActive = true
        return s
    }

    private func slider(value: Float, min: Float, max: Float, enabled: Bool = true,
                        badge: Bool = false,
                        title: @escaping (Float) -> String,
                        changed: @escaping (Float) -> Void,
                        ended: (() -> Void)? = nil) -> UIStackView {
        let l = label(title(value))
        l.isAccessibilityElement = false        // the slider reads the same text
        let s = UISlider()
        s.minimumValue = min
        s.maximumValue = max
        s.value = value
        s.isEnabled = enabled
        s.accessibilityLabel = title(value)
        s.addAction(UIAction { [weak s, weak l] _ in
            guard let s = s else { return }
            l?.text = title(s.value)
            s.accessibilityLabel = title(s.value)
            changed(s.value)
        }, for: .valueChanged)
        if let ended = ended {
            s.addAction(UIAction { _ in ended() },
                        for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        soft(s.heightAnchor.constraint(equalToConstant: 44)).isActive = true
        if !enabled {
            l.textColor = .tertiaryLabel
            s.accessibilityHint = "Needs Max"
        }

        var top: UIView = l
        if badge {
            l.setContentHuggingPriority(.required, for: .horizontal)
            let line = UIStackView(arrangedSubviews: [l, maxBadge(), UIView()])
            line.axis = .horizontal
            line.spacing = 8
            line.alignment = .center
            top = line
        }
        let v = UIStackView(arrangedSubviews: [top, s])
        v.axis = .vertical
        v.spacing = 2
        return v
    }
}

// MARK: - Tappable row

/// A whole row that acts as one button (main menu lines, locked Max rows).
final class TapRow: UIControl {
    let content = UIStackView()

    init(card: Bool) {
        super.init(frame: .zero)
        content.axis = .horizontal
        content.spacing = 10
        content.alignment = .center
        content.isUserInteractionEnabled = false     // touches go to the row itself
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        let inset: CGFloat = card ? 12 : 0
        let height = heightAnchor.constraint(greaterThanOrEqualToConstant: card ? 48 : 44)
        height.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            height,
        ])
        if card {
            backgroundColor = KeyButton.normalColor
            layer.cornerRadius = 10
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.5 : 1 }
    }
}

// MARK: - Confirm button

/// Red button for clearing or resetting. The first tap asks, the second
/// tap (within three seconds) does it.
final class ConfirmButton: UIButton {
    private var normalTitle = ""
    private var confirmTitle = ""
    private var doneTitle: String?
    private var action: (() -> Void)?
    private var armed = false
    private var token = 0

    func configure(title: String, confirm: String, done: String?, action: @escaping () -> Void) {
        normalTitle = title
        confirmTitle = confirm
        doneTitle = done
        self.action = action
        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
        setContentCompressionResistancePriority(.required, for: .horizontal)
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        show(title, bold: false, color: .systemRed)
    }

    private func show(_ text: String, bold: Bool, color: UIColor) {
        UIView.performWithoutAnimation {
            setTitle(text, for: .normal)
            setTitleColor(color, for: .normal)
            titleLabel?.font = SettingsPanel.font(15, bold ? .bold : .medium)
            layoutIfNeeded()
        }
    }

    @objc private func tapped() {
        token += 1
        let mine = token
        if armed {
            armed = false
            action?()
            if let done = doneTitle {
                show(done, bold: false, color: .secondaryLabel)
                UIAccessibility.post(notification: .announcement, argument: done)
                restore(after: 2, token: mine)
            } else {
                show(normalTitle, bold: false, color: .systemRed)
            }
        } else {
            armed = true
            show(confirmTitle, bold: true, color: .systemRed)
            restore(after: 3, token: mine)
        }
    }

    /// Goes back to the normal title unless the button was tapped again.
    private func restore(after seconds: Double, token mine: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self = self, self.token == mine else { return }
            self.armed = false
            self.show(self.normalTitle, bold: false, color: .systemRed)
        }
    }
}

/// A small rounded label with padding, used for the MAX badges.
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
