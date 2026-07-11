import AppKit

@MainActor
final class CPUUsageMenuItemView: NSView {
    private let titleLabel = NSTextField(labelWithString: "CPU: —")
    private var ratio: CGFloat = 0
    private var history: [CGFloat] = []
    private let historyLimit = 30
    private let viewSize = NSSize(width: 300, height: 58)

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: frameRect.origin, size: viewSize))
        titleLabel.font = .menuFont(ofSize: 0)
        titleLabel.frame = NSRect(x: 14, y: 34, width: viewSize.width - 28, height: 20)
        addSubview(titleLabel)
        toolTip = L10n.text(
            "왼쪽은 현재 CPU 사용률, 오른쪽은 최근 약 1분의 사용 기록입니다.",
            "The left bar is current CPU usage; the right chart shows roughly one minute of history."
        )
    }

    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { viewSize }

    func update(percent: Double) {
        let normalized = CGFloat(min(100, max(0, percent)) / 100)
        ratio = normalized
        history.append(normalized)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
        titleLabel.stringValue = String(format: "CPU: %.1f%%", percent)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let trackColor = NSColor(calibratedWhite: isDark ? 0.30 : 0.86, alpha: 1)
        let accent = NSColor.controlAccentColor

        let barRect = NSRect(x: 14, y: 10, width: 92, height: 8)
        trackColor.setFill()
        NSBezierPath(roundedRect: barRect, xRadius: 4, yRadius: 4).fill()
        if ratio > 0 {
            let fillRect = NSRect(x: barRect.minX, y: barRect.minY,
                                  width: max(8, barRect.width * ratio), height: barRect.height)
            accent.setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: 4, yRadius: 4).fill()
        }

        let chartRect = NSRect(x: 120, y: 7, width: 166, height: 22)
        trackColor.withAlphaComponent(0.55).setStroke()
        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: chartRect.minX, y: chartRect.minY))
        baseline.line(to: NSPoint(x: chartRect.maxX, y: chartRect.minY))
        baseline.lineWidth = 1
        baseline.stroke()

        guard !history.isEmpty else { return }
        let line = NSBezierPath()
        line.lineWidth = 2
        line.lineJoinStyle = .round
        line.lineCapStyle = .round
        for (index, value) in history.enumerated() {
            let progress = history.count == 1 ? 1 : CGFloat(index) / CGFloat(history.count - 1)
            let point = NSPoint(
                x: chartRect.minX + chartRect.width * progress,
                y: chartRect.minY + 1 + (chartRect.height - 2) * value
            )
            index == 0 ? line.move(to: point) : line.line(to: point)
        }
        accent.setStroke()
        line.stroke()
    }
}
