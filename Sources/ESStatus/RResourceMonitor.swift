import Foundation

struct RResourceSnapshot {
    let cpuPercent: Double
    let memoryPercent: Double
    let memoryBytes: UInt64
    let totalMemoryBytes: UInt64
    let processCount: Int
    let workerCount: Int

    static let empty = RResourceSnapshot(
        cpuPercent: 0,
        memoryPercent: 0,
        memoryBytes: 0,
        totalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
        processCount: 0,
        workerCount: 0
    )
}

private struct ProcessSample {
    let pid: Int
    let parentPID: Int
    let cpuPercent: Double
    let residentKilobytes: UInt64
    let command: String
}

enum RResourceMonitor {
    static func sample(rootPID: Int? = nil) -> RResourceSnapshot {
        let allProcesses = processList()
        let parentByPID = Dictionary(uniqueKeysWithValues: allProcesses.map { ($0.pid, $0.parentPID) })
        let detectedRStudioPIDs = Set(allProcesses.filter { isRStudioSession($0.command) }.map(\.pid))
        let rootPIDs: Set<Int>
        if let rootPID, allProcesses.contains(where: { $0.pid == rootPID }) {
            rootPIDs = [rootPID]
        } else {
            rootPIDs = detectedRStudioPIDs
        }
        let rProcesses = allProcesses.filter { process in
            guard isRProcess(process.command) else { return false }
            if rootPIDs.contains(process.pid) { return true }
            var parent = process.parentPID
            var visited = Set<Int>()
            while parent > 1, visited.insert(parent).inserted {
                if rootPIDs.contains(parent) { return true }
                parent = parentByPID[parent] ?? 0
            }
            // PSOCK/future workers can be re-parented by macOS before the next
            // sample. Their command still contains the R parallel bootstrap.
            return !rootPIDs.isEmpty && isParallelWorkerCommand(process.command)
        }
        let rPIDs = Set(rProcesses.map(\.pid))

        let workerCount = rProcesses.filter { process in
            if isParallelWorkerCommand(process.command) {
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

        let perCoreCPUPercent = rProcesses.reduce(0) { $0 + $1.cpuPercent }
        let availableCPUs = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let memoryBytes = rProcesses.reduce(UInt64(0)) {
            $0.addingReportingOverflow($1.residentKilobytes * 1024).partialValue
        }
        let totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        let memoryPercent = totalMemoryBytes > 0
            ? min(100, Double(memoryBytes) / Double(totalMemoryBytes) * 100)
            : 0

        return RResourceSnapshot(
            cpuPercent: min(100, perCoreCPUPercent / Double(availableCPUs)),
            memoryPercent: memoryPercent,
            memoryBytes: memoryBytes,
            totalMemoryBytes: totalMemoryBytes,
            processCount: rProcesses.count,
            workerCount: workerCount
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
                  let residentKilobytes = UInt64(fields[3]) else { return nil }
            return ProcessSample(
                pid: pid,
                parentPID: parentPID,
                cpuPercent: cpuPercent,
                residentKilobytes: residentKilobytes,
                command: String(fields[4])
            )
        }
    }

    private static func isRProcess(_ command: String) -> Bool {
        guard let executable = command.split(whereSeparator: \.isWhitespace).first else { return false }
        let name = URL(fileURLWithPath: String(executable)).lastPathComponent.lowercased()
        return name == "r" || name == "rscript" || name.hasPrefix("rsession")
    }

    private static func isRStudioSession(_ command: String) -> Bool {
        guard let executable = command.split(whereSeparator: \.isWhitespace).first else { return false }
        return URL(fileURLWithPath: String(executable))
            .lastPathComponent.lowercased().hasPrefix("rsession")
    }

    private static func isParallelWorkerCommand(_ command: String) -> Bool {
        let normalized = command.lowercased()
        return normalized.contains("parallel:::.workrsock") ||
            normalized.contains("parallel:::.slaversock") ||
            normalized.contains(" master=")
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
