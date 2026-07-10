import Foundation

enum AddinInstallerError: LocalizedError {
    case missingInstaller
    case launchFailed(String)
    case installationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingInstaller:
            return "The bundled RStudio Addin installer could not be found."
        case .launchFailed(let message):
            return "The Addin installer could not be started: \(message)"
        case .installationFailed(let message):
            return message.isEmpty ? "The RStudio Addin installation failed." : message
        }
    }
}

enum AddinInstaller {
    static func run(scriptURL: URL) -> Result<String, AddinInstallerError> {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rstudio-status-addin-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: logURL) }

        guard let logHandle = try? FileHandle(forWritingTo: logURL) else {
            return .failure(.launchFailed("A temporary log file could not be created."))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path]
        process.standardOutput = logHandle
        process.standardError = logHandle

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            try? logHandle.close()
            return .failure(.launchFailed(error.localizedDescription))
        }

        try? logHandle.close()
        let output = (try? String(contentsOf: logURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus == 0 {
            return .success(output)
        }
        return .failure(.installationFailed(output))
    }
}
