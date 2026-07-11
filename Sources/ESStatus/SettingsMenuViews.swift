import AppKit

@MainActor
final class SettingsAppearanceMenuItemView: NSView {
    private let onSelection: (StatusIconStyle) -> Void
    private var selectedStyle: StatusIconStyle
    private var styleButtons: [StatusIconStyle: NSButton] = [:]
    private var previewImages: [StatusVisualState: NSImageView] = [:]

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

        let header = NSTextField(labelWithString: L10n.text("상태 미리보기", "State Preview"))
        header.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        header.textColor = .secondaryLabelColor
        header.frame = NSRect(x: 252, y: 196, width: 220, height: 20)
        addSubview(header)

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
        }
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
