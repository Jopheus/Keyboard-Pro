import SwiftUI

@main
struct KeyboardProApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var text = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Turn on the keyboard")) {
                    Text("1. Open Settings → General → Keyboard → Keyboards")
                    Text("2. Tap Add New Keyboard… and choose Keyboard Pro")
                    Text("3. In any app, hold the globe key and pick Keyboard Pro")
                }
                Section(header: Text("Settings and vibration")) {
                    Text("Tap the gear at the top-left of the keyboard to open its settings.")
                    Text("For vibration, tap Keyboard Pro in the Keyboards list and turn on Allow Full Access. The keyboard never uses the internet.")
                }
                Section(header: Text("Try it here (long-press a letter for a symbol)")) {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                }
            }
            .navigationTitle("Keyboard Pro")
        }
        .navigationViewStyle(.stack)
    }
}
