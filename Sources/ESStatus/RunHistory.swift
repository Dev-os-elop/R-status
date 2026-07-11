import AppKit
import Foundation

struct RunHistoryEntry: Codable {
    let id: UUID
    let finishedAt: Date
    let status: String
    let taskName: String
    let elapsedSeconds: TimeInterval
    let peakCPUPercent: Double
    let maxWorkers: Int
}

enum RunHistoryStore {
    private static let key = "runHistoryEntries"
    private static let maximumCount = 5

    static func load() -> [RunHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([RunHistoryEntry].self, from: data) else {
            return []
        }
        return Array(entries.prefix(maximumCount))
    }

    static func add(_ entry: RunHistoryEntry) {
        var entries = load()
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(maximumCount))
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@MainActor
final class StatusSummaryMenuItemView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let historyButton = NSButton()
    private let onHistory: (NSView) -> Void
    private let viewSize = NSSize(width: 300, height: 34)

    init(title: String, onHistory: @escaping (NSView) -> Void) {
        self.onHistory = onHistory
        super.init(frame: NSRect(origin: .zero, size: viewSize))

        titleLabel.font = .menuFont(ofSize: 0)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: 14, y: 7, width: 202, height: 20)
        addSubview(titleLabel)

        historyButton.title = L10n.text("기록", "History")
        historyButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        historyButton.bezelStyle = .roundRect
        historyButton.frame = NSRect(x: 220, y: 4, width: 68, height: 26)
        historyButton.target = self
        historyButton.action = #selector(showHistory)
        addSubview(historyButton)
        update(title: title)
    }

    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { viewSize }

    func update(title: String) {
        titleLabel.stringValue = title
        historyButton.title = L10n.text("기록", "History")
    }

    @objc private func showHistory() {
        onHistory(historyButton)
    }
}

@MainActor
final class RunHistoryViewController: NSViewController {
    private var entries: [RunHistoryEntry]
    private let onClear: () -> Void
    private let panelWidth: CGFloat = 380

    init(entries: [RunHistoryEntry], onClear: @escaping () -> Void) {
        self.entries = entries
        self.onClear = onClear
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 1))
        renderContent()
    }

    private func renderContent() {
        let rowHeight: CGFloat = 72
        let listHeight = entries.isEmpty ? 58 : CGFloat(entries.count) * rowHeight
        let panelHeight = 50 + listHeight + 48
        view.subviews.forEach { $0.removeFromSuperview() }
        view.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        let header = NSTextField(labelWithString: L10n.text("최근 실행 기록", "Recent Run History"))
        header.font = .systemFont(ofSize: 14, weight: .semibold)
        header.frame = NSRect(x: 16, y: panelHeight - 35, width: 190, height: 20)
        view.addSubview(header)

        let retention = NSTextField(labelWithString: L10n.text(
            "최대 5개 · 오래된 순 삭제",
            "Up to 5 · oldest removed first"
        ))
        retention.font = .systemFont(ofSize: 10)
        retention.textColor = .secondaryLabelColor
        retention.alignment = .right
        retention.frame = NSRect(x: 202, y: panelHeight - 34, width: panelWidth - 218, height: 18)
        view.addSubview(retention)

        if entries.isEmpty {
            let empty = NSTextField(labelWithString: L10n.text("저장된 실행 기록이 없습니다.",
                                                               "No run history yet."))
            empty.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            empty.textColor = .secondaryLabelColor
            empty.alignment = .center
            empty.frame = NSRect(x: 16, y: 52, width: panelWidth - 32, height: 40)
            view.addSubview(empty)
        } else {
            for (index, entry) in entries.enumerated() {
                let y = panelHeight - 50 - CGFloat(index + 1) * rowHeight
                addEntry(entry, to: view, frame: NSRect(x: 0, y: y,
                                                        width: panelWidth, height: rowHeight))
            }
        }

        let clearButton = NSButton(title: L10n.text("기록 지우기", "Clear"),
                                   target: self, action: #selector(clearHistory))
        clearButton.bezelStyle = .rounded
        clearButton.isEnabled = !entries.isEmpty
        clearButton.frame = NSRect(x: 12, y: 10, width: panelWidth - 24, height: 30)
        view.addSubview(clearButton)

        preferredContentSize = NSSize(width: panelWidth, height: panelHeight)
    }

    private func addEntry(_ entry: RunHistoryEntry, to root: NSView, frame: NSRect) {
        let status = localizedStatus(entry.status)
        let title = entry.taskName.isEmpty ? status : "\(status) · \(entry.taskName)"
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: 16, y: frame.minY + 38, width: frame.width - 166, height: 18)
        root.addSubview(titleLabel)

        let finishedLabel = NSTextField(labelWithString: formatLocalDate(entry.finishedAt))
        finishedLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        finishedLabel.textColor = .secondaryLabelColor
        finishedLabel.alignment = .right
        finishedLabel.frame = NSRect(x: frame.maxX - 150, y: frame.minY + 39,
                                     width: 134, height: 16)
        root.addSubview(finishedLabel)

        let metrics = String(
            format: "%@: %@  ·  %@: %.1f%%  ·  %@: %d",
            L10n.text("시간", "Time"), formatElapsed(entry.elapsedSeconds),
            L10n.text("CPU 최고", "CPU max"), entry.peakCPUPercent,
            L10n.text("워커 최대", "Workers max"), entry.maxWorkers
        )
        let metricsLabel = NSTextField(labelWithString: metrics)
        metricsLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        metricsLabel.textColor = .secondaryLabelColor
        metricsLabel.frame = NSRect(x: 16, y: frame.minY + 16, width: frame.width - 32, height: 18)
        root.addSubview(metricsLabel)

        let separator = NSBox(frame: NSRect(x: 16, y: frame.minY,
                                            width: frame.width - 32, height: 1))
        separator.boxType = .separator
        root.addSubview(separator)
    }

    private func localizedStatus(_ status: String) -> String {
        switch status {
        case "complete": return L10n.text("완료", "Complete")
        case "fail": return L10n.text("실패", "Fail")
        case "interrupted": return L10n.text("중단됨", "Interrupted")
        default: return status
        }
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%02d:%02d", minutes, remainder)
    }

    private func formatLocalDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @objc private func clearHistory() {
        onClear()
        entries = []
        renderContent()
    }
}
