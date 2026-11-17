//
//  KeyboardViewController.swift
//  Keyboard Pro for iPhone  (version 12)
//
//  - Number row always on top
//  - Long-press any letter to type a symbol (hint shown in the key corner)
//  - Emoji page with categories (smiley key on the bottom row)
//  - Shortcut keys: either side of the space bar (, and .) and at the end
//    of the A–L row (Paste)
//  - Hold shift to turn on caps lock (or double-tap it)
//  - Suggestion bar: word completion, auto-correct, add words, paste copied code
//  - Settings (gear button): theme, switch sound + vibration, Max options
//  - Glass theme: frosted Liquid Glass keys on iOS 26 (follows the iPhone's
//    Clear / Tinted setting), frosted blur keys on older iOS
//  - Key preview popup, shift / caps lock (double-tap), hold-to-delete,
//    double-space for ". ", auto-capitalise, ?123 and =\< symbol pages
//
//  Requires iOS 15 or later (every iPhone 12 and newer can run it).
//

import UIKit

// MARK: - Glass look

/// Builds the frosted glass behind each key in the Glass theme.
/// iOS 26: real Liquid Glass (UIGlassEffect). iOS automatically applies the
/// user's Settings > Display & Brightness > Liquid Glass choice (Clear / Tinted).
/// iOS 15–18: a thin blur material. Either way a light frost tint is laid on top
/// so letters stay easy to read over busy backgrounds.
enum KeyGlass {
    static let cornerRadius: CGFloat = 8.5

    /// The frost tint. Character keys are lighter than function keys, like the
    /// system keyboard. Raise the alpha values for more frost, lower for clearer glass.
    static func frost(function: Bool, dark: Bool) -> UIColor {
        switch (function, dark) {
        case (false, false): return UIColor(white: 1.0, alpha: 0.55)
        case (true, false):  return UIColor(red: 0.62, green: 0.65, blue: 0.70, alpha: 0.40)
        case (false, true):  return UIColor(white: 0.55, alpha: 0.30)
        case (true, true):   return UIColor(white: 0.18, alpha: 0.40)
        }
    }

    static func apply(to view: UIVisualEffectView, function: Bool, dark: Bool) {
        let tint = frost(function: function, dark: dark)
        #if compiler(>=6.2)     // built with Xcode 26 or later
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)   // .regular is the frosted style
            glass.tintColor = tint
            UIView.performWithoutAnimation { view.effect = glass }
            return
        }
        #endif
        view.effect = UIBlurEffect(style: dark ? .systemThinMaterialDark : .systemThinMaterialLight)
        view.contentView.backgroundColor = tint
    }
}

// MARK: - Key view

final class KeyButton: UIControl {
    enum Kind { case char, shift, delete, page, globe, space, ret, paste }

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

    /// Look of every key, set by the keyboard theme. Changing it restyles
    /// keys that already exist (emoji bar, current page) straight away.
    enum Style { case solid, glass }
    static var style: Style = .solid {
        didSet { if style != oldValue { NotificationCenter.default.post(name: styleChanged, object: nil) } }
    }
    static let styleChanged = Notification.Name("KeyButton.styleChanged")

    private var glassView: UIVisualEffectView?
    private var glassLook: (function: Bool, dark: Bool)?

