import Foundation

/// Agent adapter that monitors a log file or directory for keyword/regex state markers.
public final class LogWatcherAgentAdapter: AgentAdapter, @unchecked Sendable {
    public let id: String
    public let agentID: String
    public let agentName: String
    public let logFileURL: URL
    private let clock: @Sendable () -> Date

    private var eventHandler: (@Sendable (AgentEvent) -> Void)?
    private var source: DispatchSourceFileSystemObject? = nil
    private var fileDescriptor: Int32 = -1
    private var lastOffset: UInt64 = 0
    private let queue = DispatchQueue(label: "com.bitz.agent.logwatcher", qos: .utility)

    public init(
        id: String = "log-watcher-adapter",
        agentID: String,
        agentName: String,
        logFileURL: URL,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.id = id
        self.agentID = agentID
        self.agentName = agentName
        self.logFileURL = logFileURL
        self.clock = clock
    }

    public func setHandlerForTesting(_ onEvent: @escaping @Sendable (AgentEvent) -> Void) {
        self.eventHandler = onEvent
    }

    public func start(onEvent: @escaping @Sendable (AgentEvent) -> Void) {
        self.eventHandler = onEvent

        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let size = attrs[.size] as? UInt64 {
            lastOffset = size
        }

        // Open descriptor for DispatchSource
        fileDescriptor = open(logFileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            self?.readNewLogLines()
        }

        src.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        self.source = src
        src.resume()
    }

    public func stop() {
        source?.cancel()
        source = nil
        eventHandler = nil
    }

    private let lock = NSLock()

    /// Public method to parse newly appended lines, testable deterministically.
    public func readNewLogLines() {
        lock.lock()
        defer { lock.unlock() }

        guard let handler = eventHandler else { return }
        guard let handle = try? FileHandle(forReadingFrom: logFileURL) else { return }
        defer { try? handle.close() }

        handle.seek(toFileOffset: lastOffset)
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return }
        lastOffset += UInt64(data.count)

        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
        let lines = text.components(separatedBy: .newlines)

        let now = clock()
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("approval") || lower.contains("confirm") || lower.contains("permission") {
                handler(AgentEvent(
                    agentID: agentID,
                    agentName: agentName,
                    kind: .needsApproval,
                    message: "\(agentName) needs approval!",
                    timestamp: now
                ))
            } else if lower.contains("finished") || lower.contains("completed") || lower.contains("done") {
                handler(AgentEvent(
                    agentID: agentID,
                    agentName: agentName,
                    kind: .done,
                    message: "\(agentName) is done!",
                    timestamp: now
                ))
            }
        }
    }
}
