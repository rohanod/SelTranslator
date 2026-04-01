import AppKit
import SwiftUI
import Observation

struct TranslatorPopupView: View {
    @Bindable var viewModel: TranslatorViewModel
    let onCopyAndClose: () -> Void
    @FocusState private var isEditorFocused: Bool

    private let columnSpacing: CGFloat = 12
    private let swapColumnWidth: CGFloat = 34
    private let sourceInset = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    private let pickerStatusHeight: CGFloat = 14
    private let panelCornerRadius: CGFloat = 20
    private let innerCornerRadius: CGFloat = 14

    init(viewModel: TranslatorViewModel, onCopyAndClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCopyAndClose = onCopyAndClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            Divider()
                .overlay {
                    Color(nsColor: .separatorColor).opacity(0.35)
                }

            languageRow

            contentRow
        }
        .padding(20)
        .frame(width: 760, height: 360)
        .background {
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        }
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

        responderShortcut(
            title: "Cut",
            key: "x",
            modifiers: .command,
            action: #selector(NSText.cut(_:))
        )

        responderShortcut(
            title: "Copy",
            key: "c",
            modifiers: .command,
            action: #selector(NSText.copy(_:))
        )

        responderShortcut(
            title: "Paste",
            key: "v",
            modifiers: .command,
            action: #selector(NSText.paste(_:))
        )

        responderShortcut(
            title: "Select All",
            key: "a",
            modifiers: .command,
            action: #selector(NSText.selectAll(_:))
        )

        responderShortcut(
            title: "Undo",
            key: "z",
            modifiers: .command,
            action: Selector(("undo:"))
        )

        responderShortcut(
            title: "Redo",
            key: "z",
            modifiers: [.command, .shift],
            action: Selector(("redo:"))
        )
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

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Translate")
                    .font(.title3.weight(.semibold))
                Text("Esc closes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                viewModel.copyTranslation()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .labelStyle(.titleAndIcon)
            }
            .controlSize(.small)
            .disabled(viewModel.translatedText.isEmpty)
            .opacity(viewModel.translatedText.isEmpty ? 0.5 : 1)
        }
    }

    private var languageRow: some View {
        HStack(alignment: .top, spacing: 10) {
            pickerCard(title: "From") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("From", selection: $viewModel.selectedSourceLanguageID) {
                        Text("Auto Detect").tag(TranslationLanguage.autoDetectID)
                        ForEach(viewModel.availableLanguages) { language in
                            Text(language.displayName).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if let detectedSourceLabel = viewModel.detectedSourceLabel,
                       viewModel.selectedSourceLanguageID == TranslationLanguage.autoDetectID {
                        Text("Detected \(detectedSourceLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    } else {
                        Color.clear
                            .frame(height: pickerStatusHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                viewModel.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Swap source and target languages")
            .disabled(!viewModel.canSwapLanguages)
            .opacity(viewModel.canSwapLanguages ? 1 : 0.45)
            .frame(width: swapColumnWidth)

            pickerCard(title: "To") {
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

    private var contentRow: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            sourcePanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Color.clear
                .frame(width: swapColumnWidth)

            resultPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sourcePanel: some View {
        panelCard(title: "Source") {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.sourceText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(sourceInset)
                    .focused($isEditorFocused)

                if viewModel.sourceText.isEmpty {
                    Text("Type or trigger the hotkey with text selected to prefill this field.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(sourceInset)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var resultPanel: some View {
        panelCard(title: "Translation") {
            Group {
                if viewModel.isTranslating {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Translating…")
                            .font(.callout.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Translation unavailable", systemImage: "exclamationmark.triangle")
                            .font(.callout.weight(.semibold))
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if viewModel.translatedText.isEmpty {
                    Text("Your translation will appear here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                } else {
                    ScrollView {
                        Text(viewModel.translatedText)
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.trailing, 4)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.easeInOut(duration: 0.18), value: viewModel.isTranslating)
            .animation(.easeInOut(duration: 0.18), value: viewModel.errorMessage)
            .animation(.easeInOut(duration: 0.18), value: viewModel.translatedText)
        }
    }

    private func pickerCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }

    private func panelCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }

    private func requestEditorFocus() {
        isEditorFocused = false
        DispatchQueue.main.async {
            isEditorFocused = true
        }
    }
}
