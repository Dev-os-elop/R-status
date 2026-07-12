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
        layer?.cornerRadius = 15
        iconView.image = image
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        if title == "Open RStudio" {
            titleLabel.maximumNumberOfLines = 2
            titleLabel.lineBreakMode = .byWordWrapping
        }
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        addSubview(titleLabel)
        updateBackground()
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let isOpenRStudio = titleLabel.stringValue == "Open RStudio"
        let labelHeight: CGFloat = isOpenRStudio ? 28 : 17
        let gap: CGFloat = isOpenRStudio ? 2 : 3
        let groupHeight = labelHeight + gap + 22
        let groupY = (bounds.height - groupHeight) / 2
        iconView.frame = NSRect(x: bounds.midX - 11,
                                y: groupY + labelHeight + gap,
                                width: 22, height: 22)
        titleLabel.frame = NSRect(x: 6,
                                  y: groupY,
                                  width: bounds.width - 12,
                                  height: labelHeight)
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
                : effectiveAppearance.esPanelColor.cgColor
    }

    func refreshAppearance() {
        updateBackground()
        iconView.needsDisplay = true
        titleLabel.needsDisplay = true
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
    private let executionHeader = NSTextField(labelWithString: "")
    private let executionSeparator = NSBox()
    private let footerSeparator = NSBox()
    private let resetButton = NSButton()
    private var pageButtons: [Page: DashboardNavigationButton] = [:]
    private var navigationButtons: [DashboardNavigationButton] = []
    private var currentPage: Page = .main
    private var iconView: SettingsAppearanceMenuItemView?
    private var historyController: RunHistoryViewController?
    private var languageView: SettingsLanguageMenuItemView?
    private var advancedView: SettingsAdvancedMenuItemView?
    private let settingsUpdateTile = NSView()
    private let settingsUpdateButton = NSButton()
    private let settingsVersionLabel = NSTextField(labelWithString: "")

    private let onReset: () -> Void
    private let onOpenR: () -> Void
    private let onQuit: () -> Void
    private let onIconChange: (StatusIconStyle) -> Void
    private let onLanguageChange: (AppLanguage) -> Void
    private let onElapsedChange: (Bool) -> Void
    private let onLoginChange: (Bool) -> Void
    private let onNotificationsChange: (Bool) -> Void
    private let onDarkModeChange: (Bool) -> Void
    private let onCheckUpdates: () -> Void
    private let onClearHistory: () -> Void
    private let version: String

    let panelSize = NSSize(width: 430, height: 440)

    init(version: String,
         onReset: @escaping () -> Void,
         onOpenR: @escaping () -> Void,
         onQuit: @escaping () -> Void,
         onIconChange: @escaping (StatusIconStyle) -> Void,
         onLanguageChange: @escaping (AppLanguage) -> Void,
         onElapsedChange: @escaping (Bool) -> Void,
         onLoginChange: @escaping (Bool) -> Void,
         onNotificationsChange: @escaping (Bool) -> Void,
         onDarkModeChange: @escaping (Bool) -> Void,
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
        self.onDarkModeChange = onDarkModeChange
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
        view.layer?.backgroundColor = effectiveAppearance.esPanelColor.cgColor
        view.layer?.cornerRadius = radius
    }

    private func buildShell() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.70).cgColor

        contentPanel.frame = NSRect(x: 14, y: 14, width: 300, height: 412)
        navigationPanel.frame = NSRect(x: 328, y: 14, width: 88, height: 412)
        stylePanel(contentPanel, radius: 22)
        addSubview(contentPanel)
        addSubview(navigationPanel)

        let entries: [(Page?, String, String)] = [
            (.main, "house", "Main"),
            (.icon, "paintpalette", "Icon"),
            (.history, "clock.arrow.circlepath", "History"),
            (nil, "r.square", "Open RStudio"),
            (.settings, "gearshape", "Settings")
        ]
        let heights: [CGFloat] = [58, 64, 64, 64, 64]
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
                frame: NSRect(x: 3, y: top + 4, width: 82, height: height - 8),
                title: entry.2,
                image: image
            )
            button.tag = index
            button.target = self
            button.action = #selector(navigate(_:))
            navigationPanel.addSubview(button)
            navigationButtons.append(button)
            if let page = entry.0 { pageButtons[page] = button }
        }
        buildMainPage()
    }

    private func buildMainPage() {
        mainPage.frame = contentPanel.bounds
        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.frame = NSRect(x: 20, y: 362, width: 260, height: 28)
        mainPage.addSubview(statusLabel)
        addSeparator(to: mainPage, y: 346)

        let header = NSTextField(labelWithString: L10n.text("리소스 사용량", "Resource Usage"))
        header.font = .systemFont(ofSize: 10, weight: .medium)
        header.frame = NSRect(x: 20, y: 308, width: 260, height: 26)
        mainPage.addSubview(header)

        for (index, label) in [cpuLabel, memoryLabel, workersLabel, processesLabel].enumerated() {
            label.font = .systemFont(ofSize: 11, weight: .medium)
            label.textColor = .controlAccentColor
            label.frame = NSRect(x: 30, y: 282 - CGFloat(index) * 24, width: 240, height: 24)
            mainPage.addSubview(label)
        }
        detailLabel.font = .systemFont(ofSize: 8)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.frame = NSRect(x: 30, y: 188, width: 240, height: 18)
        mainPage.addSubview(detailLabel)
        executionHeader.stringValue = L10n.text("실행 진행 상황", "Execution Progress")
        executionHeader.font = .systemFont(ofSize: 10, weight: .medium)
        mainPage.addSubview(executionHeader)
        elapsedLabel.font = .systemFont(ofSize: 11, weight: .medium)
        elapsedLabel.textColor = .controlAccentColor
        mainPage.addSubview(elapsedLabel)
        progressLabel.font = .systemFont(ofSize: 11, weight: .medium)
        mainPage.addSubview(progressLabel)
        etaLabel.font = .systemFont(ofSize: 11, weight: .medium)
        etaLabel.textColor = .controlAccentColor
        mainPage.addSubview(etaLabel)
        executionSeparator.boxType = .separator
        mainPage.addSubview(executionSeparator)
        layoutExecutionSection(hasDetail: false)

        resetButton.title = L10n.text("준비 상태로 돌아가기", "Return to Ready")
        resetButton.font = .systemFont(ofSize: 13, weight: .semibold)
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(reset)
        mainPage.addSubview(resetButton)
        footerSeparator.boxType = .separator
        mainPage.addSubview(footerSeparator)
        layoutExecutionSection(hasDetail: false)

        let appName = NSTextField(labelWithString: "ES Status")
        appName.font = .systemFont(ofSize: 10, weight: .semibold)
        appName.textColor = .secondaryLabelColor
        appName.frame = NSRect(x: 20, y: 10, width: 120, height: 18)
        mainPage.addSubview(appName)
        let versionText = NSTextField(labelWithString: "v\(version)")
        versionText.font = .systemFont(ofSize: 9, weight: .regular)
        versionText.textColor = .secondaryLabelColor
        versionText.alignment = .right
        versionText.frame = NSRect(x: 160, y: 10, width: 120, height: 18)
        mainPage.addSubview(versionText)
    }

    private func addSeparator(to root: NSView, y: CGFloat) {
        let line = NSBox(frame: NSRect(x: 20, y: y, width: 260, height: 1))
        line.boxType = .separator
        root.addSubview(line)
    }

    private func layoutExecutionSection(hasDetail: Bool) {
        let headerY: CGFloat = hasDetail ? 166 : 178
        executionHeader.frame = NSRect(x: 20, y: headerY, width: 260, height: 22)
        elapsedLabel.frame = NSRect(x: 30, y: headerY - 24, width: 240, height: 22)
        progressLabel.frame = NSRect(x: 30, y: headerY - 48, width: 240, height: 22)
        etaLabel.frame = NSRect(x: 30, y: headerY - 72, width: 240, height: 22)
        let upperLineY = headerY - 82
        executionSeparator.frame = NSRect(x: 20, y: upperLineY, width: 260, height: 1)
        resetButton.frame = NSRect(x: 20, y: upperLineY - 46, width: 260, height: 36)
        footerSeparator.frame = NSRect(x: 20, y: upperLineY - 56, width: 260, height: 1)
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
            addSectionHeader(L10n.text("모양", "Appearance"), y: 378)
            let view = SettingsAppearanceMenuItemView(selectedStyle: AppPreferences.iconStyle,
                                                       onSelection: onIconChange)
            view.frame.origin = NSPoint(x: 0, y: 20)
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
            addSectionHeader(L10n.text("언어", "Language"), y: 378)
            let language = SettingsLanguageMenuItemView(selectedLanguage: AppPreferences.language,
                                                         onSelection: onLanguageChange)
            language.frame.origin = NSPoint(x: 0, y: 280)
            languageView = language
            contentPanel.addSubview(language)
            addSectionHeader(L10n.text("고급", "Advanced"), y: 250)
            let advanced = SettingsAdvancedMenuItemView(
                showElapsedTime: AppPreferences.showElapsedTime,
                launchAtLogin: SMAppService.mainApp.status == .enabled,
                notificationsEnabled: AppPreferences.notificationsEnabled,
                darkModeEnabled: AppPreferences.darkModeEnabled,
                onElapsedTimeChange: onElapsedChange,
                onLaunchAtLoginChange: onLoginChange,
                onNotificationsChange: onNotificationsChange,
                onDarkModeChange: onDarkModeChange
            )
            advanced.frame.origin = NSPoint(x: 0, y: 100)
            advancedView = advanced
            contentPanel.addSubview(advanced)

            settingsUpdateTile.frame = NSRect(x: 10, y: 54, width: 280, height: 40)
            settingsUpdateTile.wantsLayer = true
            settingsUpdateTile.layer?.cornerRadius = 8
            settingsUpdateTile.layer?.borderWidth = 1
            settingsUpdateTile.layer?.borderColor = NSColor.separatorColor.cgColor
            settingsUpdateTile.layer?.backgroundColor = effectiveAppearance.esTileColor.cgColor
            settingsUpdateButton.frame = NSRect(x: 10, y: 12, width: 260, height: 26)
            settingsUpdateButton.bezelStyle = .roundRect
            settingsUpdateButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
            settingsUpdateButton.target = self
            settingsUpdateButton.action = #selector(checkUpdates)
            settingsUpdateTile.addSubview(settingsUpdateButton)
            settingsVersionLabel.stringValue = "v\(version)"
            settingsVersionLabel.font = .systemFont(ofSize: 9)
            settingsVersionLabel.textColor = .secondaryLabelColor
            settingsVersionLabel.alignment = .center
            settingsVersionLabel.frame = NSRect(x: 10, y: 0, width: 260, height: 12)
            settingsUpdateTile.addSubview(settingsVersionLabel)
            settingsUpdateButton.title = L10n.text("업데이트 확인…", "Check for Updates…")
            contentPanel.addSubview(settingsUpdateTile)

            let separator = NSBox(frame: NSRect(x: 14, y: 48, width: 272, height: 1))
            separator.boxType = .separator
            contentPanel.addSubview(separator)
            let quitButton = NSButton(
                title: L10n.text("앱 종료", "Quit App"),
                target: self,
                action: #selector(quitApp)
            )
            quitButton.image = NSImage(systemSymbolName: "power",
                                       accessibilityDescription: quitButton.title)
            quitButton.imagePosition = .imageLeading
            quitButton.font = .systemFont(ofSize: 12, weight: .medium)
            quitButton.bezelStyle = .rounded
            quitButton.frame = NSRect(x: 10, y: 7, width: 280, height: 34)
            quitButton.alphaValue = 0.70
            contentPanel.addSubview(quitButton)
        }
    }

    private func addSectionHeader(_ title: String,
                                  y: CGFloat,
                                  alignment: NSTextAlignment = .left) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 14, y: y, width: 272, height: 20)
        label.alignment = alignment
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
        detailLabel.isHidden = detail.isEmpty
        layoutExecutionSection(hasDetail: !detail.isEmpty)
        elapsedLabel.stringValue = elapsed.isEmpty
            ? L10n.text("실행 시간: --:--", "Elapsed time: --:--")
            : elapsed
        cpuLabel.stringValue = cpu
        memoryLabel.stringValue = memory
        workersLabel.stringValue = workers
        processesLabel.stringValue = processes
        progressLabel.attributedStringValue = progress ?? placeholder(L10n.text("진행률: --%", "Progress: --%"))
        etaLabel.attributedStringValue = eta ?? placeholder(L10n.text("남은 시간: --:--:--", "Remaining: --:--:--"))
        resetButton.isEnabled = canReset
    }

    func setUpdateState(title: String, enabled: Bool) {
        settingsUpdateButton.title = title
        settingsUpdateButton.isEnabled = enabled
    }

    func refreshAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            window?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.70)
            layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.70).cgColor
            contentPanel.layer?.backgroundColor = effectiveAppearance.esPanelColor.cgColor
            settingsUpdateTile.layer?.backgroundColor = effectiveAppearance.esTileColor.cgColor
            settingsUpdateTile.layer?.borderColor = NSColor.separatorColor.cgColor
            navigationButtons.forEach { $0.refreshAppearance() }
            languageView?.refreshAppearance()
            advancedView?.refreshAppearance()
        }
        needsDisplay = true
        displayIfNeeded()
    }

    func resetToMain() {
        show(.main)
    }

    private func placeholder(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor
        ])
    }

    @objc private func reset() { onReset() }
    @objc private func quitApp() { onQuit() }
    @objc private func checkUpdates() { onCheckUpdates() }
}
