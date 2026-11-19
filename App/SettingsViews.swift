//
//  SettingsViews.swift
//  The keyboard's settings, shown in the Keyboard Pro app. Same options as the
//  in-keyboard settings (Keyboard/SettingsPanel.swift); both read and write
//  KBSettings, which the app and the keyboard share through an App Group.
//
//  Styled like the iPhone's own Settings app:
//  - grouped lists, explanations in the grey footer under a section
//  - title on the left, current value in grey on the right, chevron to open
//  - choices are lists with a blue checkmark (picking does not leave the page)
//  - sliders have small icons at each end
//

import SwiftUI

// MARK: - Store

/// Wraps KBSettings so SwiftUI redraws when a setting changes, and tells the
/// keyboard (through `revision`) that it should reload.
final class SettingsStore: ObservableObject {
    let s = KBSettings.shared

    /// A two-way link to one setting. `after` runs once the new value is saved.
    func binding<T>(_ key: ReferenceWritableKeyPath<KBSettings, T>,
                    after: (() -> Void)? = nil) -> Binding<T> {
        Binding(
            get: { self.s[keyPath: key] },
            set: { value in
                self.update { $0[keyPath: key] = value }
                after?()
            })
    }

    /// Changes one or more settings at once.
    func update(_ change: (KBSettings) -> Void) {
        objectWillChange.send()
        change(s)
        s.revision += 1
    }

    /// Plays one key press with the current sound and vibration.
    func playFeel(_ key: KeySound = .generic) {
        SwitchFeedback.shared.reload(s)
        SwitchFeedback.shared.keyDown(key)
    }

    var themeName: String {
        KBSettings.themeNames[min(max(s.theme, 0), KBSettings.themeNames.count - 1)]
    }
    var feelName: String {
        TacPreset.current(s)?.title ?? SoundPack.named(s.effectiveFeel.pack).title
    }
    func keyName(_ index: Int) -> String {
        s.shortcutShown(index) ? KBSettings.displayName(s.shortcutKey(index)) : "–"
    }
    var actionKeysSummary: String {
        (0...2).map(keyName).joined(separator: "  ")
    }
    var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Keyboard Pro \(version) (\(build))"
    }
}

// MARK: - Appearance

struct AppearanceView: View {
    @EnvironmentObject var store: SettingsStore

    static let themeChoices: [Choice<Int>] = [
        Choice(0, "Auto", "Light or dark, following the iPhone"),
        Choice(1, "Light"),
        Choice(2, "Dark"),
        Choice(3, "Glass", "Frosted keys, following the iPhone"),
    ]
    static let oneHandedChoices: [Choice<Int>] = [
        Choice(0, "Off"), Choice(1, "Left"), Choice(2, "Right"),
    ]

    var body: some View {
        let isMax = store.s.maxUnlocked
        Form {
            Section(header: Text("Theme")) {
                ChoiceRows(choices: Self.themeChoices, current: { store.s.theme }) { value in
                    store.update { $0.theme = value }
                }
            }

            Section(footer: Text("When off, the keyboard is shorter and holding q–p types 1–0. The ?123 page always shows numbers.")) {
                Toggle("Number Row", isOn: store.binding(\.showNumberRow))
            }

            Section(footer: Text("Pushes the keys to one side. Use the arrows beside the keys to switch sides or go back to full width. Off in landscape.")) {
                NavigationLink(destination: ChoiceList(
                    title: "One-Handed Keyboard",
                    sections: [ChoiceSection(choices: Self.oneHandedChoices)],
                    current: { store.s.oneHanded },
                    pick: { value in store.update { $0.oneHanded = value } })) {
                    ValueRow(title: "One-Handed Keyboard",
                             value: Self.oneHandedChoices[min(max(store.s.oneHanded, 0), 2)].title)
                }
            }

            Section(header: MaxHeader(title: "Keyboard Height")) {
                ValueRow(title: "Height", value: "\(Int((store.s.heightScale * 100).rounded()))%")
                IconSlider(value: store.binding(\.heightScale), range: 0.85...1.25, step: 0.01,
                           low: "arrow.down.right.and.arrow.up.left",
                           high: "arrow.up.left.and.arrow.down.right")
            }
            .disabled(!isMax)
        }
        .navigationTitle("Appearance")
    }
}

