import AppKit

@MainActor
final class LeadingActionMenuItemView: NSView {
    private let title: String
    private let shortcut: String
    private let keyEquivalent: String
    private let onAction: () -> Void
    private var isPressed = false
    private var isHovered = false
    private var hoverTrackingArea: NSTrackingArea?
    private let viewSize = NSSize(width: 300, height: 30)

    init(title: String, shortcut: String, keyEquivalent: String,
         onAction: @escaping () -> Void) {
        self.title = title
        self.shortcut = shortcut
        self.keyEquivalent = keyEquivalent
        self.onAction = onAction
        super.init(frame: NSRect(origin: .zero, size: viewSize))
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { viewSize }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let isHighlighted = isHovered || isPressed
        if isHighlighted {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 5, yRadius: 5).fill()
        }

        let titleColor: NSColor = isHighlighted ? .white : .labelColor
        let shortcutColor: NSColor = isHighlighted ? .white : .tertiaryLabelColor
        let font = NSFont.menuFont(ofSize: 0)
        let titleString = NSAttributedString(
            string: title,
            attributes: [.font: font, .foregroundColor: titleColor]
        )
        let shortcutString = NSAttributedString(
            string: shortcut,
            attributes: [.font: font, .foregroundColor: shortcutColor]
        )
        let titleSize = titleString.size()
        let shortcutSize = shortcutString.size()
        titleString.draw(at: NSPoint(x: 14, y: bounds.midY - titleSize.height / 2))
        shortcutString.draw(at: NSPoint(x: bounds.maxX - 14 - shortcutSize.width,
                                        y: bounds.midY - shortcutSize.height / 2))
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = bounds.contains(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        isPressed = bounds.contains(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let shouldRun = isPressed && bounds.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        needsDisplay = true
        guard shouldRun else { return }
        performAction()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              event.charactersIgnoringModifiers?.lowercased() == keyEquivalent else {
            return false
        }
        performAction()
        return true
    }

    override func accessibilityPerformPress() -> Bool {
        performAction()
        return true
    }

    private func performAction() {
        isHovered = false
        isPressed = false
        needsDisplay = true
        enclosingMenuItem?.menu?.cancelTracking()
        DispatchQueue.main.async { [onAction] in onAction() }
    }
}

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

    private let panelSize = NSSize(width: 300, height: 330)

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
        let rowHeight: CGFloat = 34
        for (index, style) in StatusIconStyle.allCases.enumerated() {
            let column = index % 2
            let row = index / 2
            let button = NSButton(
                frame: NSRect(x: 6 + CGFloat(column) * 147,
                              y: 294 - CGFloat(row) * rowHeight,
                              width: 141, height: 30)
            )
            button.bezelStyle = .inline
            button.isBordered = false
            button.alignment = .center
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
        let divider = NSBox(frame: NSRect(x: 12, y: 154, width: 276, height: 1))
        divider.boxType = .separator
        addSubview(divider)

        previewHeader.font = .systemFont(ofSize: 14, weight: .semibold)
        previewHeader.textColor = .secondaryLabelColor
        previewHeader.frame = NSRect(x: 14, y: 126, width: 272, height: 20)
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
            let originX = 10 + CGFloat(column) * 145
            let originY = 64 - CGFloat(row) * 60

            let imageView = NSImageView(frame: NSRect(x: originX + 50, y: originY + 25,
                                                       width: 34, height: 34))
            imageView.imageScaling = .scaleNone
            addSubview(imageView)
            previewImages[entry.0] = imageView

            let label = NSTextField(labelWithString: entry.1)
            label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            label.alignment = .center
            label.frame = NSRect(x: originX, y: originY + 3, width: 135, height: 20)
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
    private let panelSize = NSSize(width: 300, height: 82)

    init(selectedLanguage: AppLanguage,
         onSelection: @escaping (AppLanguage) -> Void) {
        self.selectedLanguage = selectedLanguage
        self.onSelection = onSelection
        super.init(frame: NSRect(origin: .zero, size: panelSize))

        let frames = [
            NSRect(x: 6, y: 45, width: 288, height: 30),
            NSRect(x: 6, y: 7, width: 141, height: 30),
            NSRect(x: 153, y: 7, width: 141, height: 30)
        ]
        for (index, language) in AppLanguage.allCases.enumerated() {
            let button = NSButton(frame: frames[index])
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 7
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
            button.layer?.backgroundColor = language == selectedLanguage
                ? NSColor.controlAccentColor.withAlphaComponent(0.20).cgColor
                : effectiveAppearance.esTileColor.cgColor
        }
    }

    func applyLocalization() {
        refreshSelection()
    }

    func refreshAppearance() {
        refreshSelection()
        needsDisplay = true
    }
}

@MainActor
private final class AccentSwitch: NSControl {
    private let trackLayer = CALayer()
    private let knobLayer = CALayer()

    var state: NSControl.StateValue = .off {
        didSet {
            guard oldValue != state else { return }
            updateLayers(animated: window != nil)
        }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 52, height: 28) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayers()
    }

    private func configureLayers() {
        wantsLayer = true
        trackLayer.masksToBounds = true
        knobLayer.backgroundColor = NSColor.white.cgColor
        knobLayer.shadowColor = NSColor.black.cgColor
        knobLayer.shadowOpacity = 0.12
        knobLayer.shadowRadius = 1
        knobLayer.shadowOffset = CGSize(width: 0, height: -0.5)
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(knobLayer)
    }

    override func layout() {
        super.layout()
        updateLayers(animated: false)
    }

