import AppKit

@MainActor
final class SettingsToggleMenuItemView: NSView {
    private let onChange: (Bool) -> Void
    private let toggle = NSSwitch()

    init(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 292, height: 40))

        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 0)
        label.translatesAutoresizingMaskIntoConstraints = false

        toggle.state = isOn ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggleChanged)
        toggle.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        addSubview(toggle)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { nil }

    @objc private func toggleChanged() {
        onChange(toggle.state == .on)
    }
}
