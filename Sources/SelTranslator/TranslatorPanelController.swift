import AppKit
import SwiftUI

@MainActor
final class TranslatorPanelController: NSObject, NSWindowDelegate {
    private let popupSize = NSSize(width: 760, height: 404)
    private let copyToastSize = NSSize(width: 260, height: 92)
    private let popupVerticalOffset: CGFloat = 40
    private let toastVerticalOffset: CGFloat = 32
    private let popupIntroOffset: CGFloat = -18
    private let popupOutroOffset: CGFloat = -14
    private let toastIntroOffset: CGFloat = -14
    private let toastOutroOffset: CGFloat = 14
    private let popupShowDuration = 0.22
    private let popupHideDuration = 0.16
    private let toastShowDuration = 0.18
    private let toastHideDuration = 0.16
    private let toastDisplayDuration: UInt64 = 900_000_000

    private let viewModel: TranslatorViewModel
    private let panel: FloatingTranslatorPanel
    private let copyToastPanel: CopyToastPanel
    private var copyToastTask: Task<Void, Never>?
    private var outsideMouseMonitors: [Any] = []
    private var isClosing = false

    init(viewModel: TranslatorViewModel) {
        self.viewModel = viewModel
        self.panel = FloatingTranslatorPanel(
            contentRect: NSRect(origin: .zero, size: popupSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.copyToastPanel = CopyToastPanel(
            contentRect: NSRect(origin: .zero, size: copyToastSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init()

        let rootView = TranslatorPopupView(viewModel: viewModel) { [weak self] in
            self?.copyAndShowToast()
        }
        panel.contentViewController = NSHostingController(rootView: rootView)
        panel.delegate = self
        panel.dismissHandler = { [weak self] reason in
            self?.dismiss(reason: reason)
        }
        panel.isReleasedWhenClosed = false
        configureSpacesPinnedPanel(panel, level: .floating)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false

        let toastView = CopyToastView()
        copyToastPanel.contentViewController = NSHostingController(rootView: toastView)
        copyToastPanel.isReleasedWhenClosed = false
        configureSpacesPinnedPanel(copyToastPanel, level: .statusBar)
        copyToastPanel.backgroundColor = .clear
        copyToastPanel.isOpaque = false
        copyToastPanel.ignoresMouseEvents = true
    }

    var isVisible: Bool {
        panel.isVisible && !isClosing
    }

    func show() {
        cancelCopyToast()
        installOutsideMouseMonitors()

        let finalFrame = centeredFrame(size: popupSize, verticalOffset: popupVerticalOffset)
        panel.setFrame(finalFrame.offsetBy(dx: 0, dy: popupIntroOffset), display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        viewModel.isPresented = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = popupShowDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        }
    }

    func dismiss(reason: TranslatorDismissReason) {
        guard panel.isVisible, !isClosing else { return }
        removeOutsideMouseMonitors()
        cancelCopyToast()
        isClosing = true
        viewModel.prepareForDismiss(reason: reason)

        let endFrame = panel.frame.offsetBy(dx: 0, dy: popupOutroOffset)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = popupHideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(endFrame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
                self.panel.setFrame(self.centeredFrame(size: self.popupSize, verticalOffset: self.popupVerticalOffset), display: false)
                self.isClosing = false
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        // Space and full-screen switches can resign key without an outside click.
        // Mouse monitors own click-away dismissal so the panel can follow Spaces.
    }

    private func copyAndShowToast() {
        guard panel.isVisible, !viewModel.translatedText.isEmpty, !isClosing else { return }

        viewModel.copyTranslation()
        dismiss(reason: .escape)
        showCopyToast()
    }

    private func showCopyToast() {
        cancelCopyToast()

        let finalFrame = centeredFrame(size: copyToastSize, verticalOffset: toastVerticalOffset)
        copyToastPanel.setFrame(finalFrame.offsetBy(dx: 0, dy: toastIntroOffset), display: false)
        copyToastPanel.alphaValue = 0
        copyToastPanel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = toastShowDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            copyToastPanel.animator().alphaValue = 1
            copyToastPanel.animator().setFrame(finalFrame, display: true)
        }

        copyToastTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.toastDisplayDuration)
            let endFrame = finalFrame.offsetBy(dx: 0, dy: self.toastOutroOffset)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = self.toastHideDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.copyToastPanel.animator().alphaValue = 0
                self.copyToastPanel.animator().setFrame(endFrame, display: true)
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.copyToastPanel.orderOut(nil)
                    self?.copyToastPanel.alphaValue = 1
                    self?.copyToastPanel.setFrame(finalFrame, display: false)
                }
            }
        }
    }

    private func cancelCopyToast() {
        copyToastTask?.cancel()
        copyToastTask = nil
        copyToastPanel.orderOut(nil)
        copyToastPanel.alphaValue = 1
    }

    private func configureSpacesPinnedPanel(_ panel: NSPanel, level: NSWindow.Level) {
        panel.level = level
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
    }

    private func installOutsideMouseMonitors() {
        removeOutsideMouseMonitors()

        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            let windowNumber = event.windowNumber
            Task { @MainActor [weak self] in
                self?.handleOutsideMouseDown(windowNumber: windowNumber)
            }
            return event
        }
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            let windowNumber = event.windowNumber
            Task { @MainActor [weak self] in
                self?.handleOutsideMouseDown(windowNumber: windowNumber)
            }
        }

        outsideMouseMonitors = [localMonitor, globalMonitor].compactMap { $0 }
    }

    private func removeOutsideMouseMonitors() {
        outsideMouseMonitors.forEach(NSEvent.removeMonitor)
        outsideMouseMonitors.removeAll()
    }

    private func handleOutsideMouseDown(windowNumber: Int) {
        guard panel.isVisible, !isClosing else { return }
        guard windowNumber != panel.windowNumber, windowNumber != copyToastPanel.windowNumber else { return }
        dismiss(reason: .outsideClick)
    }

    private func centeredFrame(size: NSSize, verticalOffset: CGFloat) -> NSRect {
        guard let screen = currentScreen() else {
            return NSRect(origin: .zero, size: size)
        }

        return NSRect(
            x: screen.visibleFrame.midX - (size.width / 2),
            y: screen.visibleFrame.midY - (size.height / 2) + verticalOffset,
            width: size.width,
            height: size.height
        )
    }

    private func currentScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
    }
}

@MainActor
final class FloatingTranslatorPanel: NSPanel {
    var dismissHandler: ((TranslatorDismissReason) -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        dismissHandler?(.escape)
    }
}

@MainActor
final class CopyToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct CopyToastView: View {
    @State private var pulseValue = 0

    var body: some View {
        ZStack {
            AppPanelBackground()

            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, options: .nonRepeating, value: pulseValue)
                Text("Copied to clipboard")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 18)
        }
        .frame(width: 260, height: 92)
        .onAppear {
            pulseValue += 1
        }
    }
}
