import AppKit

@MainActor
final class MemoryUsageMenuItemView: NSView {
    private let titleLabel = NSTextField(labelWithString: "Memory: —")
    private var ratio: CGFloat = 0
    private let viewSize = NSSize(width: 300, height: 48)

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: frameRect.origin, size: viewSize))

        titleLabel.font = .menuFont(ofSize: 0)
        titleLabel.frame = NSRect(x: 14, y: 24, width: viewSize.width - 28, height: 20)
        addSubview(titleLabel)
    }

    convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { viewSize }

    func update(title: String, percent: Double) {
        titleLabel.stringValue = title
        ratio = CGFloat(min(100, max(0, percent)) / 100)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let trackRect = NSRect(x: 14, y: 8, width: viewSize.width - 28, height: 7)
        let track = NSBezierPath(roundedRect: trackRect, xRadius: 3.5, yRadius: 3.5)
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        NSColor(calibratedWhite: isDark ? 0.30 : 0.86, alpha: 1).setFill()
        track.fill()

        guard ratio > 0 else { return }
        let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY,
                              width: max(7, trackRect.width * ratio), height: trackRect.height)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: 3.5, yRadius: 3.5).fill()
    }
}
