import AppKit
import Darwin
import Foundation
import Network
import ServiceManagement
import UserNotifications

private enum RunState: String, Codable {
    case idle
    case running
    case complete
    case fail
    case interrupted

}

private struct StatusUpdate: Decodable {
    let status: RunState
    let name: String?
    let message: String?
    let pid: Int32?
}

private struct ProgressUpdate: Decodable {
    let active: Bool
    let current: Double?
    let total: Double?
    let etaSeconds: Double?
    let message: String?
}

private struct GitHubSourceVersion {
    let version: String
    let repository: String
}

private struct GitHubLatestRelease: Decodable {
    let tagName: String

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}

private enum UpdateInstallError: LocalizedError {
    case invalidVersion
    case invalidDownloadURL
    case downloadFailed
    case extractionFailed(String)
    case installerMissing
    case installerLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidVersion:
            return "The update version is invalid."
        case .invalidDownloadURL:
            return "The GitHub update URL could not be created."
        case .downloadFailed:
            return "The update ZIP could not be downloaded from GitHub."
        case .extractionFailed(let message):
            return message.isEmpty ? "The update ZIP could not be extracted." : message
        case .installerMissing:
            return "The downloaded update does not contain install.sh."
        case .installerLaunchFailed(let message):
            return message.isEmpty ? "The update installer could not be started." : message
        }
    }
}

private struct LaunchedUpdate {
    let process: Process
    let logURL: URL
}

private func runAndCapture(_ executable: String, arguments: [String]) throws -> (Int32, String) {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

private func downloadAndLaunchUpdate(_ source: GitHubSourceVersion) throws -> LaunchedUpdate {
    guard source.version.range(of: #"^[0-9]+(?:\.[0-9]+)*$"#, options: .regularExpression) != nil else {
        throw UpdateInstallError.invalidVersion
    }
    guard let archiveURL = URL(
        string: "https://github.com/\(source.repository)/archive/refs/tags/v\(source.version).zip"
    ) else {
        throw UpdateInstallError.invalidDownloadURL
    }

    let fileManager = FileManager.default
    let updateRoot = fileManager.temporaryDirectory
        .appendingPathComponent("ESStatusUpdate-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: updateRoot, withIntermediateDirectories: true)
    let archivePath = updateRoot.appendingPathComponent("update.zip")

    var request = URLRequest(url: archiveURL)
    request.setValue("ESStatus/\(source.version)", forHTTPHeaderField: "User-Agent")
    let semaphore = DispatchSemaphore(value: 0)
    var downloadData: Data?
    URLSession.shared.dataTask(with: request) { data, response, _ in
        if let response = response as? HTTPURLResponse,
           (200...299).contains(response.statusCode) {
            downloadData = data
        }
        semaphore.signal()
    }.resume()
    semaphore.wait()
    guard let downloadData else { throw UpdateInstallError.downloadFailed }
    try downloadData.write(to: archivePath, options: .atomic)

    let extractedRoot = updateRoot.appendingPathComponent("source", isDirectory: true)
    try fileManager.createDirectory(at: extractedRoot, withIntermediateDirectories: true)
    let (extractStatus, extractOutput) = try runAndCapture(
        "/usr/bin/ditto",
        arguments: ["-x", "-k", archivePath.path, extractedRoot.path]
    )
    guard extractStatus == 0 else {
        throw UpdateInstallError.extractionFailed(extractOutput)
    }

    let candidates = (try? fileManager.contentsOfDirectory(
        at: extractedRoot,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )) ?? []
    guard let sourceRoot = candidates.first(where: {
        fileManager.fileExists(atPath: $0.appendingPathComponent("install.sh").path)
    }) else {
        throw UpdateInstallError.installerMissing
    }

    if let enumerator = fileManager.enumerator(at: sourceRoot, includingPropertiesForKeys: nil) {
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "sh" {
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fileURL.path)
        }
    }
    let installerURL = sourceRoot.appendingPathComponent("install.sh")
    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installerURL.path)

    let logURL = updateRoot.appendingPathComponent("install.log")
    fileManager.createFile(atPath: logURL.path, contents: nil)
    let logHandle = try FileHandle(forWritingTo: logURL)
    let installer = Process()
    installer.executableURL = URL(fileURLWithPath: "/bin/zsh")
    installer.arguments = [installerURL.path]
    installer.currentDirectoryURL = sourceRoot
    var environment = ProcessInfo.processInfo.environment
    let updaterPaths = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/Library/Frameworks/R.framework/Resources/bin"
    ]
    environment["PATH"] = (updaterPaths + [environment["PATH"] ?? ""]).joined(separator: ":")
    environment["ESSTATUS_RUNNING_PID"] = String(Darwin.getpid())
    installer.environment = environment
    installer.standardOutput = logHandle
    installer.standardError = logHandle
    do {
        try installer.run()
        try? logHandle.close()
        return LaunchedUpdate(process: installer, logURL: logURL)
    } catch {
        try? logHandle.close()
        throw UpdateInstallError.installerLaunchFailed(error.localizedDescription)
    }
}

