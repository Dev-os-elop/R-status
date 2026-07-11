import AppKit

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
        label.translatesAutoresizingMaskIntoConstraints = false

        toggle.state = isOn ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggleChanged)
        toggle.translatesAutoresizingMaskIntoConstraints = false

        stateLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        stateLabel.alignment = .right
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
