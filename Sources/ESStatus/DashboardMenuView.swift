import AppKit
import ServiceManagement

@MainActor
private final class DashboardNavigationButton: NSControl {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    var isSelected = false { didSet { updateBackground() } }
    private var isHovered = false
    private var trackingAreaRef: NSTrackingArea?

    init(frame: NSRect, title: String, image: NSImage?) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 18
        iconView.image = image
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        addSubview(titleLabel)
        updateBackground()
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let bottom = bounds.midY - 26
        iconView.frame = NSRect(x: bounds.midX - 14, y: bottom + 25, width: 28, height: 28)
        titleLabel.frame = NSRect(x: 6, y: bottom, width: bounds.width - 12, height: 20)
    }

    override func mouseDown(with event: NSEvent) { layer?.opacity = 0.78 }
    override func mouseUp(with event: NSEvent) {
        layer?.opacity = 1
        if bounds.contains(convert(event.locationInWindow, from: nil)) { sendAction(action, to: target) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateBackground()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        layer?.opacity = 1
        updateBackground()
    }

    private func updateBackground() {
        layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.20).cgColor
            : isHovered
                ? NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
                : NSColor(calibratedWhite: 0.82, alpha: 0.70).cgColor
    }
}

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
    private var pageButtons: [Page: DashboardNavigationButton] = [:]
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

    let panelSize = NSSize(width: 430, height: 470)

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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isOpaque = false
        window?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.70)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "q" {
            onQuit()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func stylePanel(_ view: NSView, radius: CGFloat) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 0.90, alpha: 0.70).cgColor
        view.layer?.cornerRadius = radius
    }

    private func buildShell() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.70).cgColor

        contentPanel.frame = NSRect(x: 14, y: 14, width: 300, height: 442)
        navigationPanel.frame = NSRect(x: 328, y: 14, width: 88, height: 442)
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
        let heights: [CGFloat] = [72, 82, 82, 82, 82]
        var top = navigationPanel.bounds.height
        for (index, entry) in entries.enumerated() {
            let height = heights[index]
            top -= height
            var image = NSImage(systemSymbolName: entry.1, accessibilityDescription: entry.2)
            if index == 1 {
                image = StatusIconRenderer.image(style: AppPreferences.iconStyle,
                                                 state: .running, size: 24)
            }
            let button = DashboardNavigationButton(
                frame: NSRect(x: 6, y: top + 4, width: 76, height: height - 8),
                title: entry.2,
                image: image
            )
            button.tag = index
            button.target = self
            button.action = #selector(navigate(_:))
            navigationPanel.addSubview(button)
            if let page = entry.0 { pageButtons[page] = button }
        }
        buildMainPage()
    }

    private func buildMainPage() {
        mainPage.frame = contentPanel.bounds
        statusLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        statusLabel.frame = NSRect(x: 20, y: 392, width: 260, height: 28)
        mainPage.addSubview(statusLabel)
        addSeparator(to: mainPage, y: 376)

        let header = NSTextField(labelWithString: "R Resource Usage")
        header.font = .systemFont(ofSize: 17, weight: .medium)
        header.frame = NSRect(x: 20, y: 338, width: 260, height: 26)
        mainPage.addSubview(header)

        for (index, label) in [cpuLabel, memoryLabel, workersLabel, processesLabel].enumerated() {
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.textColor = .controlAccentColor
            label.frame = NSRect(x: 30, y: 298 - CGFloat(index) * 30, width: 240, height: 24)
            mainPage.addSubview(label)
        }
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.frame = NSRect(x: 30, y: 188, width: 240, height: 18)
        mainPage.addSubview(detailLabel)
        let executionHeader = NSTextField(labelWithString: L10n.text("R 실행 진행 상황", "R Execution Progress"))
        executionHeader.font = .systemFont(ofSize: 14, weight: .medium)
        executionHeader.frame = NSRect(x: 20, y: 178, width: 260, height: 22)
        mainPage.addSubview(executionHeader)
        elapsedLabel.font = .systemFont(ofSize: 15, weight: .medium)
        elapsedLabel.textColor = .controlAccentColor
        elapsedLabel.frame = NSRect(x: 30, y: 154, width: 240, height: 22)
        mainPage.addSubview(elapsedLabel)
        progressLabel.font = .systemFont(ofSize: 15, weight: .medium)
        progressLabel.frame = NSRect(x: 30, y: 130, width: 240, height: 22)
        mainPage.addSubview(progressLabel)
        etaLabel.font = .systemFont(ofSize: 15, weight: .medium)
        etaLabel.textColor = .controlAccentColor
        etaLabel.frame = NSRect(x: 30, y: 106, width: 240, height: 22)
        mainPage.addSubview(etaLabel)
        addSeparator(to: mainPage, y: 96)

        resetButton.title = L10n.text("준비 상태로 돌아가기", "Return to Ready")
        resetButton.font = .systemFont(ofSize: 17, weight: .semibold)
        resetButton.frame = NSRect(x: 20, y: 53, width: 260, height: 36)
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(reset)
        mainPage.addSubview(resetButton)
        addSeparator(to: mainPage, y: 43)

        let quit = NSButton(title: L10n.text("앱 종료", "Quit App"), target: self, action: #selector(quitApp))
        quit.isBordered = false
        quit.alignment = .left
        quit.font = .systemFont(ofSize: 16, weight: .medium)
        quit.frame = NSRect(x: 20, y: 7, width: 250, height: 27)
        mainPage.addSubview(quit)
        let quitShortcut = NSTextField(labelWithString: "⌘Q")
        quitShortcut.font = .systemFont(ofSize: 16, weight: .medium)
        quitShortcut.alignment = .right
        quitShortcut.frame = NSRect(x: 200, y: 11, width: 70, height: 22)
        mainPage.addSubview(quitShortcut)
    }

    private func addSeparator(to root: NSView, y: CGFloat) {
        let line = NSBox(frame: NSRect(x: 20, y: y, width: 260, height: 1))
        line.boxType = .separator
        root.addSubview(line)
    }

    @objc private func navigate(_ sender: DashboardNavigationButton) {
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
        for (candidate, button) in pageButtons { button.isSelected = candidate == page }
        switch page {
        case .main:
            contentPanel.addSubview(mainPage)
        case .icon:
            addSectionHeader(L10n.text("모양", "Appearance"), y: 398)
            let view = SettingsAppearanceMenuItemView(selectedStyle: AppPreferences.iconStyle,
                                                       onSelection: onIconChange)
            view.frame.origin = NSPoint(x: 0, y: 150)
            iconView = view
            contentPanel.addSubview(view)
        case .history:
            let controller = RunHistoryViewController(
                entries: RunHistoryStore.load(),
                fixedPanelHeight: contentPanel.bounds.height,
                onClear: onClearHistory
            )
            controller.loadView()
            controller.view.frame.origin = NSPoint(x: 10, y: 0)
            historyController = controller
            contentPanel.addSubview(controller.view)
        case .settings:
            addSectionHeader(L10n.text("기본", "Basic"), y: 398)
            let language = SettingsLanguageMenuItemView(selectedLanguage: AppPreferences.language,
                                                         onSelection: onLanguageChange)
            language.frame.origin = NSPoint(x: 0, y: 338)
            languageView = language
            contentPanel.addSubview(language)
            addSectionHeader(L10n.text("고급", "Advanced"), y: 270)
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
            advanced.frame.origin = NSPoint(x: 0, y: 120)
            advancedView = advanced
            contentPanel.addSubview(advanced)
        }
    }

    private func addSectionHeader(_ title: String, y: CGFloat) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 14, y: y, width: 260, height: 20)
        contentPanel.addSubview(label)
        let line = NSBox(frame: NSRect(x: 14, y: y - 9, width: 272, height: 1))
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
        progressLabel.attributedStringValue = progress ?? placeholder(L10n.text("진행률: --%", "Progress: --%"))
        etaLabel.attributedStringValue = eta ?? placeholder(L10n.text("예상 남은 시간: --:--:--", "ETA: --:--:--"))
        resetButton.isEnabled = canReset
    }

    func setUpdateState(title: String, enabled: Bool) {
        advancedView?.setUpdateState(title: title, enabled: enabled)
    }

    func resetToMain() {
        show(.main)
    }

    private func placeholder(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor
        ])
    }

    @objc private func reset() { onReset() }
    @objc private func quitApp() { onQuit() }
}
