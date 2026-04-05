import AppKit
import SwiftUI
import Observation

struct TranslatorPopupView: View {
    @Bindable var viewModel: TranslatorViewModel
    let onCopyAndClose: () -> Void
    @FocusState private var isEditorFocused: Bool

    private let columnSpacing: CGFloat = 14
    private let swapColumnWidth: CGFloat = 40
    private let sourceInset = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)

    init(viewModel: TranslatorViewModel, onCopyAndClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCopyAndClose = onCopyAndClose
    }

    var body: some View {
        ZStack {
            AppPanelBackground()

            VStack(alignment: .leading, spacing: AppUI.Spacing.large) {
                header
                languageControls
                workArea
                Divider()
                    .overlay(AppUI.separator)
                footerActions
            }
            .padding(22)
        }
        .frame(width: 760, height: 404)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isTranslating)
        .onAppear {
            requestEditorFocus()
        }
        .onChange(of: viewModel.focusToken) { _, _ in
            requestEditorFocus()
        }
        .onChange(of: viewModel.sourceText) { _, _ in
            viewModel.sourceTextDidChange()
        }
        .onChange(of: viewModel.selectedSourceLanguageID) { _, _ in
            viewModel.sourceLanguageDidChange()
        }
        .onChange(of: viewModel.selectedTargetLanguageID) { _, _ in
            viewModel.targetLanguageDidChange()
        }
        .background {
            shortcutBridge
        }
    }

    @ViewBuilder
    private var shortcutBridge: some View {
        Button("Copy And Close") {
            onCopyAndClose()
        }
        .keyboardShortcut("c", modifiers: [.command, .option])
        .disabled(viewModel.translatedText.isEmpty)
        .hidden()

        responderShortcut(title: "Cut", key: "x", modifiers: .command, action: #selector(NSText.cut(_:)))
        responderShortcut(title: "Copy", key: "c", modifiers: .command, action: #selector(NSText.copy(_:)))
        responderShortcut(title: "Paste", key: "v", modifiers: .command, action: #selector(NSText.paste(_:)))
        responderShortcut(title: "Select All", key: "a", modifiers: .command, action: #selector(NSText.selectAll(_:)))
        responderShortcut(title: "Undo", key: "z", modifiers: .command, action: Selector(("undo:")))
        responderShortcut(title: "Redo", key: "z", modifiers: [.command, .shift], action: Selector(("redo:")))
    }

    private func responderShortcut(
        title: String,
        key: KeyEquivalent,
        modifiers: EventModifiers,
        action: Selector
    ) -> some View {
        Button(title) {
            NSApp.sendAction(action, to: nil, from: nil)
        }
        .keyboardShortcut(key, modifiers: modifiers)
        .hidden()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppUI.Spacing.medium) {
            Text("Translate")
                .font(.system(size: AppUI.FontSize.title, weight: .semibold, design: .rounded))

            Spacer()

        }
    }

    private var languageControls: some View {
        HStack(alignment: .center, spacing: columnSpacing) {
            pickerColumn(title: "From", detail: sourcePickerDetail) {
                Picker("From", selection: $viewModel.selectedSourceLanguageID) {
                    Text(autoDetectPickerTitle).tag(TranslationLanguage.autoDetectID)
                    ForEach(viewModel.availableLanguages) { language in
                        Text(language.displayName).tag(language.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .frame(maxWidth: .infinity)

            Button {
                viewModel.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(AppIconButtonStyle())
            .frame(width: swapColumnWidth)
            .disabled(!viewModel.canSwapLanguages)
            .opacity(viewModel.canSwapLanguages ? 1 : 0.4)
            .help("Swap source and target languages")
            .padding(.top, 16)

            pickerColumn(title: "To") {
                Picker("To", selection: $viewModel.selectedTargetLanguageID) {
                    ForEach(viewModel.availableLanguages) { language in
                        Text(language.displayName).tag(language.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var workArea: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            sourcePanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Divider()
                    .overlay(AppUI.separator)
            }
            .frame(width: swapColumnWidth)

            resultPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sourcePanel: some View {
        AppSurface(title: "Source") {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppUI.Radius.editor, style: .continuous)
                    .fill(Color.primary.opacity(0.045))

                TextEditor(text: $viewModel.sourceText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .padding(sourceInset)
                    .focused($isEditorFocused)

                if viewModel.sourceText.isEmpty {
                    Text("Type or use the shortcut with selected text.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(AppUI.quietSecondary)
                        .padding(sourceInset)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var resultPanel: some View {
        AppSurface(title: "Translation") {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppUI.Radius.editor, style: .continuous)
                    .fill(Color.primary.opacity(0.035))

                Group {
                    if viewModel.isTranslating {
                        HStack(spacing: AppUI.Spacing.small) {
                            ProgressView()
                            Text("Translating…")
                                .font(.system(size: AppUI.FontSize.body, weight: .regular, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if let errorMessage = viewModel.errorMessage {
                        VStack(alignment: .leading, spacing: AppUI.Spacing.small) {
                            Text("Translation unavailable")
                                .font(.system(size: AppUI.FontSize.body, weight: .medium, design: .rounded))
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(AppUI.quietSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if viewModel.translatedText.isEmpty {
                        Text("Translation appears here.")
                            .font(.system(size: AppUI.FontSize.body, weight: .regular, design: .rounded))
                            .foregroundStyle(AppUI.quietSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .transition(.opacity)
                    } else {
                        ScrollView {
                            Text(viewModel.translatedText)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footerActions: some View {
        HStack(spacing: AppUI.Spacing.small) {
            Button("Clear") {
                viewModel.clearSourceText()
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .disabled(viewModel.sourceText.isEmpty && viewModel.translatedText.isEmpty)
            .opacity(viewModel.sourceText.isEmpty && viewModel.translatedText.isEmpty ? 0.45 : 1)

            Spacer()

            Button("Copy") {
                viewModel.copyTranslation()
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .disabled(viewModel.translatedText.isEmpty)
            .opacity(viewModel.translatedText.isEmpty ? 0.45 : 1)

            Button("Copy & Close") {
                onCopyAndClose()
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(viewModel.translatedText.isEmpty)
            .opacity(viewModel.translatedText.isEmpty ? 0.45 : 1)
        }
    }

    private var autoDetectPickerTitle: String {
        if let detectedSourceLabel = viewModel.detectedSourceLabel,
           viewModel.selectedSourceLanguageID == TranslationLanguage.autoDetectID {
            return "Auto Detect (\(detectedSourceLabel))"
        }

        return "Auto Detect"
    }

    private var sourcePickerDetail: String? {
        nil
    }

    private func pickerColumn<Content: View>(title: String, detail: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        AppSurface(title: title, detail: detail) {
            content()
        }
    }

    private func requestEditorFocus() {
        isEditorFocused = false
        DispatchQueue.main.async {
            isEditorFocused = true
        }
    }
}