// MARK: - Typing

struct TypingView: View {
    @EnvironmentObject var store: SettingsStore
    @State private var confirmClear = false

    static let vibrationChoices: [Choice<Int>] = [
        Choice(0, "Off"), Choice(1, "Light"), Choice(2, "Medium"), Choice(3, "Strong"),
    ]

    var body: some View {
        let isMax = store.s.maxUnlocked
        Form {
            Section(footer: Text("Smart Punctuation turns quotes into curly quotes and two hyphens into a dash. Paste Copied Codes offers a copied number, such as a sign-in code, above the keys.")) {
                Toggle("Word Suggestions", isOn: store.binding(\.suggestionsOn))
                Toggle("Auto-Correction", isOn: store.binding(\.autocorrectOn))
                Toggle("Emoji Suggestions", isOn: store.binding(\.emojiSuggestionsOn))
                Toggle("Calculator", isOn: store.binding(\.calculatorOn))
                Toggle("Smart Punctuation", isOn: store.binding(\.smartPunctuationOn))
                Toggle("Paste Copied Codes", isOn: store.binding(\.pasteCodesOn))
            }

            Section(footer: Text("Your iPhone's Text Replacements (Settings → General → Keyboard → Text Replacement) work in Keyboard Pro too.")) {
                NavigationLink(destination: WordsView()) {
                    ValueRow(title: "My Words", value: "\(store.s.customWords.count)")
                }
            }

            Section(header: MaxHeader(title: "Typing History"),
                    footer: Text("Suggests words you type often. Everything stays on this iPhone.")) {
                Toggle("Learn From My Typing", isOn: store.binding(\.historyOn))
                Button("Clear Typing History") { confirmClear = true }
                    .foregroundColor(isMax ? .red : .secondary)
            }
            .disabled(!isMax)

            Section(header: Text("Long Press"),
                    footer: Text("How long to hold a letter before it types its symbol.")) {
                Toggle("Symbol Hints on Keys", isOn: store.binding(\.showHints))
                NavigationLink(destination: ChoiceList(
                    title: "Vibration",
                    sections: [ChoiceSection(choices: Self.vibrationChoices)],
                    current: { store.s.longHaptic },
                    pick: { value in
                        store.update { $0.longHaptic = value }
                        Haptics.play(value)             // feel the chosen level
                    })) {
                    ValueRow(title: "Vibration",
                             value: Self.vibrationChoices[min(max(store.s.longHaptic, 0), 3)].title)
                }
                ValueRow(title: "Duration", value: "\(Int(store.s.longPressMs)) ms")
                IconSlider(value: store.binding(\.longPressMs), range: 150...800, step: 10,
                           low: "hare", high: "tortoise")
            }

            Section {
                NavigationLink(destination: RemapView()) {
                    HStack(spacing: 8) {
                        Text("Remap Symbols")
                        MaxBadge()
                    }
                }
                .disabled(!isMax)
            }
        }
        .navigationTitle("Typing")
        .confirmationDialog("Clear typing history?", isPresented: $confirmClear,
                            titleVisibility: .visible) {
            Button("Clear Typing History", role: .destructive) {
                store.update { $0.historyClearRequest += 1 }
            }
        } message: {
            Text("The keyboard forgets the words it learned the next time it opens.")
        }
    }
}

struct WordsView: View {
    @EnvironmentObject var store: SettingsStore
    @State private var newWord = ""

    var body: some View {
        Form {
            Section(footer: Text("You can also add a word while typing: type it, then tap “+ word” in the bar above the keys.")) {
                HStack {
                    TextField("Add Word", text: $newWord)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(trimmed.isEmpty)
                }
            }
            if !store.s.customWords.isEmpty {
                Section {
                    ForEach(store.s.customWords, id: \.self) { word in
                        Text(word)
                    }
                    .onDelete { offsets in
                        store.update { s in
                            var words = s.customWords
                            words.remove(atOffsets: offsets)
                            s.customWords = words
                        }
                    }
                }
            }
        }
        .navigationTitle("My Words")
        .toolbar { EditButton() }
    }

