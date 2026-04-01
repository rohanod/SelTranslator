import AppKit
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
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Settings")
                        .font(.largeTitle.weight(.semibold))

                    Text("Choose translation defaults and the shortcut used to open SelTranslator.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                settingsSection(
                    title: "Defaults",
                    subtitle: "These values are used when the popup opens with a fresh translation."
                ) {
                    settingsRow(label: "Default From") {
                        Picker("Default From", selection: $localSourceLanguageID) {
                            Text("Auto Detect").tag(TranslationLanguage.autoDetectID)
                            ForEach(languages, id: \.id) { language in
                                Text(language.displayName).tag(language.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 240, alignment: .leading)
                        .onChange(of: localSourceLanguageID) { _, newValue in
                            onSourceLanguageChanged(newValue)
                        }
                    }

                    settingsRow(label: "Default To") {
                        Picker("Default To", selection: $localTargetLanguageID) {
                            ForEach(languages, id: \.id) { language in
                                Text(language.displayName).tag(language.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 240, alignment: .leading)
                        .onChange(of: localTargetLanguageID) { _, newValue in
                            onTargetLanguageChanged(newValue)
                        }
                    }

                    settingsRow(label: "Draft Restore") {
                        Picker("Draft Restore", selection: $localRestoreTimeout) {
                            ForEach(DraftRestoreTimeout.allCases) { timeout in
                                Text(timeout.displayName).tag(timeout)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 240, alignment: .leading)
                        .onChange(of: localRestoreTimeout) { _, newValue in
                            onRestoreTimeoutChanged(newValue)
                        }
                    }
                }

                settingsSection(
                    title: "Global Hotkey",
                    subtitle: "This shortcut opens the translator popup from anywhere in macOS."
                ) {
                    settingsRow(label: "Key") {
                        Picker("Key", selection: $localKeyCode) {
                            ForEach(HotKeyConfiguration.keyOptions) { option in
                                Text(option.label).tag(option.keyCode)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180, alignment: .leading)
                        .onChange(of: localKeyCode) { _, _ in
                            applyHotKey()
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Modifiers")
                            .font(.subheadline.weight(.medium))

                        HStack(spacing: 16) {
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

                    Text("Current shortcut: \(currentHotKey.displayString)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private func applyHotKey() {
        onHotKeyChanged(currentHotKey)
    }

    private func settingsSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
    }

    private func settingsRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.body)
                .frame(width: 112, alignment: .leading)

            content()

            Spacer(minLength: 0)
        }
    }
}