    private func updateLayers(animated: Bool) {
        let trackRect = bounds.insetBy(dx: 1, dy: 4)
        let trackColor = (state == .on
            ? NSColor.controlAccentColor
            : NSColor(calibratedWhite: 0.78, alpha: 0.70)).cgColor

        let knobSize = trackRect.height - 4
        let knobCenterX = state == .on
            ? trackRect.maxX - knobSize / 2 - 2
            : trackRect.minX + knobSize / 2 + 2
        let knobPosition = CGPoint(x: knobCenterX, y: trackRect.midY)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = trackRect
        trackLayer.cornerRadius = trackRect.height / 2
        knobLayer.bounds = CGRect(x: 0, y: 0, width: knobSize, height: knobSize)
        knobLayer.cornerRadius = knobSize / 2

        if animated {
            let timing = CAMediaTimingFunction(name: .easeInEaseOut)
            let positionAnimation = CABasicAnimation(keyPath: "position")
            positionAnimation.fromValue = knobLayer.presentation()?.position ?? knobLayer.position
            positionAnimation.toValue = knobPosition
            positionAnimation.duration = 0.20
            positionAnimation.timingFunction = timing
            knobLayer.add(positionAnimation, forKey: "switchPosition")

            let colorAnimation = CABasicAnimation(keyPath: "backgroundColor")
            colorAnimation.fromValue = trackLayer.presentation()?.backgroundColor ?? trackLayer.backgroundColor
            colorAnimation.toValue = trackColor
            colorAnimation.duration = 0.20
            colorAnimation.timingFunction = timing
            trackLayer.add(colorAnimation, forKey: "switchColor")
        }

        knobLayer.position = knobPosition
        trackLayer.backgroundColor = trackColor
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        state = state == .on ? .off : .on
        sendAction(action, to: target)
    }

    func refreshAppearance() {
        updateLayers(animated: false)
    }
}

@MainActor
private final class AdvancedToggleTile: NSView {
    private let toggle = AccentSwitch()
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
        layer?.backgroundColor = effectiveAppearance.esTileColor.cgColor

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

    func refreshAppearance() {
        layer?.backgroundColor = effectiveAppearance.esTileColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
        titleLabel.textColor = .labelColor
        updateStateLabel()
        toggle.refreshAppearance()
        needsDisplay = true
    }
}

@MainActor
final class SettingsAdvancedMenuItemView: NSView {
    private var elapsedTile: AdvancedToggleTile!
    private var loginTile: AdvancedToggleTile!
    private var notificationsTile: AdvancedToggleTile!
    private var darkModeTile: AdvancedToggleTile!
    private let panelSize = NSSize(width: 300, height: 132)

    init(showElapsedTime: Bool, launchAtLogin: Bool, notificationsEnabled: Bool,
         darkModeEnabled: Bool,
         onElapsedTimeChange: @escaping (Bool) -> Void,
         onLaunchAtLoginChange: @escaping (Bool) -> Void,
         onNotificationsChange: @escaping (Bool) -> Void,
         onDarkModeChange: @escaping (Bool) -> Void) {
        super.init(frame: NSRect(origin: .zero, size: panelSize))
        let onText = L10n.text("켜짐", "ON")
        let offText = L10n.text("꺼짐", "OFF")
        let tileSize = NSSize(width: 135, height: 58)
        let frames = [
            NSRect(x: 10, y: 68, width: tileSize.width, height: tileSize.height),
            NSRect(x: 155, y: 68, width: tileSize.width, height: tileSize.height),
            NSRect(x: 10, y: 4, width: tileSize.width, height: tileSize.height),
            NSRect(x: 155, y: 4, width: tileSize.width, height: tileSize.height)
        ]

        elapsedTile = AdvancedToggleTile(
            frame: frames[0],
            title: L10n.text("실행 시간", "Elapsed Time"),
            isOn: showElapsedTime, onText: onText, offText: offText,
            onChange: onElapsedTimeChange
        )
        addSubview(elapsedTile)
        loginTile = AdvancedToggleTile(
            frame: frames[1],
            title: L10n.text("자동 실행", "Auto Launch"),
            isOn: launchAtLogin, onText: onText, offText: offText,
            onChange: onLaunchAtLoginChange
        )
        addSubview(loginTile)
        notificationsTile = AdvancedToggleTile(
            frame: frames[2],
            title: L10n.text("알림", "Notifications"),
            isOn: notificationsEnabled, onText: onText, offText: offText,
            onChange: onNotificationsChange
        )
        addSubview(notificationsTile)
        darkModeTile = AdvancedToggleTile(
            frame: frames[3],
            title: L10n.text("다크 모드", "Dark Mode"),
            isOn: darkModeEnabled, onText: onText, offText: offText,
            onChange: onDarkModeChange
        )
        addSubview(darkModeTile)
    }

    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { panelSize }

    func applyLocalization() {
        let onText = L10n.text("켜짐", "ON")
        let offText = L10n.text("꺼짐", "OFF")
        elapsedTile.applyLocalization(
            title: L10n.text("실행 시간", "Elapsed Time"),
            onText: onText, offText: offText
        )
        loginTile.applyLocalization(
            title: L10n.text("자동 실행", "Auto Launch"),
            onText: onText, offText: offText
        )
        notificationsTile.applyLocalization(
            title: L10n.text("알림", "Notifications"),
            onText: onText, offText: offText
        )
        darkModeTile.applyLocalization(
            title: L10n.text("다크 모드", "Dark Mode"),
            onText: onText, offText: offText
        )
    }

    func refreshAppearance() {
        [elapsedTile, loginTile, notificationsTile, darkModeTile].forEach {
            $0?.refreshAppearance()
        }
        needsDisplay = true
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
