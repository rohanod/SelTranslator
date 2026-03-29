import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let languageStore: TranslationLanguageStore
    private let hotKeyStore: HotKeyStore
    private let onHotKeyApplied: (HotKeyConfiguration) -> Void
    private let onSettingsChanged: () -> Void

    init(
        languageStore: TranslationLanguageStore,
        hotKeyStore: HotKeyStore,
        onHotKeyApplied: @escaping (HotKeyConfiguration) -> Void,
        onSettingsChanged: @escaping () -> Void
    ) {
        self.languageStore = languageStore
        self.hotKeyStore = hotKeyStore
        self.onHotKeyApplied = onHotKeyApplied
        self.onSettingsChanged = onSettingsChanged

        let contentView = SettingsView(
            languages: languageStore.availableLanguages,
            selectedSourceLanguageID: languageStore.defaultSourceLanguageID,
            selectedTargetLanguageID: languageStore.defaultTargetLanguageID,
            selectedRestoreTimeout: languageStore.draftRestoreTimeout,
            hotKey: hotKeyStore.hotKey,
            onSourceLanguageChanged: { [weak languageStore] sourceID in
                languageStore?.defaultSourceLanguageID = sourceID
                onSettingsChanged()
            },
            onTargetLanguageChanged: { [weak languageStore] targetID in
                guard let languageStore, let language = languageStore.language(for: targetID) else { return }
                languageStore.defaultTargetLanguage = language
                onSettingsChanged()
            },
            onRestoreTimeoutChanged: { [weak languageStore] timeout in
                languageStore?.draftRestoreTimeout = timeout
                onSettingsChanged()
            },
            onHotKeyChanged: { [weak hotKeyStore] hotKey in
                hotKeyStore?.hotKey = hotKey
                onHotKeyApplied(hotKey)
                onSettingsChanged()
            }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SelTranslator Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.level = .normal
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