    private var trimmed: String { newWord.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func add() {
        let word = trimmed
        guard !word.isEmpty else { return }
        store.update { s in
            if !s.customWords.contains(word) { s.customWords = s.customWords + [word] }
        }
        newWord = ""
    }
}

struct RemapView: View {
    @EnvironmentObject var store: SettingsStore
    @State private var confirmReset = false

    private static let letters = "qwertyuiopasdfghjklzxcvbnm".map { String($0) }

    var body: some View {
        let symbols = store.s.effectiveSymbols
        Form {
            Section(footer: Text("Choose the symbol each letter types when you hold it.")) {
                ForEach(Self.letters, id: \.self) { letter in
                    NavigationLink(destination: ChoiceList(
                        title: "Symbol for “\(letter)”",
                        sections: [ChoiceSection(choices: KBSettings.symbolChoices.map { Choice($0, $0) })],
                        current: { store.s.effectiveSymbols[letter] ?? "" },
                        pick: { symbol in
                            store.update { s in
                                var map = s.symbolMap
                                map[letter] = symbol
                                s.symbolMap = map
                            }
                        })) {
                        ValueRow(title: letter, value: symbols[letter] ?? "")
                    }
                }
            }
            Section {
                Button("Reset Symbols", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle("Remap Symbols")
        .confirmationDialog("Reset all symbols to the defaults?", isPresented: $confirmReset,
                            titleVisibility: .visible) {
            Button("Reset Symbols", role: .destructive) {
                store.update { $0.symbolMap = [:] }
            }
        }
    }
}

// MARK: - Tac Tile (sound + vibration)

struct TacTileView: View {
    @EnvironmentObject var store: SettingsStore

    /// "10 PM", "7 AM" for the night-hours pickers.
    static func hourName(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h) \(hour < 12 ? "AM" : "PM")"
    }

    var body: some View {
        let isMax = store.s.maxUnlocked
        let feel = store.s.effectiveFeel
        Form {
            Section(header: Text("Volume"),
                    footer: feel.pack == "Apple"
                        ? Text("The Apple sound plays at your iPhone's volume; the slider only turns it off.")
                        : nil) {
                IconSlider(value: store.binding(\.soundVolume), range: 0...1, step: 0.01,
                           low: "speaker.fill", high: "speaker.wave.3.fill",
                           ended: { store.playFeel() })
            }

            // Presets set the sound and the vibration together. They are free.
            Section(header: Text("Presets")) {
                ChoiceRows(choices: TacPreset.all.map { Choice($0.title, $0.title, $0.summary) },
                           current: { TacPreset.current(store.s)?.title ?? "" }) { title in
                    guard let item = TacPreset.all.first(where: { $0.title == title }) else { return }
                    store.update {
                        $0.soundPack = item.pack
                        $0.tapHaptic = item.haptic
                    }
                    store.playFeel()
                }
            }

            // Max: choose any sound pack and any vibration separately.
            Section(header: MaxHeader(title: "Custom"),
                    footer: Text("Mix any key sound with any vibration.")) {
                NavigationLink(destination: ChoiceList(
                    title: "Sound",
                    sections: [ChoiceSection(choices: SoundPack.all.map { Choice($0.file, $0.title) })],
                    current: { store.s.effectiveFeel.pack },
                    pick: { file in
                        let haptic = store.s.effectiveFeel.haptic
                        store.update {
                            $0.soundPack = file
                            $0.tapHaptic = haptic
                        }
                        store.playFeel()
                    })) {
                    ValueRow(title: "Sound", value: SoundPack.named(feel.pack).title)
                }
                NavigationLink(destination: ChoiceList(
                    title: "Vibration",
                    sections: [ChoiceSection(choices: TapHaptic.choices.map { Choice($0.value, $0.title) })],
                    current: { store.s.effectiveFeel.haptic },
                    pick: { value in
                        let pack = store.s.effectiveFeel.pack
                        store.update {
                            $0.tapHaptic = value
                            $0.soundPack = pack
                        }
                        store.playFeel()
                    })) {
                    ValueRow(title: "Vibration",
                             value: TapHaptic.choices.first { $0.value == feel.haptic }?.title ?? "")
                }
            }
            .disabled(!isMax)

            // Adaptive Tac Tile: each press adjusts to how and where you type.
            Section(header: Text("Adaptive"),
                    footer: Text("Variation makes every press slightly different, like a real switch. Auto-quiet turns the sound off in password fields and lightens vibration in Low Power Mode.")) {
                Toggle("Natural Variation", isOn: store.binding(\.adaptiveVariation))
                Toggle("Auto-Quiet", isOn: store.binding(\.adaptiveQuiet))
                Toggle("Quiet at Night", isOn: store.binding(\.adaptiveNight))
                if store.s.adaptiveNight {
                    Picker("From", selection: store.binding(\.nightFrom)) {
                        ForEach(0..<24, id: \.self) { Text(Self.hourName($0)).tag($0) }
                    }
                    Picker("Until", selection: store.binding(\.nightTo)) {
                        ForEach(0..<24, id: \.self) { Text(Self.hourName($0)).tag($0) }
                    }
                }
            }

            Section(header: MaxHeader(title: "Adaptive"),
                    footer: Text("When you type fast, clicks get a little quieter and the vibration lighter.")) {
                Toggle("Soften When Typing Fast", isOn: store.binding(\.adaptiveFast))
            }
            .disabled(!isMax)

            Section(footer: Text("In the keyboard, sound and vibration need Allow Full Access.")) {
                Button("Play Sample") { store.playFeel() }
            }
        }
        .navigationTitle("Tac Tile")
        .onAppear { SwitchFeedback.shared.reload(store.s) }
    }
}

// MARK: - Action Keys

struct ActionKeysView: View {
    @EnvironmentObject var store: SettingsStore
    @State private var confirmReset = false

    var body: some View {
        Form {
            // One group per key: show it or not, then what it types.
            ForEach(0...2, id: \.self) { index in
                Section {
                    Toggle(KBSettings.shortcutNames[index], isOn: Binding(
                        get: { store.s.shortcutShown(index) },
                        set: { value in store.update { $0.setShortcutShown(index, value) } }))
                    NavigationLink(destination: ActionKeyPickView(index: index)) {
                        ValueRow(title: KBSettings.displayName(store.s.shortcutKey(index)),
                                 value: "Change")
                    }
                    .disabled(!store.s.shortcutShown(index))
                }
            }
            Section(footer: Text("A Paste key needs Allow Full Access.")) {
                Button("Reset to , . Paste", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle("Action Keys")
        .confirmationDialog("Reset Action Keys to , . Paste?", isPresented: $confirmReset,
                            titleVisibility: .visible) {
            Button("Reset Action Keys", role: .destructive) {
                store.update { s in
                    for index in 0...2 {
                        s.setShortcutKey(index, KBSettings.shortcutDefaults[index])
                        s.setShortcutShown(index, true)
                    }
                }
            }
        }
    }
}

struct ActionKeyPickView: View {
    let index: Int
    @EnvironmentObject var store: SettingsStore
    @State private var emoji = ""

    private static let symbols = [",", "."] + KBSettings.symbolChoices.filter { $0 != "," && $0 != "." }
    private static let numbers = (0...9).map { String($0) }
    private static let letters = "abcdefghijklmnopqrstuvwxyz".map { String($0) }

    var body: some View {
        let current = store.s.shortcutKey(index)
        let isListed = current == KBSettings.pasteAction
            || (Self.symbols + Self.numbers + Self.letters).contains(current)
        Form {
            Section {
                ChoiceRows(choices: [Choice(KBSettings.pasteAction, "Paste", "Pastes the copied text")],
                           current: { store.s.shortcutKey(index) }, pick: choose)
            }
            Section(header: Text("Emoji")) {
                if !isListed {
                    ChoiceRows(choices: [Choice(current, current)],
                               current: { store.s.shortcutKey(index) }, pick: choose)
                }
                HStack {
                    TextField("Type an Emoji", text: $emoji)
                        .onSubmit(chooseEmoji)
                    Button("Use", action: chooseEmoji)
                        .disabled(emoji.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section(header: Text("Symbols")) {
                ChoiceRows(choices: Self.symbols.map { Choice($0, $0) },
                           current: { store.s.shortcutKey(index) }, pick: choose)
            }
            Section(header: Text("Numbers")) {
                ChoiceRows(choices: Self.numbers.map { Choice($0, $0) },
                           current: { store.s.shortcutKey(index) }, pick: choose)
            }
            Section(header: Text("Letters")) {
                ChoiceRows(choices: Self.letters.map { Choice($0, $0) },
                           current: { store.s.shortcutKey(index) }, pick: choose)
            }
        }
        .navigationTitle(KBSettings.shortcutNames[index])
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chooseEmoji() {
        guard let first = emoji.trimmingCharacters(in: .whitespaces).first else { return }
        choose(String(first))
        emoji = ""
    }

    private func choose(_ value: String) {
        store.update { $0.setShortcutKey(index, value) }
    }
}

// MARK: - Building blocks (iPhone Settings look)

/// A white symbol on a coloured rounded square, like the icons in Settings.
struct SettingsIcon: View {
    let name: String
    let color: Color

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 29, height: 29)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color))
            .accessibilityHidden(true)
    }
}

/// One line of the home screen's settings list: icon, name, current value.
struct MenuRow: View {
    let icon: String
    let color: Color
    let title: String
    var value = ""

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(name: icon, color: color)
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

/// Title on the left, current value in grey on the right.
struct ValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The purple MAX label on paid features.
struct MaxBadge: View {
    var body: some View {
        Text("MAX")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.purple))
            .accessibilityLabel("Max feature")
    }
}

/// A section title followed by a MAX badge.
struct MaxHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            MaxBadge()
        }
    }
}

/// A slider with a small icon at each end, like Brightness or Key Repeat.
struct IconSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let low: String
    let high: String
    var ended: (() -> Void)? = nil

