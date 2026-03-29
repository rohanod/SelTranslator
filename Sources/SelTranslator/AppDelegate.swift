import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let languageStore = TranslationLanguageStore()
    private let hotKeyStore = HotKeyStore()
    private let accessibilityService = AccessibilitySelectionService()
    private let translationService = TranslationService()

    private lazy var translatorViewModel = TranslatorViewModel(
        languageStore: languageStore,
        translationService: translationService
    )
    private lazy var translatorPanelController = TranslatorPanelController(viewModel: translatorViewModel)

    private var statusBarController: StatusBarController?
    private var hotKeyManager: GlobalHotKeyManager?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(
            currentHotKey: { [weak self] in
                self?.hotKeyStore.hotKey ?? .default
            },
            onOpenTranslator: { [weak self] in
                self?.showTranslator()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        statusBarController?.install()

        hotKeyManager = GlobalHotKeyManager { [weak self] in
            Task { @MainActor [weak self] in
                self?.showTranslator()
            }
        }

        applyHotKey(hotKeyStore.hotKey)
    }

    private func showTranslator() {
        if translatorPanelController.isVisible {
            translatorPanelController.dismiss(reason: .escape)
            return
        }

        let prefill = captureSelectedTextIfAvailable()
        translatorViewModel.prepareForPresentation(prefillText: prefill)
        translatorPanelController.show()
    }

    private func captureSelectedTextIfAvailable() -> String? {
        guard accessibilityService.hasPermission(prompt: false) else {
            return nil
        }

        do {
            let selection = try accessibilityService.captureSelection()
            let trimmed = selection.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            Diagnostics.info("Prefilled translator from selection. chars=\(trimmed.count)")
            return trimmed
        } catch {
            return nil
        }
    }

    private func applyHotKey(_ hotKey: HotKeyConfiguration) {
        do {
            try hotKeyManager?.register(hotKey: hotKey)
            statusBarController?.refresh()
            Diagnostics.info("Hotkey registered: \(hotKey.displayString)")
        } catch {
            Diagnostics.error("Hotkey registration failed: \(Diagnostics.describe(error))")
        }
    }

    private func openSettings() {
        settingsWindowController = SettingsWindowController(
            languageStore: languageStore,
            hotKeyStore: hotKeyStore,
            onHotKeyApplied: { [weak self] hotKey in
                self?.applyHotKey(hotKey)
            },
            onSettingsChanged: { [weak self] in
                self?.translatorViewModel.reloadSettings()
                self?.statusBarController?.refresh()
            }
        )
        settingsWindowController?.show()
    }
}
