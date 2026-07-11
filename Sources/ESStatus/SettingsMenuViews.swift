import AppKit

@MainActor
final class ReturnToReadyMenuItemView: NSView {
    private let onReset: () -> Void
    private let viewSize = NSSize(width: 300, height: 40)
    private var isTerminal = false
    private var isPressed = false

    init(onReset: @escaping () -> Void) {
        self.onReset = onReset
        super.init(frame: NSRect(origin: .zero, size: viewSize))
        setAccessibilityRole(.button)
        setAccessibilityLabel(L10n.text("준비 상태로 돌아가기", "Return to Ready"))
        setTerminalState(false)
    }

    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { viewSize }

    func setTerminalState(_ isTerminal: Bool) {
        self.isTerminal = isTerminal
        if !isTerminal { isPressed = false }
        setAccessibilityEnabled(isTerminal)
        toolTip = isTerminal
            ? L10n.text("완료된 상태를 지우고 대기 상태로 돌아갑니다.",
                        "Clear the finished status and return to Ready.")
            : L10n.text("작업이 완료·실패·중단된 후 사용할 수 있습니다.",
                        "Available after a task completes, fails, or is interrupted.")
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let buttonRect = bounds.insetBy(dx: 12, dy: 5)
        let path = NSBezierPath(roundedRect: buttonRect, xRadius: 7, yRadius: 7)
        let fillColor: NSColor
        if !isTerminal {
            fillColor = NSColor(calibratedWhite: 0.84, alpha: 1)
        } else if isPressed {
            fillColor = NSColor.controlAccentColor.blended(withFraction: 0.18, of: .black)
                ?? NSColor.controlAccentColor
        } else {
            fillColor = NSColor.controlAccentColor
        }
        fillColor.setFill()
        path.fill()

        let title = NSAttributedString(
            string: L10n.text("준비 상태로 돌아가기", "Return to Ready"),
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: isTerminal ? NSColor.white : NSColor(calibratedWhite: 0.42, alpha: 1)
            ]
        )
        let titleSize = title.size()
        title.draw(at: NSPoint(
            x: buttonRect.midX - titleSize.width / 2,
            y: buttonRect.midY - titleSize.height / 2
        ))
    }

    override func mouseDown(with event: NSEvent) {
        guard isTerminal else { return }
        isPressed = buttonRect.contains(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isTerminal else { return }
        isPressed = buttonRect.contains(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isTerminal else { return }
        let shouldReset = isPressed && buttonRect.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        needsDisplay = true
        if shouldReset { onReset() }
    }

    private var buttonRect: NSRect { bounds.insetBy(dx: 12, dy: 5) }
}

@MainActor
final class SettingsAppearanceMenuItemView: NSView {
    private let onSelection: (StatusIconStyle) -> Void
    private var selectedStyle: StatusIconStyle
    private var styleButtons: [StatusIconStyle: NSButton] = [:]
    private var previewImages: [StatusVisualState: NSImageView] = [:]
    private var previewLabels: [StatusVisualState: NSTextField] = [:]
    private let previewHeader = NSTextField(labelWithString: "")

    private let panelSize = NSSize(width: 500, height: 226)

    init(selectedStyle: StatusIconStyle,
         onSelection: @escaping (StatusIconStyle) -> Void) {
        self.selectedStyle = selectedStyle
        self.onSelection = onSelection
        super.init(frame: NSRect(origin: .zero, size: panelSize))
        buildStyleColumn()
        buildPreviewColumn()
        refreshSelection()
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize { panelSize }

    private func buildStyleColumn() {
        let rowHeight: CGFloat = 30
        for (index, style) in StatusIconStyle.allCases.enumerated() {
            let button = NSButton(
                frame: NSRect(x: 10, y: panelSize.height - 32 - CGFloat(index) * rowHeight,
                              width: 218, height: 28)
            )
            button.bezelStyle = .inline
            button.isBordered = false
            button.alignment = .left
            button.font = .menuFont(ofSize: 0)
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            button.image = StatusIconRenderer.image(style: style, state: .running, size: 19)
            button.tag = index
            button.target = self
            button.action = #selector(selectStyle(_:))
            button.toolTip = style.displayName
            addSubview(button)
            styleButtons[style] = button
        }
    }

    private func buildPreviewColumn() {
        let divider = NSBox(frame: NSRect(x: 235, y: 10, width: 1, height: 206))
        divider.boxType = .separator
        addSubview(divider)

        previewHeader.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        previewHeader.textColor = .secondaryLabelColor
        previewHeader.frame = NSRect(x: 252, y: 196, width: 220, height: 20)
        addSubview(previewHeader)

        let states: [(StatusVisualState, String)] = [
            (.running, L10n.text("실행 중", "Running")),
            (.complete, L10n.text("완료", "Complete")),
            (.fail, L10n.text("실패", "Fail")),
            (.interrupted, L10n.text("중단됨", "Interrupted"))
        ]

        for (index, entry) in states.enumerated() {
            let column = index % 2
            let row = index / 2
            let originX = 252 + CGFloat(column) * 118
            let originY = 104 - CGFloat(row) * 88

            let imageView = NSImageView(frame: NSRect(x: originX + 36, y: originY + 30,
                                                       width: 34, height: 34))
            imageView.imageScaling = .scaleNone
            addSubview(imageView)
            previewImages[entry.0] = imageView

            let label = NSTextField(labelWithString: entry.1)
            label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            label.alignment = .center
            label.frame = NSRect(x: originX, y: originY + 6, width: 106, height: 20)
            addSubview(label)
            previewLabels[entry.0] = label
        }
        applyLocalization()
    }

    @objc private func selectStyle(_ sender: NSButton) {
        guard StatusIconStyle.allCases.indices.contains(sender.tag) else { return }
        selectedStyle = StatusIconStyle.allCases[sender.tag]
        refreshSelection()
        onSelection(selectedStyle)
    }

    private func refreshSelection() {
        for (style, button) in styleButtons {
            button.title = style == selectedStyle ? "✓  \(style.displayName)" : "    \(style.displayName)"
            button.contentTintColor = style == selectedStyle ? .controlAccentColor : .labelColor
        }
        for (state, imageView) in previewImages {
            imageView.image = StatusIconRenderer.image(style: selectedStyle, state: state, size: 30)
        }
    }

    func applyLocalization() {
        previewHeader.stringValue = L10n.text("상태 미리보기", "State Preview")
        previewLabels[.running]?.stringValue = L10n.text("실행 중", "Running")
        previewLabels[.complete]?.stringValue = L10n.text("완료", "Complete")
        previewLabels[.fail]?.stringValue = L10n.text("실패", "Fail")
        previewLabels[.interrupted]?.stringValue = L10n.text("중단됨", "Interrupted")
    }
}

@MainActor
final class SettingsLanguageMenuItemView: NSView {
    private let onSelection: (AppLanguage) -> Void
    private var selectedLanguage: AppLanguage
    private var buttons: [AppLanguage: NSButton] = [:]
    private let titleLabel = NSTextField(labelWithString: "")
    private let panelSize = NSSize(width: 500, height: 44)

    init(selectedLanguage: AppLanguage,
         onSelection: @escaping (AppLanguage) -> Void) {
        self.selectedLanguage = selectedLanguage
        self.onSelection = onSelection
        super.init(frame: NSRect(origin: .zero, size: panelSize))

        titleLabel.font = .menuFont(ofSize: 0)
        titleLabel.frame = NSRect(x: 14, y: 12, width: 100, height: 20)
        addSubview(titleLabel)

        for (index, language) in AppLanguage.allCases.enumerated() {
            let button = NSButton(frame: NSRect(x: 126 + CGFloat(index) * 120,
                                                y: 7, width: 112, height: 30))
            button.bezelStyle = .roundRect
            button.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
            button.tag = index
            button.target = self
            button.action = #selector(selectLanguage(_:))
            addSubview(button)
            buttons[language] = button
        }
        applyLocalization()
    }

    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { panelSize }

    @objc private func selectLanguage(_ sender: NSButton) {
        guard AppLanguage.allCases.indices.contains(sender.tag) else { return }
        selectedLanguage = AppLanguage.allCases[sender.tag]
        onSelection(selectedLanguage)
        applyLocalization()
    }

    private func refreshSelection() {
        for (language, button) in buttons {
            button.title = language == selectedLanguage
                ? "✓ \(language.displayName)"
                : language.displayName
            button.contentTintColor = language == selectedLanguage ? .controlAccentColor : .labelColor
        }
    }

    func applyLocalization() {
        titleLabel.stringValue = L10n.text("언어", "Language")
        refreshSelection()
    }
}

@MainActor
private final class AdvancedToggleTile: NSView {
    private let toggle = NSSwitch()
    private let stateLabel = NSTextField(labelWithString: "")
    private var onText: String
    private var offText: String
    private let onChange: (Bool) -> Void
    private let titleLabel = NSTextField(labelWithString: "")

    init(frame: NSRect, title: String, isOn: Bool, onText: String, offText: String,
         onChange: @escaping (Bool) -> Void) {
        self.onText = onText
        self.offText = offText
        self.onChange = onChange
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: 10, y: 33, width: frame.width - 20, height: 18)
        addSubview(titleLabel)

        stateLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        stateLabel.frame = NSRect(x: 10, y: 10, width: frame.width - 82, height: 18)
        addSubview(stateLabel)

        toggle.state = isOn ? .on : .off
        toggle.frame = NSRect(x: frame.width - 64, y: 5, width: 52, height: 28)
        toggle.target = self
        toggle.action = #selector(toggleChanged)
        addSubview(toggle)
        updateStateLabel()
    }

    required init?(coder: NSCoder) { nil }

    @objc private func toggleChanged() {
        updateStateLabel()
        onChange(toggle.state == .on)
    }

    private func updateStateLabel() {
        let isOn = toggle.state == .on
        stateLabel.stringValue = isOn ? onText : offText
        stateLabel.textColor = isOn ? .controlAccentColor : .secondaryLabelColor
    }

    func applyLocalization(title: String, onText: String, offText: String) {
        titleLabel.stringValue = title
        self.onText = onText
        self.offText = offText
        updateStateLabel()
    }
}

@MainActor
final class SettingsAdvancedMenuItemView: NSView {
    private let updateButton = NSButton()
    private var elapsedTile: AdvancedToggleTile!
    private var loginTile: AdvancedToggleTile!
    private var notificationsTile: AdvancedToggleTile!
    private let panelSize = NSSize(width: 500, height: 132)

    init(showElapsedTime: Bool, launchAtLogin: Bool, notificationsEnabled: Bool,
         onElapsedTimeChange: @escaping (Bool) -> Void,
         onLaunchAtLoginChange: @escaping (Bool) -> Void,
         onNotificationsChange: @escaping (Bool) -> Void,
         onCheckForUpdates: @escaping () -> Void) {
        self.onCheckForUpdates = onCheckForUpdates
        super.init(frame: NSRect(origin: .zero, size: panelSize))
        let onText = L10n.text("켜짐", "ON")
        let offText = L10n.text("꺼짐", "OFF")
        let tileSize = NSSize(width: 235, height: 58)
        let frames = [
            NSRect(x: 10, y: 68, width: tileSize.width, height: tileSize.height),
            NSRect(x: 255, y: 68, width: tileSize.width, height: tileSize.height),
            NSRect(x: 10, y: 4, width: tileSize.width, height: tileSize.height),
            NSRect(x: 255, y: 4, width: tileSize.width, height: tileSize.height)
        ]

        elapsedTile = AdvancedToggleTile(
            frame: frames[0],
            title: L10n.text("메뉴바 실행 시간", "Elapsed Time in Menu Bar"),
            isOn: showElapsedTime, onText: onText, offText: offText,
            onChange: onElapsedTimeChange
        )
        addSubview(elapsedTile)
        loginTile = AdvancedToggleTile(
            frame: frames[1],
            title: L10n.text("로그인 시 실행", "Launch at Login"),
            isOn: launchAtLogin, onText: onText, offText: offText,
            onChange: onLaunchAtLoginChange
        )
        addSubview(loginTile)
        notificationsTile = AdvancedToggleTile(
            frame: frames[2],
            title: L10n.text("macOS 알림", "macOS Notifications"),
            isOn: notificationsEnabled, onText: onText, offText: offText,
            onChange: onNotificationsChange
        )
        addSubview(notificationsTile)

        let updateTile = NSView(frame: frames[3])
        updateTile.wantsLayer = true
        updateTile.layer?.cornerRadius = 8
        updateTile.layer?.borderWidth = 1
        updateTile.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(updateTile)

        updateButton.frame = NSRect(x: 10, y: 10, width: tileSize.width - 20, height: 38)
        updateButton.bezelStyle = .roundRect
        updateButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates)
        updateTile.addSubview(updateButton)
        setUpdateState(title: L10n.text("업데이트 확인…", "Check for Updates…"), enabled: true)
    }

    private let onCheckForUpdates: () -> Void

    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { panelSize }

    func setUpdateState(title: String, enabled: Bool) {
        updateButton.title = title
        updateButton.isEnabled = enabled
    }

    func applyLocalization() {
        let onText = L10n.text("켜짐", "ON")
        let offText = L10n.text("꺼짐", "OFF")
        elapsedTile.applyLocalization(
            title: L10n.text("메뉴바 실행 시간", "Elapsed Time in Menu Bar"),
            onText: onText, offText: offText
        )
        loginTile.applyLocalization(
            title: L10n.text("로그인 시 실행", "Launch at Login"),
            onText: onText, offText: offText
        )
        notificationsTile.applyLocalization(
            title: L10n.text("macOS 알림", "macOS Notifications"),
            onText: onText, offText: offText
        )
        if updateButton.isEnabled {
            updateButton.title = L10n.text("업데이트 확인…", "Check for Updates…")
        }
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }
}