    var body: some View {
        Slider(value: $value, in: range, step: step,
               label: { EmptyView() },
               minimumValueLabel: { Image(systemName: low).foregroundColor(.secondary) },
               maximumValueLabel: { Image(systemName: high).foregroundColor(.secondary) },
               onEditingChanged: { editing in if !editing { ended?() } })
    }
}

/// One option in a list of choices.
struct Choice<Value: Hashable> {
    let value: Value
    let title: String
    var subtitle: String?

    init(_ value: Value, _ title: String, _ subtitle: String? = nil) {
        self.value = value
        self.title = title
        self.subtitle = subtitle
    }
}

struct ChoiceSection<Value: Hashable> {
    var header: String?
    let choices: [Choice<Value>]
}

/// Rows with a blue checkmark beside the current choice. Put inside a Section.
struct ChoiceRows<Value: Hashable>: View {
    @EnvironmentObject var store: SettingsStore     // redraws when a setting changes
    let choices: [Choice<Value>]
    let current: () -> Value
    let pick: (Value) -> Void

    var body: some View {
        let selected = current()
        ForEach(choices.indices, id: \.self) { i in
            let choice = choices[i]
            Button {
                pick(choice.value)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(choice.title).foregroundColor(.primary)
                        if let subtitle = choice.subtitle {
                            Text(subtitle).font(.footnote).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if choice.value == selected {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .accessibilityAddTraits(choice.value == selected ? .isSelected : [])
        }
    }
}

/// A page that is just a list of choices (opened from a row with a value).
struct ChoiceList<Value: Hashable>: View {
    let title: String
    let sections: [ChoiceSection<Value>]
    let current: () -> Value
    let pick: (Value) -> Void

    var body: some View {
        List {
            ForEach(sections.indices, id: \.self) { i in
                Section(header: sections[i].header.map { Text($0) }) {
                    ChoiceRows(choices: sections[i].choices, current: current, pick: pick)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
