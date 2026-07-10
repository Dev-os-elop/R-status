import Foundation

struct RResourceSnapshot {
    let cpuPercent: Double
    let residentMemoryBytes: UInt64
    let processCount: Int
    let activeTaskCount: Int
    let workerCount: Int
    let threadCount: Int
    let systemGPUPercent: Int?

    static let empty = RResourceSnapshot(
        cpuPercent: 0,
        residentMemoryBytes: 0,
        processCount: 0,
        activeTaskCount: 0,
        workerCount: 0,
        threadCount: 0,
        systemGPUPercent: nil
    )
}

private struct ProcessSample {
    let pid: Int
    let parentPID: Int
    let cpuPercent: Double
    let residentMemoryKB: UInt64
    let command: String
}

enum RResourceMonitor {
    static func sample() -> RResourceSnapshot {
        let allProcesses = processList()
        let rProcesses = allProcesses.filter { isRProcess($0.command) }
        let parentByPID = Dictionary(uniqueKeysWithValues: allProcesses.map { ($0.pid, $0.parentPID) })
        let rPIDs = Set(rProcesses.map(\.pid))

        let workerCount = rProcesses.filter { process in
            if process.command.contains("parallel:::.workRSOCK") ||
                process.command.contains("parallel:::.slaveRSOCK") ||
                process.command.contains(" MASTER=") {
                return true
            }
            var parent = process.parentPID
            var visited = Set<Int>()
            while parent > 1, visited.insert(parent).inserted {
                if rPIDs.contains(parent) { return true }
                parent = parentByPID[parent] ?? 0
            }
            return false
        }.count

        return RResourceSnapshot(
            cpuPercent: rProcesses.reduce(0) { $0 + $1.cpuPercent },
            residentMemoryBytes: rProcesses.reduce(0) { $0 + $1.residentMemoryKB * 1_024 },
            processCount: rProcesses.count,
            activeTaskCount: rProcesses.filter { $0.cpuPercent >= 0.5 }.count,
            workerCount: workerCount,
            threadCount: rProcesses.reduce(0) { $0 + threadCount(for: $1.pid) },
            systemGPUPercent: systemGPUUtilization()
        )
    }

    private static func processList() -> [ProcessSample] {
        guard let output = run("/bin/ps", arguments: ["-axo", "pid=,ppid=,pcpu=,rss=,command="]) else {
            return []
        }

        return output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(maxSplits: 4, whereSeparator: \.isWhitespace)
            guard fields.count == 5,
                  let pid = Int(fields[0]),
                  let parentPID = Int(fields[1]),
                  let cpuPercent = Double(fields[2]),
                  let residentMemoryKB = UInt64(fields[3]) else { return nil }
            return ProcessSample(
                pid: pid,
                parentPID: parentPID,
                cpuPercent: cpuPercent,
                residentMemoryKB: residentMemoryKB,
                command: String(fields[4])
            )
        }
    }

    private static func isRProcess(_ command: String) -> Bool {
        guard let executable = command.split(whereSeparator: \.isWhitespace).first else { return false }
        let name = URL(fileURLWithPath: String(executable)).lastPathComponent.lowercased()
        return name == "r" || name == "rscript" || name.hasPrefix("rsession")
    }

    private static func threadCount(for pid: Int) -> Int {
        guard let output = run("/bin/ps", arguments: ["-M", "\(pid)"]) else { return 0 }
        return max(0, output.split(whereSeparator: \.isNewline).count - 1)
    }

    private static func systemGPUUtilization() -> Int? {
        guard let output = run("/usr/sbin/ioreg", arguments: ["-r", "-c", "IOAccelerator", "-d", "1"]),
              let regex = try? NSRegularExpression(pattern: #"\"Device Utilization %\"\s*=\s*(\d+)"#),
              let match = regex.firstMatch(
                in: output,
                range: NSRange(output.startIndex..., in: output)
              ),
              let valueRange = Range(match.range(at: 1), in: output) else { return nil }
        return Int(output[valueRange])
    }

    private static func run(_ executable: String, arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
