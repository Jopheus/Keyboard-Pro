import SwiftUI

@main
struct KeyboardProApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// The app's home screen: how to turn the keyboard on, every keyboard setting
/// (the same ones as the gear on the keyboard), and a field to try it.
struct ContentView: View {
    @StateObject private var store = SettingsStore()
    @State private var text = ""
    @State private var confirmReset = false

    var body: some View {
        NavigationView {
            // Settings come first: the gear on the keyboard opens the app here.
            Form {
                if !store.s.isShared {
                    Section {
                        Label("Settings can't reach the keyboard", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("This copy of the app was installed without its App Group, so changes made here stay in the app. Use the gear on the keyboard instead, or reinstall with a tool that keeps App Groups.")
                            .font(.footnote)
                    }
                }

                Section(footer: Text("Changes show up the next time the keyboard opens. The keyboard needs Allow Full Access to read them, and for sound and vibration.")) {
                    NavigationLink(destination: AppearanceView()) {
                        MenuRow(icon: "textformat.size", color: .blue, title: "Appearance",
                                value: store.themeName)
                    }
                    NavigationLink(destination: TypingView()) {
                        MenuRow(icon: "keyboard", color: .gray, title: "Typing")
                    }
                    NavigationLink(destination: TacTileView()) {
                        MenuRow(icon: "speaker.wave.2.fill", color: .pink, title: "Tac Tile",
                                value: store.feelName)
                    }
                    NavigationLink(destination: ActionKeysView()) {
                        MenuRow(icon: "square.grid.2x2.fill", color: .orange, title: "Action Keys",
                                value: store.actionKeysSummary)
                    }
                }

                Section(footer: Text("Test switch until purchases are added.")) {
                    Toggle(isOn: store.binding(\.maxUnlocked)) {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "star.fill", color: .purple)
                            Text("Max Unlocked")
                        }
                    }
                }

                Section(header: Text("Try It Here"),
                        footer: Text("Hold a letter to type its symbol.")) {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                }

                Section(header: Text("Turn On the Keyboard"),
                        footer: Text("The gear on the keyboard opens this app.")) {
                    Text("1. Open Settings → General → Keyboard → Keyboards")
                    Text("2. Tap Add New Keyboard… and choose Keyboard Pro")
                    Text("3. Tap Keyboard Pro and turn on Allow Full Access")
                    Text("4. In any app, hold the globe key and pick Keyboard Pro")
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section(footer: Text(store.versionText).frame(maxWidth: .infinity)) {
                    Button("Reset All Settings", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Keyboard Pro")
            .confirmationDialog("Reset all settings?", isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button("Reset All Settings", role: .destructive) {
                    store.update { $0.resetAll() }
                }
            } message: {
                Text("Your words and emoji combos are kept.")
            }
        }
        .navigationViewStyle(.stack)
        .environmentObject(store)
    }
}
