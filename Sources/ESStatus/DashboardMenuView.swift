import AppKit
import ServiceManagement

@MainActor
final class DashboardMenuView: NSView {
    enum Page { case main, icon, history, settings }

    private let contentPanel = NSView()
    private let navigationPanel = NSView()
    private let mainPage = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let elapsedLabel = NSTextField(labelWithString: "")
    private let cpuLabel = NSTextField(labelWithString: "")
    private let memoryLabel = NSTextField(labelWithString: "")
    private let workersLabel = NSTextField(labelWithString: "")
    private let processesLabel = NSTextField(labelWithString: "")
    private let progressLabel = NSTextField(labelWithString: "")
    private let etaLabel = NSTextField(labelWithString: "")
    private let resetButton = NSButton()
    private var pageButtons: [Page: NSButton] = [:]
    private var currentPage: Page = .main
    private var iconView: SettingsAppearanceMenuItemView?
    private var historyController: RunHistoryViewController?
    private var languageView: SettingsLanguageMenuItemView?
    private var advancedView: SettingsAdvancedMenuItemView?

    private let onReset: () -> Void
    private let onOpenR: () -> Void
    private let onQuit: () -> Void
    private let onIconChange: (StatusIconStyle) -> Void
    private let onLanguageChange: (AppLanguage) -> Void
    private let onElapsedChange: (Bool) -> Void
    private let onLoginChange: (Bool) -> Void
    private let onNotificationsChange: (Bool) -> Void
    private let onCheckUpdates: () -> Void
    private let onClearHistory: () -> Void
    private let version: String

    let panelSize = NSSize(width: 586, height: 546)

