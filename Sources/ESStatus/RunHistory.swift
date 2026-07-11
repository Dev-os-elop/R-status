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
    private let panelWidth: CGFloat = 350

    init(entries: [RunHistoryEntry], onClear: @escaping () -> Void) {
        self.entries = entries
        self.onClear = onClear
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        rebuildView()
    }

    private func rebuildView() {
        let rowHeight: CGFloat = 64
        let listHeight = entries.isEmpty ? 58 : CGFloat(entries.count) * rowHeight
        let panelHeight = 46 + listHeight + 48
        let root = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))

        let header = NSTextField(labelWithString: L10n.text("최근 실행 기록", "Recent Run History"))
        header.font = .systemFont(ofSize: 14, weight: .semibold)
        header.frame = NSRect(x: 16, y: panelHeight - 34, width: panelWidth - 32, height: 20)
        root.addSubview(header)

        if entries.isEmpty {
            let empty = NSTextField(labelWithString: L10n.text("저장된 실행 기록이 없습니다.",
                                                               "No run history yet."))
            empty.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            empty.textColor = .secondaryLabelColor
            empty.alignment = .center
            empty.frame = NSRect(x: 16, y: 52, width: panelWidth - 32, height: 40)
            root.addSubview(empty)
        } else {
            for (index, entry) in entries.enumerated() {
                let y = panelHeight - 46 - CGFloat(index + 1) * rowHeight
                addEntry(entry, to: root, frame: NSRect(x: 12, y: y + 4,
                                                        width: panelWidth - 24, height: 56))
            }
        }

        let clearButton = NSButton(title: L10n.text("기록 지우기", "Clear"),
                                   target: self, action: #selector(clearHistory))
        clearButton.bezelStyle = .rounded
        clearButton.isEnabled = !entries.isEmpty
        clearButton.frame = NSRect(x: 12, y: 10, width: panelWidth - 24, height: 30)
        root.addSubview(clearButton)

        preferredContentSize = NSSize(width: panelWidth, height: panelHeight)
        view = root
    }

    private func addEntry(_ entry: RunHistoryEntry, to root: NSView, frame: NSRect) {
        let card = NSBox(frame: frame)
        card.boxType = .custom
        card.cornerRadius = 7
        card.borderColor = .separatorColor
        card.borderWidth = 1
        card.fillColor = .controlBackgroundColor
        root.addSubview(card)

        let status = localizedStatus(entry.status)
        let title = entry.taskName.isEmpty ? status : "\(status) · \(entry.taskName)"
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: 10, y: 31, width: frame.width - 20, height: 18)
        card.addSubview(titleLabel)

        let metrics = String(
            format: "%@: %@  ·  %@: %.1f%%  ·  %@: %d",
            L10n.text("시간", "Time"), formatElapsed(entry.elapsedSeconds),
            L10n.text("CPU 최고", "CPU max"), entry.peakCPUPercent,
            L10n.text("워커 최대", "Workers max"), entry.maxWorkers
        )
        let metricsLabel = NSTextField(labelWithString: metrics)
        metricsLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        metricsLabel.textColor = .secondaryLabelColor
        metricsLabel.frame = NSRect(x: 10, y: 10, width: frame.width - 20, height: 18)
        card.addSubview(metricsLabel)
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

    @objc private func clearHistory() {
        onClear()
        entries = []
        rebuildView()
    }
}
