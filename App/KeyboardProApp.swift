//
//  KeyboardProApp.swift
//  The Keyboard Pro app: set-up steps, a place to try the keyboard, and all
//  of the keyboard's settings full screen. The keyboard's gear button opens
//  this app (keyboardpro://settings). Settings are saved in storage shared
//  with the keyboard, which picks them up the next time it appears.
//

import SwiftUI
import UIKit

@main
struct KeyboardProApp: App {
    var body: some Scene {
        WindowGroup {
            SettingsScreen()
                .ignoresSafeArea(.keyboard)
                .onOpenURL { _ in }          // keyboardpro://settings just opens the app
        }
    }
}

/// Wraps the settings screen (SettingsPanel, shared with the keyboard).
struct SettingsScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SettingsViewController {
        SettingsViewController()
    }

    func updateUIViewController(_ controller: SettingsViewController, context: Context) {}
}

final class SettingsViewController: UIViewController {
    private let settings = KBSettings.shared
    private let feedback = SwitchFeedback.shared
    private var panel: SettingsPanel?

    override func viewDidLoad() {
        super.viewDidLoad()
        // The same grey as the keyboard, so tiles and sample keys stand out.
        view.backgroundColor = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(white: 0.13, alpha: 1)
            : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1) }

        KeyButton.style = settings.theme == 3 ? .glass : .solid
        KeyButton.showHints = settings.showHints
        feedback.reload(settings)

        let panel = SettingsPanel(settings: settings)
        panel.isInApp = true
        panel.onOpenSystemSettings = {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        panel.onPreviewKey = { [weak self] sound in self?.feedback.keyDown(sound) }
        panel.onFeedbackChanged = { [weak self] in
            guard let self = self else { return }
            self.feedback.reload(self.settings)
            self.feedback.keyDown()             // play a sample of the new feel
        }
        panel.onThemeChanged = { [weak self] in
            guard let self = self else { return }
            KeyButton.style = self.settings.theme == 3 ? .glass : .solid
        }
        panel.onClearHistory = { SuggestionEngine().clearHistory() }
        // Height changes and Done have nothing to do here: the keyboard
        // applies height the next time it opens, and the app has no Done.

        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            panel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            panel.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
        self.panel = panel

        // Coming back from the iPhone's Settings app or the keyboard: refresh.
        NotificationCenter.default.addObserver(self, selector: #selector(reloadPanel),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadPanel()
    }

    @objc private func reloadPanel() {
        panel?.reload(hasFullAccess: settings.keyboardFullAccess ?? false)
    }
}
