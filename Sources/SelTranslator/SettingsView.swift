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
        ScrollView {
            VStack(alignment: .leading, spacing: AppUI.Spacing.xLarge) {
                settingsHeader
                sectionDivider
                translationDefaultsSection
                sectionDivider
                popupBehaviorSection
                sectionDivider
                globalShortcutSection
                sectionDivider
                helpSection
            }
            .padding(28)
        }
        .frame(width: 540, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SelTranslator Settings")
                .font(.system(size: AppUI.FontSize.headline, weight: .semibold, design: .rounded))

            Text("Defaults and shortcut behavior.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(AppUI.quietSecondary)
        }
    }

    private var translationDefaultsSection: some View {
        AppSectionCard(title: "Translation Defaults") {
            VStack(alignment: .leading, spacing: AppUI.Spacing.medium) {
                settingRow(title: "Source language") {
                    Picker("Default source language", selection: $localSourceLanguageID) {
                        Text("Auto Detect").tag(TranslationLanguage.autoDetectID)
                        ForEach(languages, id: \.id) { language in
                            Text(language.displayName).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: localSourceLanguageID) { _, newValue in
                        onSourceLanguageChanged(newValue)
                    }
                }

                settingRow(title: "Target language") {
                    Picker("Default target language", selection: $localTargetLanguageID) {
                        ForEach(languages, id: \.id) { language in
                            Text(language.displayName).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: localTargetLanguageID) { _, newValue in
                        onTargetLanguageChanged(newValue)
                    }
                }
            }
        }
    }

    private var popupBehaviorSection: some View {
        AppSectionCard(title: "Popup Behavior") {
            settingRow(title: "Draft restore") {
                Picker("Draft restore timeout", selection: $localRestoreTimeout) {
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
    }

    private var globalShortcutSection: some View {
        AppSectionCard(title: "Global Shortcut") {
            VStack(alignment: .leading, spacing: AppUI.Spacing.medium) {
                settingRow(title: "Key") {
                    Picker("Key", selection: $localKeyCode) {
                        ForEach(HotKeyConfiguration.keyOptions) { option in
                            Text(option.label).tag(option.keyCode)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: localKeyCode) { _, _ in
                        applyHotKey()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Modifiers")
                        .font(.system(size: AppUI.FontSize.body, weight: .medium, design: .rounded))

                    HStack(spacing: 14) {
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
                }

                Text(currentHotKey.displayString)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(AppUI.quietSecondary)
            }
        }
    }

    private var helpSection: some View {
        AppSectionCard(title: "Notes") {
            VStack(alignment: .leading, spacing: AppUI.Spacing.small) {
                AppHintText(text: "If the shortcut stops working, check accessibility permissions in macOS settings.")
                AppHintText(text: "If translation is unavailable, verify the selected languages are supported by Apple’s translation features.")
            }
        }
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(AppUI.separator)
    }

    private func settingRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: AppUI.FontSize.body, weight: .medium, design: .rounded))

            content()
        }
    }

    private func applyHotKey() {
        onHotKeyChanged(currentHotKey)
    }
}