    /// Glass is skipped when Reduce Transparency is on (Accessibility setting).
    private var usesGlass: Bool {
        Self.style == .glass && !UIAccessibility.isReduceTransparencyEnabled
    }

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
        NotificationCenter.default.addObserver(self, selector: #selector(styleDidChange),
                                               name: Self.styleChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(styleDidChange),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // An explicit shadow path lets iOS draw the shadow cheaply.
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            glassLook = nil
            updateColor()
        }
    }

    @objc private func styleDidChange() { applyStyle() }

    /// Switches between solid keys and frosted glass keys.
    private func applyStyle() {
        let glass = usesGlass
        let radius: CGFloat = glass ? KeyGlass.cornerRadius : 6
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        layer.shadowOpacity = glass ? 0 : 0.25      // glass casts no hard shadow
        if glass, glassView == nil {
            let v = UIVisualEffectView(effect: nil)
            v.isUserInteractionEnabled = false
            v.frame = bounds
            v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            v.layer.cornerRadius = radius
            v.layer.cornerCurve = .continuous
            v.clipsToBounds = true
            insertSubview(v, at: 0)                 // behind the labels
            glassView = v
        } else if !glass {
            glassView?.removeFromSuperview()
            glassView = nil
        }
        glassLook = nil
        setNeedsLayout()
        updateColor()
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
        let functionLook = (isFunctionKey != pressed)
        if let glassView = glassView {
            backgroundColor = .clear
            let look = (function: functionLook, dark: traitCollection.userInterfaceStyle == .dark)
            if glassLook?.function != look.function || glassLook?.dark != look.dark {
                glassLook = look
                KeyGlass.apply(to: glassView, function: look.function, dark: look.dark)
            }
        } else {
            backgroundColor = functionLook ? Self.functionColor : Self.normalColor
        }
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

    func show(_ text: String, isText: Bool) {
        label.text = text
        label.font = isText ? .systemFont(ofSize: 13, weight: .medium) : .systemFont(ofSize: 28)
        label.adjustsFontSizeToFitWidth = isText
        label.minimumScaleFactor = 0.6
        label.textColor = .label
    }
}