private enum UpdateCheckResult {
    case updateAvailable(GitHubSourceVersion)
    case latest
    case failed(String)
}

private func isVersion(_ candidate: String, newerThan current: String) -> Bool {
    let candidateParts = versionComponents(candidate)
    let currentParts = versionComponents(current)
    let count = max(candidateParts.count, currentParts.count)
    for index in 0..<count {
        let lhs = index < candidateParts.count ? candidateParts[index] : 0
        let rhs = index < currentParts.count ? currentParts[index] : 0
        if lhs != rhs { return lhs > rhs }
    }
    return false
}

private func versionComponents(_ version: String) -> [Int] {
    version
        .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        .split(separator: ".")
        .map { component in
            Int(component.prefix(while: { $0.isNumber })) ?? 0
        }
}

private final class LocalHTTPServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "ESStatus.HTTPServer")
    var onStatus: ((StatusUpdate) -> Void)?
    var onProgress: ((ProgressUpdate) -> Void)?

    func start(port: UInt16 = 47821) throws {
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "ESStatus", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "잘못된 포트입니다."])
        }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                NSLog("ES Status server failed: \(error)")
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            var buffer = buffer
            if let data { buffer.append(data) }

            if let request = self?.completeRequest(in: buffer) {
                self?.process(request, on: connection)
            } else if complete || error != nil || buffer.count >= 65_536 {
                self?.respond(status: "400 Bad Request", body: #"{"ok":false}"#, on: connection)
            } else {
                self?.receive(on: connection, buffer: buffer)
            }
        }
    }

    private func completeRequest(in data: Data) -> Data? {
        let marker = Data("\r\n\r\n".utf8)
        guard let headerEnd = data.range(of: marker) else { return nil }
        let headerData = data[..<headerEnd.lowerBound]
        guard let headers = String(data: headerData, encoding: .utf8) else { return nil }
        let contentLength = headers
            .split(separator: "\r\n")
            .first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)) } ?? 0
        let totalLength = headerEnd.upperBound + contentLength
        guard data.count >= totalLength else { return nil }
        return data.prefix(totalLength)
    }

    private func process(_ request: Data, on connection: NWConnection) {
        guard let text = String(data: request, encoding: .utf8),
              let firstLine = text.components(separatedBy: "\r\n").first else {
            respond(status: "400 Bad Request", body: #"{"ok":false}"#, on: connection)
            return
        }

        if firstLine.hasPrefix("GET /health ") {
            respond(status: "200 OK", body: #"{"ok":true,"app":"ES Status"}"#, on: connection)
            return
        }

        guard let bodyRange = request.range(of: Data("\r\n\r\n".utf8)) else {
            respond(status: "404 Not Found", body: #"{"ok":false}"#, on: connection)
            return
        }

        let body = request[bodyRange.upperBound...]
        do {
            if firstLine.hasPrefix("POST /status ") {
                let update = try JSONDecoder().decode(StatusUpdate.self, from: body)
                DispatchQueue.main.async { [weak self] in self?.onStatus?(update) }
            } else if firstLine.hasPrefix("POST /progress ") {
                let update = try JSONDecoder().decode(ProgressUpdate.self, from: body)
                DispatchQueue.main.async { [weak self] in self?.onProgress?(update) }
            } else {
                respond(status: "404 Not Found", body: #"{"ok":false}"#, on: connection)
                return
            }
            respond(status: "200 OK", body: #"{"ok":true}"#, on: connection)
        } catch {
            respond(status: "400 Bad Request", body: #"{"ok":false,"error":"invalid status"}"#, on: connection)
        }
    }

    private func respond(status: String, body: String, on connection: NWConnection) {
        let response = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSMenuDelegate {
    private let server = LocalHTTPServer()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let summaryItem = NSMenuItem(title: "RStudio 연결 대기 중", action: nil, keyEquivalent: "")
    private let versionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let detailItem = NSMenuItem(title: "포트 47821", action: nil, keyEquivalent: "")
    private let elapsedItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let resourceHeaderItem = NSMenuItem(title: "R Resource Usage", action: nil, keyEquivalent: "")
    private let cpuItem = NSMenuItem(title: "CPU: —", action: nil, keyEquivalent: "")
    private let workersItem = NSMenuItem(title: "Parallel workers: —", action: nil, keyEquivalent: "")
    private let processesItem = NSMenuItem(title: "R processes: —", action: nil, keyEquivalent: "")
    private let progressItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let etaItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private weak var advancedSettingsView: SettingsAdvancedMenuItemView?
    private weak var appearanceSettingsView: SettingsAppearanceMenuItemView?
    private weak var languageSettingsView: SettingsLanguageMenuItemView?
    private weak var settingsPanelMenu: NSMenu?
    private weak var basicSettingsHeader: NSMenuItem?
    private weak var appearanceSettingsHeader: NSMenuItem?
    private weak var advancedSettingsHeader: NSMenuItem?
    private weak var returnToReadyView: ReturnToReadyMenuItemView?
    private var addinInstallItem: NSMenuItem?
    private var isInstallingAddin = false
    private var isInstallingUpdate = false
    private var state: RunState = .idle
    private var taskName = ""
    private var detailMessage = ""
    private var startedAt: Date?
    private var timer: Timer?
    private var resourceTimer: Timer?
    private var processWatchTimer: Timer?
    private var updateInstallTimer: Timer?
    private var isSamplingResources = false
    private var resourceRefreshPending = false
    private var taskPID: Int32?
    private var updateProcess: Process?
    private var updateLogURL: URL?
    private var instanceLockFD: Int32 = -1
    private var shouldReconfigureMenuAfterClose = false

    private func acquireInstanceLock() -> Bool {
        let lockPath = "/tmp/io.github.ljwook92.rstatus.instance.lock"
        let fd = Darwin.open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { return false }
        var lock = flock(
            l_start: 0,
            l_len: 0,
            l_pid: 0,
            l_type: Int16(F_WRLCK),
            l_whence: Int16(SEEK_SET)
        )
        guard Darwin.fcntl(fd, F_SETLK, &lock) == 0 else {
            Darwin.close(fd)
            return false
        }
        instanceLockFD = fd
        return true
    }
    private var updateCheckPreviousApplication: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireInstanceLock() else {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        updateApplicationIcon()
        configureMenu()
        updateDisplay()
        startResourceMonitoring()

        server.onStatus = { [weak self] update in self?.apply(update) }
        server.onProgress = { [weak self] update in self?.applyProgress(update) }
        do {
            try server.start()
            summaryItem.title = L10n.text("RStudio 연결 준비됨", "RStudio connection ready")
        } catch {
            state = .fail
            detailMessage = "포트 47821을 열 수 없습니다: \(error.localizedDescription)"
        }
        updateDisplay()

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        if AppPreferences.notificationsEnabled {
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }

    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        resourceTimer?.invalidate()
        processWatchTimer?.invalidate()
        updateInstallTimer?.invalidate()
        server.stop()
        if instanceLockFD >= 0 {
            Darwin.close(instanceLockFD)
            instanceLockFD = -1
        }
    }

    private func configureMenu() {
        menu.removeAllItems()
        menu.delegate = self
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        statusItem.button?.toolTip = L10n.text("R 작업 상태", "R task status")
        statusItem.button?.imageScaling = .scaleNone
        statusItem.menu = menu

        summaryItem.isEnabled = false
        versionItem.title = "Version \(currentVersion)"
        versionItem.isEnabled = false
        detailItem.isEnabled = false
        detailItem.isHidden = true
        elapsedItem.isEnabled = false
        menu.addItem(summaryItem)
        menu.addItem(versionItem)
        menu.addItem(detailItem)
        menu.addItem(elapsedItem)
        menu.addItem(.separator())

        resourceHeaderItem.title = L10n.text("R 리소스 사용량", "R Resource Usage")
        for item in [resourceHeaderItem, cpuItem, workersItem, processesItem, progressItem, etaItem] {
            item.isEnabled = false
            menu.addItem(item)
        }
        progressItem.isHidden = true
        etaItem.isHidden = true
        menu.addItem(.separator())

        let resetItem = NSMenuItem()
        let resetView = ReturnToReadyMenuItemView { [weak self] in
            self?.resetStatus()
        }
        returnToReadyView = resetView
        resetItem.view = resetView
        menu.addItem(resetItem)

        let notificationItem = NSMenuItem(title: L10n.text("알림 테스트", "Test Notification"),
                                          action: #selector(testNotification), keyEquivalent: "n")
        notificationItem.target = self
        menu.addItem(notificationItem)

        let openItem = NSMenuItem(title: L10n.text("RStudio 열기", "Open RStudio"),
                                  action: #selector(openRStudio), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: L10n.text("설정", "Settings"),
                                      action: nil, keyEquivalent: "")
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: settingsItem.title)
        settingsItem.submenu = makeSettingsMenu()
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let installAddinItem = NSMenuItem(
            title: L10n.text("RStudio Addin 설치/업데이트…", "Install/Update RStudio Addin…"),
            action: #selector(installAddinFromMenu), keyEquivalent: ""
        )
        installAddinItem.target = self
        addinInstallItem = installAddinItem
        menu.addItem(installAddinItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: L10n.text("ES Status 종료", "Quit ES Status"),
                                  action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeSettingsMenu() -> NSMenu {
        let settingsMenu = NSMenu(title: L10n.text("설정", "Settings"))
        settingsPanelMenu = settingsMenu

        let basicHeader = NSMenuItem(title: L10n.text("기본", "Basic"), action: nil, keyEquivalent: "")
        basicHeader.isEnabled = false
        basicSettingsHeader = basicHeader
        settingsMenu.addItem(basicHeader)

        let languageItem = NSMenuItem()
        let languageView = SettingsLanguageMenuItemView(
            selectedLanguage: AppPreferences.language
        ) { [weak self] language in
            AppPreferences.language = language
            self?.shouldReconfigureMenuAfterClose = true
            self?.applySettingsLocalization()
            self?.updateDisplay()
        }
        languageSettingsView = languageView
        languageItem.view = languageView
        settingsMenu.addItem(languageItem)

        settingsMenu.addItem(.separator())
        let appearanceHeader = NSMenuItem(title: L10n.text("모양", "Appearance"), action: nil, keyEquivalent: "")
        appearanceHeader.isEnabled = false
        appearanceSettingsHeader = appearanceHeader
        settingsMenu.addItem(appearanceHeader)

        let appearanceItem = NSMenuItem()
        let appearanceView = SettingsAppearanceMenuItemView(
            selectedStyle: AppPreferences.iconStyle
        ) { [weak self] style in
            AppPreferences.iconStyle = style
            self?.updateDisplay()
        }
        appearanceSettingsView = appearanceView
        appearanceItem.view = appearanceView
        settingsMenu.addItem(appearanceItem)

        settingsMenu.addItem(.separator())
        let advancedHeader = NSMenuItem(title: L10n.text("고급", "Advanced"), action: nil, keyEquivalent: "")
        advancedHeader.isEnabled = false
        advancedSettingsHeader = advancedHeader
        settingsMenu.addItem(advancedHeader)

        let advancedItem = NSMenuItem()
        let advancedView = SettingsAdvancedMenuItemView(
            showElapsedTime: AppPreferences.showElapsedTime,
            launchAtLogin: SMAppService.mainApp.status == .enabled,
            notificationsEnabled: AppPreferences.notificationsEnabled,
            onElapsedTimeChange: { [weak self] enabled in
                AppPreferences.showElapsedTime = enabled
                self?.updateDisplay()
            },
            onLaunchAtLoginChange: { [weak self] enabled in
                self?.setLaunchAtLogin(enabled)
            },
            onNotificationsChange: { [weak self] enabled in
                self?.setNotificationsEnabled(enabled)
            },
            onCheckForUpdates: { [weak self] in
                self?.checkForUpdates()
            }
        )
        advancedSettingsView = advancedView
        advancedItem.view = advancedView
        settingsMenu.addItem(advancedItem)

        return settingsMenu
    }

    private func applySettingsLocalization() {
        settingsPanelMenu?.title = L10n.text("설정", "Settings")
        basicSettingsHeader?.title = L10n.text("기본", "Basic")
        appearanceSettingsHeader?.title = L10n.text("모양", "Appearance")
        advancedSettingsHeader?.title = L10n.text("고급", "Advanced")
        languageSettingsView?.applyLocalization()
        appearanceSettingsView?.applyLocalization()
        advancedSettingsView?.applyLocalization()
    }

    func menuDidClose(_ closedMenu: NSMenu) {
        guard closedMenu === menu, shouldReconfigureMenuAfterClose else { return }
        shouldReconfigureMenuAfterClose = false
        DispatchQueue.main.async { [weak self] in
            self?.configureMenu()
            self?.updateDisplay()
        }
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private func startResourceMonitoring() {
        refreshResourceUsage()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshResourceUsage() }
        }
        resourceTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshResourceUsage(forceAfterCurrent: Bool = false) {
        guard !isSamplingResources else {
            if forceAfterCurrent { resourceRefreshPending = true }
            return
        }
        isSamplingResources = true
        Task.detached(priority: .utility) {
            let snapshot = RResourceMonitor.sample()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isSamplingResources = false
                self.updateResourceItems(snapshot)
                if self.resourceRefreshPending {
                    self.resourceRefreshPending = false
                    self.refreshResourceUsage()
                }
            }
        }
    }

    private func updateResourceItems(_ snapshot: RResourceSnapshot) {
        cpuItem.title = String(format: "CPU: %.1f%%", snapshot.cpuPercent)
        workersItem.title = "\(L10n.text("병렬 워커", "Parallel workers")): \(snapshot.workerCount)"
        processesItem.title = "\(L10n.text("R 프로세스", "R processes")): \(snapshot.processCount)"
    }

    private func applyProgress(_ update: ProgressUpdate) {
        guard state == .running, update.active else {
            clearProgress()
            return
        }
        guard let current = update.current,
              let total = update.total,
              current.isFinite,
              total.isFinite,
              total > 0 else {
            clearProgress()
            return
        }

        let displayCurrent = min(total, max(0, current))
        let ratio = min(1, max(0, displayCurrent / total))
        let segmentCount = 8
        let completed = min(segmentCount, max(0, Int((ratio * Double(segmentCount)).rounded(.down))))
        let percent = Int((ratio * 100).rounded())
        setProgressTitle(
            completed: completed,
            segmentCount: segmentCount,
            details: "\(String(format: "%3d", percent))%"
        )
        progressItem.isEnabled = true
        progressItem.isHidden = false

        if let eta = update.etaSeconds, eta.isFinite, eta >= 0 {
            setCompactProgressTitle(etaItem, "\(L10n.text("남은 시간", "Remaining")): \(formatRemaining(eta))")
        } else {
            setCompactProgressTitle(etaItem, "\(L10n.text("남은 시간", "Remaining")): --:--:--")
        }
        etaItem.isEnabled = true
        etaItem.isHidden = false
    }

    private func clearProgress() {
        progressItem.title = ""
        progressItem.attributedTitle = NSAttributedString(string: "")
        progressItem.isEnabled = false
        progressItem.isHidden = true
        etaItem.title = ""
        etaItem.attributedTitle = NSAttributedString(string: "")
        etaItem.isEnabled = false
        etaItem.isHidden = true
    }

    private func formatRemaining(_ interval: TimeInterval) -> String {
        let seconds = min(359_999, max(0, Int(interval.rounded(.up))))
        return String(
            format: "%02d:%02d:%02d",
            seconds / 3_600,
            (seconds % 3_600) / 60,
            seconds % 60
        )
    }

    private func setCompactProgressTitle(_ item: NSMenuItem, _ title: String) {
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)]
        )
    }

    private func setProgressTitle(completed: Int, segmentCount: Int, details: String) {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let completedAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            // Fixed color keeps the completed cells visually stable when the
            // menu transitions between active and inactive states.
            .foregroundColor: NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.92, alpha: 1.0)
        ]
        let result = NSMutableAttributedString(
            string: "\(L10n.text("진행률", "Progress")): [",
            attributes: normalAttributes
        )
        result.append(NSAttributedString(
            string: String(repeating: "■", count: completed),
            attributes: completedAttributes
        ))
        result.append(NSAttributedString(
            string: String(repeating: "■", count: segmentCount - completed),
            attributes: [
                .font: font,
                .foregroundColor: NSColor(calibratedWhite: 0.62, alpha: 1.0)
            ]
        ))
        result.append(NSAttributedString(string: "] \(details)", attributes: normalAttributes))
        progressItem.title = result.string
        progressItem.attributedTitle = result
    }

    private func startProcessWatchdog() {
        processWatchTimer?.invalidate()
        guard let taskPID, taskPID > 0 else { return }
        let watchTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkTaskProcess() }
        }
        processWatchTimer = watchTimer
        RunLoop.main.add(watchTimer, forMode: .common)
    }

    private func checkTaskProcess() {
        guard state == .running, let taskPID else { return }
        if Darwin.kill(taskPID, 0) == 0 || errno == EPERM { return }

        processWatchTimer?.invalidate()
        processWatchTimer = nil
        self.taskPID = nil
        timer?.invalidate()
        timer = nil
        state = .interrupted
        detailMessage = "RStudio session ended"
        refreshResourceUsage(forceAfterCurrent: true)
        updateDisplay()
        sendNotification()
    }

    private func stateTitle(_ state: RunState) -> String {
        switch state {
        case .idle: return L10n.text("준비됨", "Ready")
        case .running: return L10n.text("실행 중", "Running")
        case .complete: return L10n.text("완료", "Complete")
        case .fail: return L10n.text("실패", "Fail")
        case .interrupted: return L10n.text("중단됨", "Interrupted")
        }
    }

    private func visualState(_ state: RunState) -> StatusVisualState {
        switch state {
        case .idle: return .idle
        case .running: return .running
        case .complete: return .complete
        case .fail: return .fail
        case .interrupted: return .interrupted
        }
    }

    private func menuBarIcon(size: CGFloat = 22) -> NSImage {
        StatusIconRenderer.image(
            style: AppPreferences.iconStyle,
            state: visualState(state),
            size: size
        )
    }

    private func updateApplicationIcon() {
        NSApp.applicationIconImage = StatusIconRenderer.applicationIcon(
            style: .catOutline,
            size: 256
        )
    }

    private func apply(_ update: StatusUpdate) {
        state = update.status
        if let name = update.name, !name.isEmpty { taskName = name }
        detailMessage = update.message ?? ""
        if let pid = update.pid, pid > 0 { taskPID = pid }

        if state == .running {
            clearProgress()
            startedAt = Date()
            timer?.invalidate()
            let refreshTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateDisplay() }
            }
            timer = refreshTimer
            RunLoop.main.add(refreshTimer, forMode: .common)
            startProcessWatchdog()
        } else {
            clearProgress()
            timer?.invalidate()
            timer = nil
            processWatchTimer?.invalidate()
            processWatchTimer = nil
            taskPID = nil
            if state == .complete || state == .fail || state == .interrupted {
                refreshResourceUsage(forceAfterCurrent: true)
                sendNotification()
            }
        }
        updateDisplay()
    }

    private func updateDisplay() {
        var title = stateTitle(state)
        if state == .running, AppPreferences.showElapsedTime, let startedAt {
            title += " \(formatElapsed(Date().timeIntervalSince(startedAt)))"
        }
        statusItem.button?.image = menuBarIcon(size: 24)
        statusItem.button?.imageScaling = .scaleNone
        if state == .idle {
            statusItem.length = 28
            statusItem.button?.imagePosition = .imageOnly
            statusItem.button?.title = ""
        } else {
            statusItem.length = NSStatusItem.variableLength
            statusItem.button?.imagePosition = .imageLeft
            statusItem.button?.title = title
        }
        returnToReadyView?.setTerminalState(
            state == .complete || state == .fail || state == .interrupted
        )
        let summary = state == .idle ? L10n.text("R 상태 준비됨", "R Status Ready") : stateTitle(state)
        summaryItem.title = taskName.isEmpty ? summary : "\(summary) · \(taskName)"

        if !detailMessage.isEmpty {
            detailItem.title = detailMessage
            detailItem.isHidden = false
        } else {
            detailItem.title = ""
            detailItem.isHidden = true
        }

        if let startedAt {
            elapsedItem.title = "\(L10n.text("실행 시간", "Elapsed time")): \(formatElapsed(Date().timeIntervalSince(startedAt)))"
            elapsedItem.isHidden = false
        } else {
            elapsedItem.isHidden = true
        }
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%02d:%02d", minutes, remainder)
    }

    private func sendNotification() {
        let title = taskName.isEmpty ? stateTitle(state) : taskName
        let body: String
        switch state {
        case .complete:
            body = L10n.text("R 작업이 완료되었습니다.", "The R task completed.")
        case .interrupted:
            body = L10n.text("R 작업이 사용자에 의해 중단되었습니다.", "The R task was interrupted.")
        default:
            body = detailMessage.isEmpty
                ? L10n.text("R 작업이 실패했습니다.", "The R task failed.")
                : detailMessage
        }
        postNotification(title: title, body: body)
    }

    private func postNotification(title: String, body: String) {
        guard AppPreferences.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    @objc private func testNotification() {
        postNotification(
            title: "ES Status",
            body: L10n.text("상태 알림 테스트입니다.", "This is a status notification test.")
        )
    }

    @objc private func installAddinFromMenu() {
        installBundledAddin()
    }

    private func installBundledAddin() {
        guard !isInstallingAddin else { return }
        guard let scriptURL = Bundle.main.url(forResource: "install-addin", withExtension: "sh") else {
            showAddinInstallationResult(.failure(.missingInstaller))
            return
        }

        isInstallingAddin = true
        addinInstallItem?.title = L10n.text("RStudio Addin 설치 중…", "Installing RStudio Addin…")
        addinInstallItem?.isEnabled = false

        Task.detached(priority: .userInitiated) {
            let result = AddinInstaller.run(scriptURL: scriptURL)
            await MainActor.run { [weak self] in
                self?.showAddinInstallationResult(result)
            }
        }
    }

    private func showAddinInstallationResult(_ result: Result<String, AddinInstallerError>) {
        isInstallingAddin = false
        addinInstallItem?.title = L10n.text(
            "RStudio Addin 설치/업데이트…",
            "Install/Update RStudio Addin…"
        )
        addinInstallItem?.isEnabled = true
        switch result {
        case .success:
            UserDefaults.standard.set(currentVersion, forKey: "installedAddinVersion")
            postNotification(
                title: "RStudio Addin Installed",
                body: "Restart RStudio, then choose Run Selection with Status from Addins."
            )
        case .failure(let error):
            let message = error.localizedDescription
            postNotification(
                title: "RStudio Addin Installation Failed",
                body: message.count > 180 ? String(message.prefix(180)) + "…" : message
            )
        }
    }

    @objc private func checkForUpdates() {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
           frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            updateCheckPreviousApplication = frontmostApplication
        }
        let repository = Bundle.main.object(forInfoDictionaryKey: "GitHubRepository") as? String
            ?? "Dev-os-elop/R-status"
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else { return }
        let installedVersion = currentVersion
        setUpdateControl(title: L10n.text("업데이트 확인 중…", "Checking for Updates…"),
                         enabled: false)

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("ESStatus/\(installedVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let result: UpdateCheckResult
            if let error {
                result = .failed(error.localizedDescription)
            } else if let httpResponse = response as? HTTPURLResponse,
                      !(200...299).contains(httpResponse.statusCode) {
                result = .failed("GitHub returned HTTP \(httpResponse.statusCode).")
            } else if let data,
                      let release = try? JSONDecoder().decode(GitHubLatestRelease.self, from: data) {
                let remoteVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let sourceVersion = GitHubSourceVersion(
                    version: remoteVersion,
                    repository: repository
                )
                result = isVersion(remoteVersion, newerThan: installedVersion)
                    ? .updateAvailable(sourceVersion)
                    : .latest
            } else {
                result = .failed("The latest GitHub release could not be read.")
            }

            DispatchQueue.main.async { [weak self] in
                self?.showUpdateResult(result)
            }
        }.resume()
    }

    private func showUpdateResult(_ result: UpdateCheckResult) {
        setUpdateControl(title: L10n.text("업데이트 확인…", "Check for Updates…"),
                         enabled: true)
        defer { restorePreviousApplicationFocus() }
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        switch result {
        case .updateAvailable(let sourceVersion):
            alert.messageText = L10n.text("업데이트 사용 가능", "Update Available")
            alert.informativeText = L10n.text(
                "ES Status v\(sourceVersion.version)을 설치할 수 있습니다. 현재 버전은 v\(currentVersion)입니다.",
                "ES Status v\(sourceVersion.version) is available on GitHub. You are using v\(currentVersion)."
            )
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.text("다운로드 및 설치", "Download and Install"))
            alert.addButton(withTitle: L10n.text("나중에", "Later"))
            if alert.runModal() == .alertFirstButtonReturn {
                installUpdate(sourceVersion)
            }
        case .latest:
            alert.messageText = L10n.text("최신 버전입니다", "You're up to date")
            alert.informativeText = L10n.text(
                "ES Status 최신 버전(v\(currentVersion))을 사용 중입니다.",
                "You're using the latest version of ES Status (v\(currentVersion))."
            )
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        case .failed(let message):
            alert.messageText = L10n.text("업데이트 확인 실패", "Unable to Check for Updates")
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func restorePreviousApplicationFocus() {
        guard let previousApplication = updateCheckPreviousApplication else { return }
        updateCheckPreviousApplication = nil
        DispatchQueue.main.async {
            NSApp.deactivate()
            previousApplication.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func installUpdate(_ sourceVersion: GitHubSourceVersion) {
        guard !isInstallingUpdate else { return }
        isInstallingUpdate = true
        setUpdateControl(title: L10n.text("업데이트 다운로드 중…", "Downloading Update…"),
                         enabled: false)

        Task.detached(priority: .userInitiated) {
            let result: Result<LaunchedUpdate, Error>
            do {
                result = .success(try downloadAndLaunchUpdate(sourceVersion))
            } catch {
                result = .failure(error)
            }
            await MainActor.run { [weak self] in
                self?.handleUpdateLaunch(result, sourceVersion: sourceVersion)
            }
        }
    }

    private func handleUpdateLaunch(_ result: Result<LaunchedUpdate, Error>,
                                    sourceVersion: GitHubSourceVersion) {
        switch result {
        case .success(let launched):
            setUpdateControl(title: L10n.text("업데이트 설치 중…", "Installing Update…"),
                             enabled: false)
            updateProcess = launched.process
            updateLogURL = launched.logURL
            postNotification(
                title: "ES Status Update",
                body: "Installing v\(sourceVersion.version). The app will restart automatically."
            )
            updateInstallTimer?.invalidate()
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.checkUpdateInstaller() }
            }
            updateInstallTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        case .failure(let error):
            showUpdateInstallFailure(error.localizedDescription)
        }
    }

    private func checkUpdateInstaller() {
        guard let updateProcess, !updateProcess.isRunning else { return }
        updateInstallTimer?.invalidate()
        updateInstallTimer = nil
        guard updateProcess.terminationStatus != 0 else { return }
        let log = updateLogURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let message = log.isEmpty
            ? "The installer exited with status \(updateProcess.terminationStatus)."
            : log
        showUpdateInstallFailure(message)
        self.updateProcess = nil
        updateLogURL = nil
    }

    private func showUpdateInstallFailure(_ message: String) {
        isInstallingUpdate = false
        setUpdateControl(title: L10n.text("업데이트 확인…", "Check for Updates…"),
                         enabled: true)
        postNotification(
            title: "ES Status Update Failed",
            body: message.count > 180 ? String(message.prefix(180)) + "…" : message
        )
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    @objc private func resetStatus() {
        timer?.invalidate()
        timer = nil
        state = .idle
        taskName = ""
        detailMessage = ""
        startedAt = nil
        clearProgress()
        updateDisplay()
    }

    @objc private func openRStudio() {
        let candidates = ["/Applications/RStudio.app", NSHomeDirectory() + "/Applications/RStudio.app"]
        if let path = candidates.first(where: FileManager.default.fileExists(atPath:)) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    private func setUpdateControl(title: String, enabled: Bool) {
        advancedSettingsView?.setUpdateState(title: title, enabled: enabled)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            detailMessage = L10n.text(
                "로그인 실행 설정 실패: \(error.localizedDescription)",
                "Launch at login failed: \(error.localizedDescription)"
            )
        }
        updateDisplay()
    }

    private func setNotificationsEnabled(_ enabled: Bool) {
        AppPreferences.notificationsEnabled = enabled
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        updateDisplay()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@main
private enum ESStatusMain {
    private static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let appDelegate = AppDelegate()
        delegate = appDelegate
        app.delegate = appDelegate
        app.run()
    }
}