@MainActor
final class SettingsToggleMenuItemView: NSView {
    private let onChange: (Bool) -> Void
    private let toggle = NSSwitch()
    private let stateLabel = NSTextField(labelWithString: "")
    private let onText: String
    private let offText: String

    init(title: String, isOn: Bool, onText: String, offText: String,
         onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        self.onText = onText
        self.offText = offText
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 40))

        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 0)
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false

        toggle.state = isOn ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggleChanged)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        toggle.translatesAutoresizingMaskIntoConstraints = false

        stateLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        stateLabel.alignment = .right
        stateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        stateLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        addSubview(stateLabel)
        addSubview(toggle)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
            stateLabel.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -8),
            stateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            stateLabel.widthAnchor.constraint(equalToConstant: 38),
            label.trailingAnchor.constraint(lessThanOrEqualTo: stateLabel.leadingAnchor, constant: -10)
        ])
        updateStateLabel()
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 320, height: 40)
    }

    @objc private func toggleChanged() {
        updateStateLabel()
        onChange(toggle.state == .on)
    }

    private func updateStateLabel() {
        let isOn = toggle.state == .on
        stateLabel.stringValue = isOn ? onText : offText
        stateLabel.textColor = isOn ? .controlAccentColor : .secondaryLabelColor
    }
}