final class EmojiHeader: UICollectionReusableView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.frame = bounds.insetBy(dx: 6, dy: 0)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(label)
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

    // Emoji shown on the emoji page: see EmojiData.swift.
    private let emojiGroups = EmojiData.groups

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
    private var emojiBar: UIView?
    private var emojiTabs: UIView?
    private var emojiTabButtons: [UIButton] = []
    private var pickBanner: UIView?
    private let pickLabel = UILabel()
    /// Set while choosing an emoji for a space-bar key (0 = left, 1 = right).
    private var pickingKeySide: Int?
    private var settingsStart = SettingsPanel.Start.main

    private var settingsPanel: SettingsPanel?
    private let suggestionBar = UIStackView()
    private var suggestionButtons: [UIButton] = []
    private var suggestions: [Suggestion] = []
    private var lastCorrection: (original: String, corrected: String)?
    private var rejectedCorrections = Set<String>()
    private var clipboardHasCode = false
    private var lastClipboardChange = -1

    private weak var pendingKey: KeyButton?   // key held down but not typed yet
    private var longPressFired = false
    private var longPressTimer: Timer?
    private var deleteTimer: Timer?
    private var shiftHoldTimer: Timer?
    private var shiftLockedByHold = false
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
        pickingKeySide = nil
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
            let picking = (pickingKeySide != nil)
            pickBanner?.isHidden = !picking
            emojiBar?.isHidden = picking
            if let side = pickingKeySide {
                pickLabel.text = "Emoji for: \(KBSettings.shortcutNames[side])"
            }
            surface.keys = picking ? [] : emojiBarKeys
            surface.passthroughs = [emojiList as UIView?, emojiTabs, pickBanner].compactMap { $0 }
            return
        }
        if page == .settings {
            let panel = settingsPanel ?? makeSettingsPanel()
            panel.isHidden = false
            panel.reload(hasFullAccess: hasFullAccess, start: settingsStart)
            settingsStart = .main
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

        // Shortcut keys (settings: Shortcut keys). Typed as-is, never shifted.
        func shortcutKey(_ text: String) -> KeyButton {
            let key = text == KBSettings.pasteAction
                ? KeyButton(kind: .paste, icon: "doc.on.clipboard", function: true)
                : KeyButton(kind: .char, title: text, output: text, function: true)
            register(key)
            width(key, 0.1)
            return key
        }

        // Number row, then rows 1 and 2. The A–L row ends with the third
        // shortcut key on the letters page.
        for (index, chars) in [numberRow, rows[0], rows[1]].enumerated() {
            let keys = chars.map { makeCharKey($0) }
            keys.forEach { width($0, 0.1) }
            if index == 2, page == .letters, settings.rowKeyShown {
                addRow(keys + [shortcutKey(settings.rowKey)], fill: false)
            } else {
                addRow(keys, fill: false)
            }
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

        // Bottom row: ?123 / ABC, emoji, (globe), left key, space, right key, return
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

        if settings.leftKeyShown { bottom.append(shortcutKey(settings.leftKey)) }

        let space = KeyButton(kind: .space, title: "space")
        register(space)
        bottom.append(space)

        if settings.rightKeyShown { bottom.append(shortcutKey(settings.rightKey)) }

        let ret = KeyButton(kind: .ret, icon: "return", function: true)
        register(ret)
        width(ret, 0.18)
        bottom.append(ret)
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

        // Shown only while choosing an emoji for a space-bar key.
        pickLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        pickLabel.textColor = .label
        pickLabel.adjustsFontSizeToFitWidth = true
        pickLabel.minimumScaleFactor = 0.7
        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        cancel.setContentHuggingPriority(.required, for: .horizontal)
        cancel.addAction(UIAction { [weak self] _ in self?.finishPicking(nil) }, for: .touchUpInside)
        let banner = UIStackView(arrangedSubviews: [pickLabel, cancel])
        banner.axis = .horizontal
        banner.spacing = 8
        banner.isLayoutMarginsRelativeArrangement = true
        banner.layoutMargins = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        banner.isHidden = true

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 2
        let list = UICollectionView(frame: .zero, collectionViewLayout: layout)
        list.backgroundColor = .clear
        list.dataSource = self
        list.delegate = self
        list.register(EmojiCell.self, forCellWithReuseIdentifier: "emoji")
        list.register(EmojiHeader.self,
                      forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                      withReuseIdentifier: "header")

        // Category tabs: tap to jump to a group.
        let tabs = UIStackView()
        tabs.axis = .horizontal
        tabs.distribution = .fillEqually
        emojiTabButtons = emojiGroups.enumerated().map { (index, group) -> UIButton in
            let tab = UIButton(type: .system)
            tab.setTitle(group.tab, for: .normal)
            tab.titleLabel?.font = .systemFont(ofSize: 18)
            tab.layer.cornerRadius = 6
            tab.addAction(UIAction { [weak self] _ in self?.jumpToEmojiGroup(index) },
                          for: .touchUpInside)
            tabs.addArrangedSubview(tab)
            return tab
        }

        let abc = KeyButton(kind: .page, title: "ABC", output: "letters", function: true)
        let space = KeyButton(kind: .space, title: "space")
        let del = KeyButton(kind: .delete, icon: "delete.left", function: true)
        let ret = KeyButton(kind: .ret, icon: "return", function: true)
        emojiBarKeys = [abc, space, del, ret]
        emojiBarKeys.forEach { wire($0) }

        let bar = UIStackView(arrangedSubviews: emojiBarKeys)
        bar.axis = .horizontal
        bar.spacing = 6

        let column = UIStackView(arrangedSubviews: [banner, list, tabs, bar])
        column.axis = .vertical
        column.spacing = 4
        column.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(column)

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 3),
            panel.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -3),
            panel.topAnchor.constraint(equalTo: surface.topAnchor, constant: 6),
            panel.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -4),

            column.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            column.topAnchor.constraint(equalTo: panel.topAnchor),
            column.bottomAnchor.constraint(equalTo: panel.bottomAnchor),

            softHeight(banner, 30),
            softHeight(tabs, 30),
            softHeight(bar, 42),

            abc.widthAnchor.constraint(equalTo: panel.widthAnchor, multiplier: 0.15),
            del.widthAnchor.constraint(equalTo: panel.widthAnchor, multiplier: 0.15),
            ret.widthAnchor.constraint(equalTo: panel.widthAnchor, multiplier: 0.2),
        ])

        emojiPanel = panel
        emojiList = list
        emojiBar = bar
        emojiTabs = tabs
        pickBanner = banner
        highlightEmojiTab(0)
        return panel
    }

    private func softHeight(_ view: UIView, _ value: CGFloat) -> NSLayoutConstraint {
        let c = view.heightAnchor.constraint(equalToConstant: value)
        c.priority = UILayoutPriority(999)
        return c
    }

    private func jumpToEmojiGroup(_ section: Int) {
        guard let list = emojiList, section < emojiGroups.count,
              !emojiGroups[section].items.isEmpty else { return }
        list.layoutIfNeeded()
        let first = IndexPath(item: 0, section: section)
        if let header = list.layoutAttributesForSupplementaryElement(
            ofKind: UICollectionView.elementKindSectionHeader, at: first) {
            let maxY = max(0, list.contentSize.height - list.bounds.height)
            list.setContentOffset(CGPoint(x: 0, y: min(header.frame.minY, maxY)), animated: false)
        } else {
            list.scrollToItem(at: first, at: .top, animated: false)
        }
        highlightEmojiTab(section)
    }

    private func highlightEmojiTab(_ section: Int) {
        for (index, tab) in emojiTabButtons.enumerated() {
            tab.backgroundColor = index == section ? KeyButton.functionColor : .clear
        }
    }

    /// Picking an emoji for a space-bar key: called with the emoji, or nil to cancel.
    private func finishPicking(_ value: String?) {
        guard let side = pickingKeySide else { return }
        if let value = value {
            settings.setShortcutKey(side, value)
        }
        pickingKeySide = nil
        settingsStart = .spaceKeys
        page = .settings
        buildKeyboard()
    }

    // MARK: Touch handling
    //
    // Letters and space are typed when the finger lifts OR when the next key
    // goes down, whichever comes first. That keeps letters in the right order
    // when typing fast with two thumbs.

    @objc private func touchDown(_ key: KeyButton) {
        commitPending()
        if key.kind != .shift {
            // Another key while shift is held: it's shift+letter, not a hold for caps lock.
            shiftHoldTimer?.invalidate()
            shiftHoldTimer = nil
        }
        switch key.kind {
        case .space:  feedback.keyDown(.space)
        case .ret:    feedback.keyDown(.enter)
        case .delete: feedback.keyDown(.delete)
        default:      feedback.keyDown()
        }

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
        case .shift:
            // Holding shift for the long-press time turns on caps lock.
            shiftHoldTimer?.invalidate()
            shiftLockedByHold = false
            let timer = Timer(timeInterval: settings.longPressMs / 1000, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.shiftHoldTimer = nil
                self.shiftLockedByHold = true
                self.shift = .locked
                self.manualShift = true
                self.refreshCase()
                Haptics.play(self.settings.longHaptic)
            }
            RunLoop.main.add(timer, forMode: .common)
            shiftHoldTimer = timer
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
            shiftHoldTimer?.invalidate()
            shiftHoldTimer = nil
            if shiftLockedByHold {
                shiftLockedByHold = false      // already locked by holding: leave it on
            } else {
                tapShift()
            }
        case .page:
            switchPage(key.output)
        case .paste:
            pasteClipboard()
        case .globe:
            break
        }
    }

    /// The Paste shortcut key: types whatever text was copied.
    private func pasteClipboard() {
        guard hasFullAccess else {
            flashMessage("Turn on Full Access to paste")
            return
        }
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            flashMessage("Nothing copied")
            return
        }
        proxy.insertText(text)
        lastCorrection = nil
        manualShift = false
        updateAutoShift()
        refreshSuggestions()
    }

    /// Shows a short message in the suggestion bar for a moment.
    private func flashMessage(_ text: String) {
        guard let slot = suggestionButtons.first else { return }
        UIView.performWithoutAnimation {
            slot.setTitle(text, for: .normal)
            slot.layoutIfNeeded()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshSuggestions()
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
        if key.kind == .shift {
            shiftHoldTimer?.invalidate()
            shiftHoldTimer = nil
            shiftLockedByHold = false
        }
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
        shiftHoldTimer?.invalidate()
        shiftHoldTimer = nil
        shiftLockedByHold = false
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
        if pickingKeySide != nil {
            finishPicking(nil)
            return
        }
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
        // 14 pt is 20% smaller than the 17 pt default; the 40 pt tap area stays.
        gear.setImage(UIImage(systemName: "gearshape",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)),
                      for: .normal)
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
        checkClipboard()
        var list: [Suggestion] = []
        if clipboardHasCode {
            list.append(Suggestion(title: "Paste code", text: "", isAdd: false, isPaste: true))
        }

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
        feedback.keyDown()

        if choice.isPaste {
            pasteCode()
            return
        }
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

    // MARK: Paste a copied code (for example a one-time code from Messages)

    /// Looks at the clipboard only when it has changed. This asks iOS whether
    /// the copied text contains a number without reading the text itself, so
    /// iOS shows no paste prompt until the button is actually tapped.
    private func checkClipboard() {
        guard settings.pasteCodesOn, hasFullAccess else {
            clipboardHasCode = false
            return
        }
        let board = UIPasteboard.general
        let change = board.changeCount
        guard change != lastClipboardChange else { return }
        lastClipboardChange = change
        clipboardHasCode = false
        guard board.hasStrings else { return }

        board.detectPatterns(for: [.number]) { [weak self] result in
            let found = ((try? result.get())?.contains(.number)) ?? false
            DispatchQueue.main.async {
                guard let self = self, found, change == self.lastClipboardChange else { return }
                self.clipboardHasCode = true
                self.refreshSuggestions()
            }
        }
    }

    private func pasteCode() {
        clipboardHasCode = false            // the button goes away until something new is copied
        if let code = Self.extractCode(UIPasteboard.general.string ?? "") {
            proxy.insertText(code)
            lastCorrection = nil
        }
        refreshSuggestions()
    }

    /// A 4–8 digit code: the whole copied text ("123 456", "123-456"), or the
    /// first run of 4–8 digits inside a longer copied message.
    private static func extractCode(_ text: String) -> String? {
        func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }

        let compact = text.filter { !($0.isWhitespace || $0 == "-") }
        if (4...8).contains(compact.count), compact.allSatisfy(isDigit) { return compact }

        var runs: [String] = []
        var current = ""
        for c in text {
            if isDigit(c) {
                current.append(c)
            } else if !current.isEmpty {
                runs.append(current)
                current = ""
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs.first { (4...8).contains($0.count) }
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

    /// Light or dark keys regardless of the iPhone's setting, follow the iPhone,
    /// or frosted glass keys (which also follow the iPhone's light / dark mode).
    private func applyTheme() {
        KeyButton.style = (settings.theme == 3) ? .glass : .solid
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
        pickingKeySide = nil
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
        panel.onPickEmoji = { [weak self] side in
            guard let self = self else { return }
            self.pickingKeySide = side
            self.page = .emoji
            self.buildKeyboard()
        }
        panel.onFeedbackChanged = { [weak self] in
            guard let self = self else { return }
            self.feedback.reload(self.settings)
            self.feedback.keyDown()       // play a sample of the new feel
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

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        emojiGroups.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        emojiGroups[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "emoji", for: indexPath)
        let group = emojiGroups[indexPath.section]
        (cell as? EmojiCell)?.show(group.items[indexPath.item], isText: group.isText)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: "header", for: indexPath)
        (view as? EmojiHeader)?.label.text = emojiGroups[indexPath.section].title
        return view
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: 22)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = collectionView.bounds.width > 500 ? 14 : 8
        let side = max(floor(collectionView.bounds.width / columns), 30)
        // WeChat text codes are wider: two emoji cells each.
        let wide = emojiGroups[indexPath.section].isText
        return CGSize(width: wide ? side * 2 : side, height: 40)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        feedback.keyDown()
        let value = emojiGroups[indexPath.section].items[indexPath.item]
        if pickingKeySide != nil {
            finishPicking(value)
        } else {
            proxy.insertText(value)
        }
    }

    /// Keeps the category tab in step with the group being looked at.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === emojiList, let list = emojiList else { return }
        let probe = CGPoint(x: 10, y: list.contentOffset.y + 30)
        if let path = list.indexPathForItem(at: probe) {
            highlightEmojiTab(path.section)
        }
    }
}
