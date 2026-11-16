//
//  KeyboardViewController.swift
//  Keyboard Pro for iPhone  (version 7)
//
//  - Number row always on top
//  - Long-press any letter to type a symbol (hint shown in the key corner)
//  - Emoji page (smiley key on the bottom row)
//  - Suggestion bar: word completion, auto-correct, add words to dictionary
//  - Settings (gear button): theme, switch sound + vibration, Max options
//  - Key preview popup, shift / caps lock (double-tap), hold-to-delete,
//    double-space for ". ", auto-capitalise, ?123 and =\< symbol pages
//
//  Requires iOS 15 or later (every iPhone 12 and newer can run it).
//

import UIKit

// MARK: - Key view

final class KeyButton: UIControl {
    enum Kind { case char, shift, delete, page, globe, space, ret }

    let kind: Kind
    let base: String            // lowercase letter / symbol
    var output: String          // what gets typed on a normal tap
    let alternate: String?      // what gets typed on long-press
    private(set) var isFunctionKey: Bool

    private let titleLabel = UILabel()
    private let hintLabel = UILabel()
    private let iconView = UIImageView()

    static let normalColor = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.42, alpha: 1) : .white }
    static let functionColor = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.27, alpha: 1) : UIColor(red: 0.67, green: 0.69, blue: 0.73, alpha: 1) }

    init(kind: Kind, title: String = "", output: String = "", alternate: String? = nil,
         icon: String? = nil, function: Bool = false) {
        self.kind = kind
        self.base = output
        self.output = output
        self.alternate = alternate
        self.isFunctionKey = function
        super.init(frame: .zero)

        layer.cornerRadius = 6
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 0

        titleLabel.text = title
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.font = kind == .char ? .systemFont(ofSize: 22)
                                        : .systemFont(ofSize: 15, weight: .medium)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        iconView.tintColor = .label
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        setIcon(icon)

        hintLabel.text = alternate
        hintLabel.textColor = .secondaryLabel
        hintLabel.font = .systemFont(ofSize: 10)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            hintLabel.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
        updateColor()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // An explicit shadow path lets iOS draw the shadow cheaply.
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 6).cgPath
    }

    func setTitle(_ text: String) { titleLabel.text = text }

    func setIcon(_ name: String?) {
        iconView.image = name.flatMap { UIImage(systemName: $0) }
        iconView.isHidden = (name == nil)
    }

    func setFunction(_ value: Bool) {
        isFunctionKey = value
        updateColor()
    }

    override var isHighlighted: Bool { didSet { updateColor() } }

    private func updateColor() {
        // Character keys show a popup instead of changing colour.
        let pressed = isHighlighted && kind != .char
        backgroundColor = (isFunctionKey != pressed) ? Self.functionColor : Self.normalColor
    }
}

// MARK: - Emoji cell

final class EmojiCell: UICollectionViewCell {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 28)
        label.textAlignment = .center
        label.frame = contentView.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}

// MARK: - Touch surface

/// Sends every touch to the nearest key, so taps that land in the small gaps
/// between keys (or just beside an edge key) still type something.
final class KeyboardSurface: UIView {
    var keys: [KeyButton] = []
    /// Views (suggestion bar, emoji list, settings) that handle their own touches.
    var passthroughs: [UIView] = []

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point), !isHidden, isUserInteractionEnabled else { return nil }
        for p in passthroughs where !p.isHidden && p.convert(p.bounds, to: self).contains(point) {
            return super.hitTest(point, with: event)
        }
        var best: KeyButton?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for key in keys {
            let f = key.convert(key.bounds, to: self)
            let dx = max(f.minX - point.x, 0, point.x - f.maxX)
            let dy = max(f.minY - point.y, 0, point.y - f.maxY)
            let d = dx * dx + dy * dy
            if d < bestDistance {
                bestDistance = d
                best = key
            }
        }
        // Further than 20pt from any key (the empty strip on top): ignore.
        return bestDistance <= 400 ? best : self
    }
}

