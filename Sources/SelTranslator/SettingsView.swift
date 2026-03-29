import SwiftUI

struct SettingsView: View {
    let languages: [TranslationLanguage]
    let selectedSourceLanguageID: String
    let selectedTargetLanguageID: String
    let selectedRestoreTimeout: DraftRestoreTimeout
    let hotKey: HotKeyConfiguration
    let onSourceLanguageChanged: (String) -> Void
    let onTargetLanguageChanged: (String) -> Void
    let onRestoreTimeoutChanged: (DraftRestoreTimeout) -> Void
    let onHotKeyChanged: (HotKeyConfiguration) -> Void

    @State private var localSourceLanguageID: String
    @State private var localTargetLanguageID: String
    @State private var localRestoreTimeout: DraftRestoreTimeout
    @State private var localKeyCode: UInt32
    @State private var useCommand: Bool
    @State private var useOption: Bool
    @State private var useControl: Bool
    @State private var useShift: Bool

    init(
        languages: [TranslationLanguage],
        selectedSourceLanguageID: String,
        selectedTargetLanguageID: String,
        selectedRestoreTimeout: DraftRestoreTimeout,
        hotKey: HotKeyConfiguration,
        onSourceLanguageChanged: @escaping (String) -> Void,
        onTargetLanguageChanged: @escaping (String) -> Void,
        onRestoreTimeoutChanged: @escaping (DraftRestoreTimeout) -> Void,
        onHotKeyChanged: @escaping (HotKeyConfiguration) -> Void
    ) {
        self.languages = languages
        self.selectedSourceLanguageID = selectedSourceLanguageID
        self.selectedTargetLanguageID = selectedTargetLanguageID
        self.selectedRestoreTimeout = selectedRestoreTimeout
        self.hotKey = hotKey
        self.onSourceLanguageChanged = onSourceLanguageChanged
        self.onTargetLanguageChanged = onTargetLanguageChanged
        self.onRestoreTimeoutChanged = onRestoreTimeoutChanged
        self.onHotKeyChanged = onHotKeyChanged

        _localSourceLanguageID = State(initialValue: selectedSourceLanguageID)
        _localTargetLanguageID = State(initialValue: selectedTargetLanguageID)
        _localRestoreTimeout = State(initialValue: selectedRestoreTimeout)
        _localKeyCode = State(initialValue: hotKey.keyCode)
        _useCommand = State(initialValue: hotKey.isCommandEnabled)
        _useOption = State(initialValue: hotKey.isOptionEnabled)
        _useControl = State(initialValue: hotKey.isControlEnabled)
        _useShift = State(initialValue: hotKey.isShiftEnabled)
    }

    private var currentHotKey: HotKeyConfiguration {
        HotKeyConfiguration(keyCode: localKeyCode, modifiers: 0)
            .with(command: useCommand, option: useOption, control: useControl, shift: useShift)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SelTranslator Settings")
                .font(.system(size: 20, weight: .semibold, design: .rounded))

            GroupBox("Defaults") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Default From", selection: $localSourceLanguageID) {
                        Text("Auto Detect").tag(TranslationLanguage.autoDetectID)
                        ForEach(languages, id: \.id) { language in
                            Text(language.displayName).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: localSourceLanguageID) { _, newValue in
                        onSourceLanguageChanged(newValue)
                    }

                    Picker("Default To", selection: $localTargetLanguageID) {
                        ForEach(languages, id: \.id) { language in
                            Text(language.displayName).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: localTargetLanguageID) { _, newValue in
                        onTargetLanguageChanged(newValue)
                    }

                    Picker("Draft Restore", selection: $localRestoreTimeout) {
                        ForEach(DraftRestoreTimeout.allCases) { timeout in
                            Text(timeout.displayName).tag(timeout)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: localRestoreTimeout) { _, newValue in
                        onRestoreTimeoutChanged(newValue)
                    }
                }
            }

            GroupBox("Global Hotkey") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Key", selection: $localKeyCode) {
                        ForEach(HotKeyConfiguration.keyOptions) { option in
                            Text(option.label).tag(option.keyCode)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: localKeyCode) { _, _ in
                        applyHotKey()
                    }

                    HStack(spacing: 12) {
                        Toggle("Control", isOn: $useControl)
                        Toggle("Option", isOn: $useOption)
                        Toggle("Shift", isOn: $useShift)
                        Toggle("Command", isOn: $useCommand)
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: useControl) { _, _ in applyHotKey() }
                    .onChange(of: useOption) { _, _ in applyHotKey() }
                    .onChange(of: useShift) { _, _ in applyHotKey() }
                    .onChange(of: useCommand) { _, _ in applyHotKey() }

                    Text("Current shortcut: \(currentHotKey.displayString)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 440, height: 280)
    }

    private func applyHotKey() {
        onHotKeyChanged(currentHotKey)
    }
}
