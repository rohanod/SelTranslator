import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let currentHotKey: () -> HotKeyConfiguration
    private let onOpenTranslator: () -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void
    private let statusItem: NSStatusItem

    init(
        currentHotKey: @escaping () -> HotKeyConfiguration,
        onOpenTranslator: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.currentHotKey = currentHotKey
        self.onOpenTranslator = onOpenTranslator
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            let symbolName = NSImage(systemSymbolName: "translate", accessibilityDescription: "Translator") != nil ? "translate" : "globe"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Translator")
            button.imagePosition = .imageOnly
            button.title = ""
        }
        rebuildMenu()
    }

    func refresh() {
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let hotkeyItem = NSMenuItem(title: "Hotkey: \(currentHotKey().displayString)", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)
        menu.addItem(.separator())

        let openTranslatorItem = NSMenuItem(
            title: "Open Translator",
            action: #selector(openTranslator),
            keyEquivalent: ""
        )
        openTranslatorItem.target = self
        menu.addItem(openTranslatorItem)

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit SelTranslator", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc
    private func openTranslator() {
        onOpenTranslator()
    }

    @objc
    private func openSettings() {
        onOpenSettings()
    }

    @objc
    private func quit() {
        onQuit()
    }
}