// MARK: - Keyboard

final class KeyboardViewController: UIInputViewController {

    private let settings = KBSettings.shared
    private let engine = SuggestionEngine()
    private let feedback = SwitchFeedback.shared

    private let numberRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

    private let letterRows = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]
    private let symbolRows = [
        ["@", "#", "$", "_", "&", "-", "+", "(", ")", "/"],
        ["*", "\"", "'", ":", ";", "!", "?", ",", "."],
        ["%", "=", "<", ">", "[", "]", "^"],
    ]
    private let moreRows = [
        ["~", "`", "|", "•", "√", "π", "÷", "×", "¶", "∆"],
        ["£", "¢", "€", "¥", "°", "{", "}", "\\", "©"],
        ["®", "™", "✓", "§", "…", "¿", "¡"],
    ]

    // Emoji shown on the emoji page. Add or remove freely.
    private let emojis: [String] = (
        "😀😃😄😁😆😅😂🤣😊😇🙂🙃😉😌😍🥰😘😗😙😚😋😛😜🤪😝🤑🤗🤭🤫🤔🤐🤨😐😑😶😏😒🙄😬🤥"
        + "😔😪🤤😴😷🤒🤕🤢🤮🤧🥵🥶🥴😵🤯🤠🥳😎🤓🧐😕😟🙁😮😯😲😳🥺😦😧😨😰😥😢😭😱😖😣😞😓😩😫🥱"
        + "😤😡😠🤬😈👿💀💩🤡👻👽🤖😺😸😹😻🙈🙉🙊"
        + "👍👎👌🤏🤞🤟🤘🤙👈👉👆👇👋🤚🖐✋🖖👏🙌🤝🙏💪✍👀"
        + "❤🧡💛💚💙💜🖤🤍🤎💔💕💞💓💗💖💘💝💯💢💥💫💦💨🔥⭐🌟✨⚡🎉🎊🎁🎂🏆🥇"
        + "🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐮🐷🐸🐵🐔🐧🐦🦆🦉🐴🦄🐝🦋🐢🐍🐙🐬🐳🐟"
        + "🌸🌹🌻🌴🌵🍀🍁🌈☀🌙☁☔❄🌊"
        + "🍎🍊🍋🍌🍉🍇🍓🍑🍍🥭🥑🍅🌽🥕🍞🧀🍗🍔🍟🍕🌭🌮🍣🍜🍚🍦🍩🍪🍫🍿☕🍵🍺🍷🥤"
        + "⚽🏀🏈⚾🎾🏐🎱🏓🏸🎮🎲🎵🎶🎤🎧🎬📷"
        + "🚗🚕🚌🚓🚑🚒🚚🚲🛵✈🚀🚢🏠🏢🏥🏫⛽🗺"
        + "📱💻⌚📞📺💡🔋🔑🔒🔔📌📎✂📝📚📅📈💰💳💵📦🛒⏰✅❌❓❗⚠🚫💤"
    ).map { String($0) }

    private enum Page { case letters, symbols, more, emoji, settings }
    private enum Shift { case off, on, locked }

    private var page = Page.letters
    private var shift = Shift.off
    private var manualShift = false           // user tapped shift; don't auto-change it
    private var lastShiftTap = Date.distantPast
    private var lastSpaceTap = Date.distantPast

    private let surface = KeyboardSurface()
    private let rowsStack = UIStackView()
    private var heightConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var isLandscape: Bool?
    private var topInset: CGFloat = 36

    private var allKeys: [KeyButton] = []
    private var letterKeys: [KeyButton] = []
    private weak var shiftKey: KeyButton?
    private var builtPage: Page?
    private var builtWithGlobe: Bool?

    private var emojiPanel: UIView?
    private var emojiList: UICollectionView?
    private var emojiBarKeys: [KeyButton] = []

    private var settingsPanel: SettingsPanel?
    private let suggestionBar = UIStackView()
    private var suggestionButtons: [UIButton] = []
    private var suggestions: [Suggestion] = []
    private var lastCorrection: (original: String, corrected: String)?
    private var rejectedCorrections = Set<String>()

    private weak var pendingKey: KeyButton?   // key held down but not typed yet
    private var longPressFired = false
    private var longPressTimer: Timer?
    private var deleteTimer: Timer?
    private let popup = UILabel()

    private var proxy: UITextDocumentProxy { textDocumentProxy }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        surface.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(surface)

        rowsStack.axis = .vertical
        rowsStack.spacing = 8
        rowsStack.distribution = .fillEqually
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(rowsStack)

        let height = view.heightAnchor.constraint(equalToConstant: 298)
        height.priority = UILayoutPriority(999)
        let top = rowsStack.topAnchor.constraint(equalTo: surface.topAnchor, constant: topInset)
        heightConstraint = height
        topConstraint = top

        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surface.topAnchor.constraint(equalTo: view.topAnchor),
            surface.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 3),
            rowsStack.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -3),
            rowsStack.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -4),
            top,
            height,
        ])

        setUpSuggestionBar()
        applyTheme()
        feedback.reload(settings)

        popup.textAlignment = .center
        popup.font = .systemFont(ofSize: 24)
        popup.textColor = .label
        popup.backgroundColor = KeyButton.normalColor
        popup.layer.cornerRadius = 8
        popup.clipsToBounds = true
        popup.isHidden = true
        view.addSubview(popup)

        buildKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Decimal / punctuation number fields open on the symbol page.
        let type = proxy.keyboardType ?? .default
        let numeric = (type == .decimalPad || type == .numbersAndPunctuation)
        page = numeric ? .symbols : .letters
        manualShift = false
        if builtPage != page || builtWithGlobe != needsInputModeSwitchKey { buildKeyboard() }
        updateAutoShift()
        refreshSuggestions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // iOS delays touches near the screen edges (q, a, p, 1 …) while it checks
        // for system swipes. Turning the delay off keeps edge keys responsive.
        view.window?.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard view.bounds.width > 0 else { return }
        let landscape = view.bounds.width > 500
        if landscape != isLandscape { applyMetrics(landscape: landscape) }
        if builtWithGlobe != needsInputModeSwitchKey { buildKeyboard() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelTouches()
        engine.save()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        updateAutoShift()
        refreshSuggestions()
    }

    private func applyMetrics(landscape: Bool) {
        isLandscape = landscape
        topInset = landscape ? 26 : 36
        // Max: the key area can be made shorter or taller.
        let base: CGFloat = landscape ? 228 : 298
        let scaled = topInset + (base - topInset) * settings.effectiveHeightScale
        heightConstraint?.constant = landscape ? min(scaled, 260) : scaled
        topConstraint?.constant = topInset
        rowsStack.spacing = landscape ? 5 : 8
        popup.font = .systemFont(ofSize: landscape ? 18 : 24)
        emojiList?.collectionViewLayout.invalidateLayout()
    }

    // MARK: Building the layout

    private func buildKeyboard() {
        cancelTouches()
        builtPage = page
        builtWithGlobe = needsInputModeSwitchKey

        let showsKeys = (page != .emoji && page != .settings)
        rowsStack.isHidden = !showsKeys
        suggestionBar.isHidden = !showsKeys
        emojiPanel?.isHidden = (page != .emoji)
        settingsPanel?.isHidden = (page != .settings)

        if page == .emoji {
            let panel = emojiPanel ?? makeEmojiPanel()
            panel.isHidden = false
            surface.keys = emojiBarKeys
            surface.passthroughs = emojiList.map { [$0] } ?? []
            return
        }
        if page == .settings {
            let panel = settingsPanel ?? makeSettingsPanel()
            panel.isHidden = false
            panel.reload(hasFullAccess: hasFullAccess)
            surface.keys = []
            surface.passthroughs = [panel]
            return
        }
        surface.passthroughs = [suggestionBar]

        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        allKeys.removeAll()
        letterKeys.removeAll()

        var widths: [NSLayoutConstraint] = []
        func width(_ v: UIView, _ m: CGFloat) {
            widths.append(v.widthAnchor.constraint(equalTo: rowsStack.widthAnchor,
                                                   multiplier: m, constant: -6))
        }

        let rows: [[String]]
        switch page {
        case .symbols: rows = symbolRows
        case .more:    rows = moreRows
        default:       rows = letterRows
        }

        // Number row, then rows 1 and 2
        for chars in [numberRow, rows[0], rows[1]] {
            let keys = chars.map { makeCharKey($0) }
            keys.forEach { width($0, 0.1) }
            addRow(keys, fill: false)
        }

        // Row 3: shift / page key, letters, delete
        let left: KeyButton
        switch page {
        case .symbols:
            left = KeyButton(kind: .page, title: "=\\<", output: "more", function: true)
        case .more:
            left = KeyButton(kind: .page, title: "?123", output: "symbols", function: true)
        default:
            left = KeyButton(kind: .shift, icon: "shift", function: true)
            shiftKey = left
        }
        let del = KeyButton(kind: .delete, icon: "delete.left", function: true)
        let middle = rows[2].map { makeCharKey($0) }
        middle.forEach { width($0, 0.1) }
        width(left, 0.15)
        width(del, 0.15)
        register(left)
        register(del)
        addRow([left] + middle + [del], fill: false)

        // Bottom row: ?123 / ABC, emoji, (globe), space, return
        var bottom: [KeyButton] = []
        let mode = KeyButton(kind: .page,
                             title: page == .letters ? "?123" : "ABC",
                             output: page == .letters ? "symbols" : "letters",
                             function: true)
        register(mode)
        width(mode, 0.15)
        bottom.append(mode)

        let emoji = KeyButton(kind: .page, output: "emoji", icon: "face.smiling", function: true)
        register(emoji)
        width(emoji, 0.12)
        bottom.append(emoji)

        if needsInputModeSwitchKey {
            let globe = makeGlobeKey()
            width(globe, 0.1)
            allKeys.append(globe)
            bottom.append(globe)
        }

        let space = KeyButton(kind: .space, title: "space")
        let ret = KeyButton(kind: .ret, icon: "return", function: true)
        register(space)
        register(ret)
        width(ret, 0.2)
        bottom += [space, ret]
        addRow(bottom, fill: true)

        NSLayoutConstraint.activate(widths)
        surface.keys = allKeys
        refreshCase()
    }

    private func makeCharKey(_ s: String) -> KeyButton {
        let isLetter = (page == .letters) && (s.first?.isLetter == true)
        let key = KeyButton(kind: .char, title: s, output: s,
                            alternate: isLetter ? settings.effectiveSymbols[s] : nil)
        register(key)
        if isLetter { letterKeys.append(key) }
        return key
    }

    private func makeGlobeKey() -> KeyButton {
        let globe = KeyButton(kind: .globe, icon: "globe", function: true)
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)),
                        for: .allTouchEvents)
        return globe
    }

    private func addRow(_ keys: [UIView], fill: Bool) {
        let row = UIView()
        let stack = UIStackView(arrangedSubviews: keys)
        stack.axis = .horizontal
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)

        var c = [stack.topAnchor.constraint(equalTo: row.topAnchor),
                 stack.bottomAnchor.constraint(equalTo: row.bottomAnchor)]
        if fill {
            c += [stack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                  stack.trailingAnchor.constraint(equalTo: row.trailingAnchor)]
        } else {
            c += [stack.centerXAnchor.constraint(equalTo: row.centerXAnchor)]
        }
        NSLayoutConstraint.activate(c)
        rowsStack.addArrangedSubview(row)
    }

    private func register(_ key: KeyButton) {
        allKeys.append(key)
        wire(key)
    }

    private func wire(_ key: KeyButton) {
        key.addTarget(self, action: #selector(touchDown(_:)), for: .touchDown)
        key.addTarget(self, action: #selector(touchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        key.addTarget(self, action: #selector(touchCancelled(_:)), for: .touchCancel)
    }

    // MARK: Emoji page (built once, the first time it is opened)

    private func makeEmojiPanel() -> UIView {
        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(panel)

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 2
        let list = UICollectionView(frame: .zero, collectionViewLayout: layout)
        list.backgroundColor = .clear
        list.dataSource = self
        list.delegate = self
        list.register(EmojiCell.self, forCellWithReuseIdentifier: "emoji")
        list.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(list)

        let abc = KeyButton(kind: .page, title: "ABC", output: "letters", function: true)
        let space = KeyButton(kind: .space, title: "space")
        let del = KeyButton(kind: .delete, icon: "delete.left", function: true)
        let ret = KeyButton(kind: .ret, icon: "return", function: true)
        emojiBarKeys = [abc, space, del, ret]
        emojiBarKeys.forEach { wire($0) }

        let bar = UIStackView(arrangedSubviews: emojiBarKeys)
        bar.axis = .horizontal
        bar.spacing = 6
        bar.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(bar)

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 3),
            panel.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -3),
            panel.topAnchor.constraint(equalTo: surface.topAnchor, constant: 6),
            panel.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -4),

            list.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            list.topAnchor.constraint(equalTo: panel.topAnchor),
            list.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -6),

            bar.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: 42),

            abc.widthAnchor.constraint(equalTo: panel.widthAnchor, multiplier: 0.15),
            del.widthAnchor.constraint(equalTo: panel.widthAnchor, multiplier: 0.15),
            ret.widthAnchor.constraint(equalTo: panel.widthAnchor, multiplier: 0.2),
        ])

        emojiPanel = panel
        emojiList = list
        return panel
    }

    // MARK: Touch handling
    //
    // Letters and space are typed when the finger lifts OR when the next key
    // goes down, whichever comes first. That keeps letters in the right order
    // when typing fast with two thumbs.

    @objc private func touchDown(_ key: KeyButton) {
        commitPending()
        feedback.keyDown(big: key.kind == .space || key.kind == .ret || key.kind == .delete)

        switch key.kind {
        case .char, .space:
            pendingKey = key
            longPressFired = false
            if key.kind == .char { showPopup(key.output, over: key) }
            if let alt = key.alternate {
                let delay = settings.longPressMs / 1000
                let timer = Timer(timeInterval: delay, repeats: false) { [weak self, weak key] _ in
                    guard let self = self, let key = key, key === self.pendingKey else { return }
                    self.longPressFired = true
                    Haptics.play(self.settings.longHaptic)
                    self.showPopup(alt, over: key)
                }
                RunLoop.main.add(timer, forMode: .common)
                longPressTimer = timer
            }
        case .delete:
            if undoCorrection() { return }      // delete right after auto-correct = undo it
            proxy.deleteBackward()
            deleteTimer?.invalidate()
            let timer = Timer(fire: Date().addingTimeInterval(0.4), interval: 0.07,
                              repeats: true) { [weak self] _ in
                self?.proxy.deleteBackward()
            }
            RunLoop.main.add(timer, forMode: .common)
            deleteTimer = timer
        default:
            break
        }
    }

    @objc private func touchUp(_ key: KeyButton) {
        switch key.kind {
        case .char, .space:
            if key === pendingKey { commitPending() }   // otherwise already typed
        case .delete:
            stopDeleting()
            updateAutoShift()
            refreshSuggestions()
        case .ret:
            proxy.insertText("\n")
            lastCorrection = nil
            manualShift = false
            updateAutoShift()
            refreshSuggestions()
        case .shift:
            tapShift()
        case .page:
            switchPage(key.output)
        case .globe:
            break
        }
    }

    @objc private func touchCancelled(_ key: KeyButton) {
        if key === pendingKey {
            pendingKey = nil
            longPressFired = false
            longPressTimer?.invalidate()
            longPressTimer = nil
            hidePopup()
        }
        if key.kind == .delete { stopDeleting() }
    }

    private func commitPending() {
        guard let key = pendingKey else { return }
        let wasLong = longPressFired
        pendingKey = nil
        longPressFired = false
        longPressTimer?.invalidate()
        longPressTimer = nil
        hidePopup()

        if key.kind == .space {
            typeSpace()
        } else {
            type(wasLong ? (key.alternate ?? key.output) : key.output)
        }
    }

    private func stopDeleting() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }

    /// Drops anything in progress without typing it.
    private func cancelTouches() {
        pendingKey = nil
        longPressFired = false
        longPressTimer?.invalidate()
        longPressTimer = nil
        stopDeleting()
        hidePopup()
    }

    // MARK: Actions

    private func type(_ text: String) {
        proxy.insertText(text)
        lastCorrection = nil
        manualShift = false
        if shift == .on {
            shift = .off
            refreshCase()
        }
        updateAutoShift()
        refreshSuggestions()
    }

    private func typeSpace() {
        let now = Date()
        let before = proxy.documentContextBeforeInput ?? ""
        let fieldType = proxy.keyboardType ?? .default
        let plainText = !(fieldType == .URL || fieldType == .emailAddress || fieldType == .webSearch)

        // Auto-correct the word that was just finished, then learn it.
        let context = wordContext()
        var finished = context.word
        lastCorrection = nil
        if settings.autocorrectOn, plainText,
           (proxy.autocorrectionType ?? .default) != .no,
           !rejectedCorrections.contains(context.word.lowercased()),
           let fix = engine.correction(for: context.word, custom: settings.customWords) {
            for _ in 0..<context.word.count { proxy.deleteBackward() }
            proxy.insertText(fix)
            lastCorrection = (context.word, fix)
            finished = fix
        }
        if settings.effectiveHistory, plainText, !finished.isEmpty {
            engine.learn(finished, previous: context.previous)
        }

        if plainText,
           now.timeIntervalSince(lastSpaceTap) < 0.45,
           before.hasSuffix(" "),
           let prev = before.dropLast().last, prev.isLetter || prev.isNumber {
            proxy.deleteBackward()
            proxy.insertText(". ")
            lastSpaceTap = .distantPast
        } else {
            proxy.insertText(" ")
            lastSpaceTap = now
        }
        manualShift = false
        updateAutoShift()
        refreshSuggestions()
    }

    private func tapShift() {
        let now = Date()
        if shift == .locked {
            shift = .off
        } else if shift == .on && now.timeIntervalSince(lastShiftTap) < 0.35 {
            shift = .locked                       // double-tap = caps lock
        } else {
            shift = (shift == .on) ? .off : .on
        }
        lastShiftTap = now
        manualShift = true
        refreshCase()
    }

    private func switchPage(_ target: String) {
        switch target {
        case "symbols": page = .symbols
        case "more":    page = .more
        case "emoji":   page = .emoji
        default:        page = .letters
        }
        buildKeyboard()
        updateAutoShift()
        refreshSuggestions()
    }

    private func refreshCase() {
        guard page == .letters else { return }
        for key in letterKeys {
            let s = (shift == .off) ? key.base : key.base.uppercased()
            key.output = s
            key.setTitle(s)
        }
        shiftKey?.setIcon(shift == .locked ? "capslock.fill" : shift == .on ? "shift.fill" : "shift")
        shiftKey?.setFunction(shift == .off)
    }

    private func updateAutoShift() {
        guard page == .letters, shift != .locked, !manualShift else { return }
        let mode = proxy.autocapitalizationType ?? .sentences
        let before = proxy.documentContextBeforeInput ?? ""
        let want: Bool
        switch mode {
        case .allCharacters:
            want = true
        case .words:
            want = before.isEmpty || before.last?.isWhitespace == true
        case .sentences:
            want = isSentenceStart(before)
        default:
            want = false
        }
        let newShift: Shift = want ? .on : .off
        if newShift != shift {
            shift = newShift
            refreshCase()
        }
    }

    private func isSentenceStart(_ before: String) -> Bool {
        guard let last = before.last else { return true }       // empty field
        if last.isNewline { return true }
        guard last == " " else { return false }
        var text = Substring(before)
        while text.last == " " { text.removeLast() }
        guard let end = text.last else { return true }
        return end == "." || end == "!" || end == "?" || end.isNewline
    }

    // MARK: Suggestion bar

    private func setUpSuggestionBar() {
        suggestionBar.axis = .horizontal
        suggestionBar.spacing = 4
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(suggestionBar)

        let gear = UIButton(type: .system)
        gear.setImage(UIImage(systemName: "gearshape"), for: .normal)
        gear.tintColor = .secondaryLabel
        gear.addAction(UIAction { [weak self] _ in self?.openSettings() }, for: .touchUpInside)
        suggestionBar.addArrangedSubview(gear)

        let slots = UIStackView()
        slots.axis = .horizontal
        slots.distribution = .fillEqually
        for index in 0..<3 {
            let button = UIButton(type: .system)
            button.setTitleColor(.label, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16)
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.addAction(UIAction { [weak self] _ in self?.applySuggestion(index) },
                             for: .touchUpInside)
            slots.addArrangedSubview(button)
            suggestionButtons.append(button)
        }
        suggestionBar.addArrangedSubview(slots)

        NSLayoutConstraint.activate([
            gear.widthAnchor.constraint(equalToConstant: 40),
            suggestionBar.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 3),
            suggestionBar.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -3),
            suggestionBar.topAnchor.constraint(equalTo: surface.topAnchor),
            suggestionBar.bottomAnchor.constraint(equalTo: rowsStack.topAnchor, constant: -2),
        ])
    }

    /// The word being typed and the word before it.
    private func wordContext() -> (word: String, previous: String?) {
        var chars = Array(proxy.documentContextBeforeInput ?? "")

        func takeWord() -> String {
            var taken: [Character] = []
            while let c = chars.last, c.isLetter || c == "'" || c == "’" {
                taken.append(c)
                chars.removeLast()
            }
            return String(taken.reversed())
        }

        let word = takeWord()
        guard chars.last == " " else { return (word, nil) }
        while chars.last == " " { chars.removeLast() }
        let previous = takeWord()
        return (word, previous.isEmpty ? nil : previous)
    }

    private func refreshSuggestions() {
        guard page != .emoji, page != .settings else { return }
        var list: [Suggestion] = []

        if settings.suggestionsOn {
            let context = wordContext()
            let custom = settings.customWords
            // Unknown word: offer to add it to the dictionary.
            if context.word.count >= 2, context.word.allSatisfy({ $0.isLetter }),
               !engine.isKnown(context.word, custom: custom) {
                list.append(Suggestion(title: "+ " + context.word, text: context.word, isAdd: true))
            }
            let words = engine.suggestions(prefix: context.word, previous: context.previous,
                                           custom: custom, useHistory: settings.effectiveHistory)
            for word in words where list.count < 3 {
                list.append(Suggestion(title: word, text: word, isAdd: false))
            }
        }

        suggestions = list
        UIView.performWithoutAnimation {
            for (index, button) in suggestionButtons.enumerated() {
                button.setTitle(index < list.count ? list[index].title : "", for: .normal)
                button.isEnabled = index < list.count
                button.layoutIfNeeded()
            }
        }
    }

    private func applySuggestion(_ index: Int) {
        guard index < suggestions.count else { return }
        let choice = suggestions[index]
        cancelTouches()
        feedback.keyDown(big: false)

        if choice.isAdd {
            var words = settings.customWords
            if !words.contains(where: { $0.lowercased() == choice.text.lowercased() }) {
                words.append(choice.text)
                settings.customWords = words
            }
            refreshSuggestions()
            return
        }

        let context = wordContext()
        for _ in 0..<context.word.count { proxy.deleteBackward() }
        proxy.insertText(choice.text + " ")
        if settings.effectiveHistory { engine.learn(choice.text, previous: context.previous) }

        lastCorrection = nil
        manualShift = false
        if shift == .on {
            shift = .off
            refreshCase()
        }
        updateAutoShift()
        refreshSuggestions()
    }

    /// Pressing delete straight after an auto-correction puts the original word back.
    private func undoCorrection() -> Bool {
        guard let change = lastCorrection else { return false }
        lastCorrection = nil
        let before = proxy.documentContextBeforeInput ?? ""
        guard before.hasSuffix(change.corrected + " ") else { return false }

        for _ in 0..<(change.corrected.count + 1) { proxy.deleteBackward() }
        proxy.insertText(change.original + " ")
        rejectedCorrections.insert(change.original.lowercased())
        updateAutoShift()
        refreshSuggestions()
        return true
    }

    // MARK: Settings

    /// Light or dark keys regardless of the iPhone's setting, or follow the iPhone.
    private func applyTheme() {
        switch settings.theme {
        case 1:
            view.overrideUserInterfaceStyle = .light
            view.backgroundColor = UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)
        case 2:
            view.overrideUserInterfaceStyle = .dark
            view.backgroundColor = UIColor(white: 0.13, alpha: 1)
        default:
            view.overrideUserInterfaceStyle = .unspecified
            view.backgroundColor = .clear
        }
    }

    private func openSettings() {
        page = .settings
        buildKeyboard()
    }

    private func closeSettings() {
        page = .letters
        applyMetrics(landscape: isLandscape ?? false)
        buildKeyboard()
        updateAutoShift()
        refreshSuggestions()
    }

    private func makeSettingsPanel() -> SettingsPanel {
        let panel = SettingsPanel(settings: settings)
        panel.onDone = { [weak self] in self?.closeSettings() }
        panel.onHeightChanged = { [weak self] in
            guard let self = self else { return }
            self.applyMetrics(landscape: self.isLandscape ?? false)
        }
        panel.onClearHistory = { [weak self] in self?.engine.clearHistory() }
        panel.onThemeChanged = { [weak self] in self?.applyTheme() }
        panel.onFeedbackChanged = { [weak self] in
            guard let self = self else { return }
            self.feedback.reload(self.settings)
            self.feedback.keyDown(big: false)       // play a sample of the new feel
        }
        surface.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 3),
            panel.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -3),
            panel.topAnchor.constraint(equalTo: surface.topAnchor, constant: 6),
            panel.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -4),
        ])
        settingsPanel = panel
        return panel
    }

    // MARK: Popup

    private func showPopup(_ text: String, over key: KeyButton) {
        let f = key.convert(key.bounds, to: view)
        let w = max(f.width + 12, 46)
        let h = topInset - 2
        let x = min(max(2, f.midX - w / 2), view.bounds.width - w - 2)
        let y = max(0, f.minY - h - 2)
        popup.frame = CGRect(x: x, y: y, width: w, height: h)
        popup.text = text
        popup.isHidden = false
        view.bringSubviewToFront(popup)
    }

    private func hidePopup() { popup.isHidden = true }
}

// MARK: - Emoji list

extension KeyboardViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        emojis.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "emoji", for: indexPath)
        (cell as? EmojiCell)?.label.text = emojis[indexPath.item]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = collectionView.bounds.width > 500 ? 14 : 8
        let side = floor(collectionView.bounds.width / columns)
        return CGSize(width: max(side, 30), height: 40)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        feedback.keyDown(big: false)
        proxy.insertText(emojis[indexPath.item])
    }
}