    init(version: String,
         onReset: @escaping () -> Void,
         onOpenR: @escaping () -> Void,
         onQuit: @escaping () -> Void,
         onIconChange: @escaping (StatusIconStyle) -> Void,
         onLanguageChange: @escaping (AppLanguage) -> Void,
         onElapsedChange: @escaping (Bool) -> Void,
         onLoginChange: @escaping (Bool) -> Void,
         onNotificationsChange: @escaping (Bool) -> Void,
         onCheckUpdates: @escaping () -> Void,
         onClearHistory: @escaping () -> Void) {
        self.version = version
        self.onReset = onReset
        self.onOpenR = onOpenR
        self.onQuit = onQuit
        self.onIconChange = onIconChange
        self.onLanguageChange = onLanguageChange
        self.onElapsedChange = onElapsedChange
        self.onLoginChange = onLoginChange
        self.onNotificationsChange = onNotificationsChange
        self.onCheckUpdates = onCheckUpdates
        self.onClearHistory = onClearHistory
        super.init(frame: NSRect(origin: .zero, size: panelSize))
        buildShell()
        show(.main)
    }

    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { panelSize }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "q" {
            onQuit()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func stylePanel(_ view: NSView, radius: CGFloat) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 0.90, alpha: 1).cgColor
        view.layer?.cornerRadius = radius
    }

    private func buildShell() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        contentPanel.frame = NSRect(x: 14, y: 14, width: 430, height: 518)
        navigationPanel.frame = NSRect(x: 458, y: 14, width: 114, height: 518)
        stylePanel(contentPanel, radius: 22)
        addSubview(contentPanel)
        addSubview(navigationPanel)

        let entries: [(Page?, String, String)] = [
            (.main, "house", "Main"),
            (.icon, "paintpalette", "Icon"),
            (.history, "clock.arrow.circlepath", "History"),
            (nil, "r.square", "R Open"),
            (.settings, "gearshape", "Settings")
        ]
        let heights: [CGFloat] = [66, 96, 96, 96, 96]
        var top = navigationPanel.bounds.height - 10
        for (index, entry) in entries.enumerated() {
            let height = heights[index]
            top -= height
            let button = NSButton(frame: NSRect(x: 8, y: top, width: 98, height: height - 8))
            button.title = entry.2
            button.font = .systemFont(ofSize: 13, weight: .medium)
            button.image = NSImage(systemSymbolName: entry.1, accessibilityDescription: entry.2)
            if index == 1 {
                button.image = StatusIconRenderer.image(style: AppPreferences.iconStyle,
                                                        state: .running, size: 24)
            }
            button.imagePosition = .imageAbove
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 18
            button.layer?.backgroundColor = NSColor(calibratedWhite: 0.82, alpha: 1).cgColor
            button.tag = index
            button.target = self
            button.action = #selector(navigate(_:))
            navigationPanel.addSubview(button)
            if let page = entry.0 { pageButtons[page] = button }
            top -= index == 0 ? 4 : 6
        }
        buildMainPage()
    }

    private func buildMainPage() {
        mainPage.frame = contentPanel.bounds
        statusLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        statusLabel.frame = NSRect(x: 20, y: 462, width: 390, height: 28)
        mainPage.addSubview(statusLabel)
        addSeparator(to: mainPage, y: 442)

        let header = NSTextField(labelWithString: "R Resource Usage")
        header.font = .systemFont(ofSize: 17, weight: .medium)
        header.frame = NSRect(x: 20, y: 400, width: 300, height: 26)
        mainPage.addSubview(header)

        for (index, label) in [cpuLabel, memoryLabel, workersLabel, processesLabel].enumerated() {
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.textColor = .controlAccentColor
            label.frame = NSRect(x: 30, y: 360 - CGFloat(index) * 32, width: 370, height: 24)
            mainPage.addSubview(label)
        }
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.frame = NSRect(x: 30, y: 230, width: 370, height: 20)
        mainPage.addSubview(detailLabel)
        elapsedLabel.font = .systemFont(ofSize: 15, weight: .medium)
        elapsedLabel.textColor = .controlAccentColor
        elapsedLabel.frame = NSRect(x: 30, y: 202, width: 370, height: 22)
        mainPage.addSubview(elapsedLabel)
        progressLabel.font = .systemFont(ofSize: 15, weight: .medium)
        progressLabel.frame = NSRect(x: 30, y: 174, width: 370, height: 22)
        mainPage.addSubview(progressLabel)
        etaLabel.font = .systemFont(ofSize: 15, weight: .medium)
        etaLabel.textColor = .controlAccentColor
        etaLabel.frame = NSRect(x: 30, y: 146, width: 370, height: 22)
        mainPage.addSubview(etaLabel)
        addSeparator(to: mainPage, y: 123)

        resetButton.title = L10n.text("준비 상태로 돌아가기", "Return to Ready")
        resetButton.font = .systemFont(ofSize: 17, weight: .semibold)
        resetButton.frame = NSRect(x: 20, y: 62, width: 390, height: 50)
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(reset)
        mainPage.addSubview(resetButton)
        addSeparator(to: mainPage, y: 50)

        let quit = NSButton(title: L10n.text("앱 종료", "Quit App"), target: self, action: #selector(quitApp))
        quit.isBordered = false
        quit.alignment = .left
        quit.font = .systemFont(ofSize: 16, weight: .medium)
        quit.frame = NSRect(x: 20, y: 10, width: 380, height: 30)
        mainPage.addSubview(quit)
        let quitShortcut = NSTextField(labelWithString: "⌘Q")
        quitShortcut.font = .systemFont(ofSize: 16, weight: .medium)
        quitShortcut.alignment = .right
        quitShortcut.frame = NSRect(x: 330, y: 15, width: 70, height: 22)
        mainPage.addSubview(quitShortcut)
    }

    private func addSeparator(to root: NSView, y: CGFloat) {
        let line = NSBox(frame: NSRect(x: 20, y: y, width: 390, height: 1))
        line.boxType = .separator
        root.addSubview(line)
    }

    @objc private func navigate(_ sender: NSButton) {
        switch sender.tag {
        case 0: show(.main)
        case 1: show(.icon)
        case 2: show(.history)
        case 3: onOpenR()
        default: show(.settings)
        }
    }

    private func show(_ page: Page) {
        currentPage = page
        contentPanel.subviews.forEach { $0.removeFromSuperview() }
        for (candidate, button) in pageButtons {
            button.layer?.backgroundColor = candidate == page
                ? NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
                : NSColor(calibratedWhite: 0.82, alpha: 1).cgColor
        }
        switch page {
        case .main:
            contentPanel.addSubview(mainPage)
        case .icon:
            let view = SettingsAppearanceMenuItemView(selectedStyle: AppPreferences.iconStyle,
                                                       onSelection: onIconChange)
            view.frame.origin = NSPoint(x: 0, y: 143)
            iconView = view
            contentPanel.addSubview(view)
        case .history:
            let controller = RunHistoryViewController(entries: RunHistoryStore.load(), onClear: onClearHistory)
            controller.loadView()
            controller.view.frame.origin = NSPoint(
                x: 25,
                y: max(10, (contentPanel.bounds.height - controller.view.frame.height) / 2)
            )
            historyController = controller
            contentPanel.addSubview(controller.view)
        case .settings:
            addSectionHeader(L10n.text("기본", "Basic"), y: 474)
            let language = SettingsLanguageMenuItemView(selectedLanguage: AppPreferences.language,
                                                         onSelection: onLanguageChange)
            language.frame.origin = NSPoint(x: 0, y: 414)
            languageView = language
            contentPanel.addSubview(language)
            addSectionHeader(L10n.text("고급", "Advanced"), y: 374)
            let advanced = SettingsAdvancedMenuItemView(
                showElapsedTime: AppPreferences.showElapsedTime,
                launchAtLogin: SMAppService.mainApp.status == .enabled,
                notificationsEnabled: AppPreferences.notificationsEnabled,
                version: version,
                onElapsedTimeChange: onElapsedChange,
                onLaunchAtLoginChange: onLoginChange,
                onNotificationsChange: onNotificationsChange,
                onCheckForUpdates: onCheckUpdates
            )
            advanced.frame.origin = NSPoint(x: 0, y: 224)
            advancedView = advanced
            contentPanel.addSubview(advanced)
        }
    }

    private func addSectionHeader(_ title: String, y: CGFloat) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 14, y: y, width: 390, height: 20)
        contentPanel.addSubview(label)
        let line = NSBox(frame: NSRect(x: 14, y: y - 9, width: 402, height: 1))
        line.boxType = .separator
        contentPanel.addSubview(line)
    }

    func update(status: String, detail: String, elapsed: String,
                cpu: String, memory: String, workers: String, processes: String,
                progress: NSAttributedString?, eta: NSAttributedString?, canReset: Bool) {
        statusLabel.stringValue = status
        detailLabel.stringValue = detail
        elapsedLabel.stringValue = elapsed
        cpuLabel.stringValue = cpu
        memoryLabel.stringValue = memory
        workersLabel.stringValue = workers
        processesLabel.stringValue = processes
        progressLabel.attributedStringValue = progress ?? NSAttributedString(string: "")
        etaLabel.attributedStringValue = eta ?? NSAttributedString(string: "")
        resetButton.isEnabled = canReset
    }

    func setUpdateState(title: String, enabled: Bool) {
        advancedView?.setUpdateState(title: title, enabled: enabled)
    }

    @objc private func reset() { onReset() }
    @objc private func quitApp() { onQuit() }
}
