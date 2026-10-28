import Foundation

/// Agent adapter that monitors Antigravity's active session transcript (`transcript.jsonl`)
/// in `~/.gemini/antigravity/brain/<id>/.system_generated/logs/`.
public final class AntigravityTranscriptAdapter: AgentAdapter, @unchecked Sendable {
    public let id: String = "antigravity-transcript-adapter"
    public let agentID: String = "antigravity"
    public let agentName: String = "Antigravity"

    public let baseBrainURL: URL
    private let clock: @Sendable () -> Date
    private var eventHandler: (@Sendable (AgentEvent) -> Void)?
    private var pollTask: Task<Void, Never>? = nil

    private var currentTranscriptURL: URL? = nil
    private var lastOffset: UInt64 = 0
    private let lock = NSLock()

    public static var defaultBrainURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gemini/antigravity/brain")
    }

    public init(
        baseBrainURL: URL = AntigravityTranscriptAdapter.defaultBrainURL,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.baseBrainURL = baseBrainURL
        self.clock = clock
    }

    public func setHandlerForTesting(_ onEvent: @escaping @Sendable (AgentEvent) -> Void) {
        self.eventHandler = onEvent
    }

    public func start(onEvent: @escaping @Sendable (AgentEvent) -> Void) {
        self.eventHandler = onEvent
        self.pollTask?.cancel()

        // Locate initial active transcript and set offset to EOF to avoid replaying history
        if let latest = findLatestTranscriptURL() {
            self.currentTranscriptURL = latest
            if let attrs = try? FileManager.default.attributesOfItem(atPath: latest.path),
               let size = attrs[.size] as? UInt64 {
                self.lastOffset = size
            }
        }

        // Poll for updates every 1.5 seconds
        self.pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                self.checkForUpdates()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
        eventHandler = nil
        lock.lock()
        currentTranscriptURL = nil
        lastOffset = 0
        lock.unlock()
    }

    /// Finds the most recently modified `transcript.jsonl` under `baseBrainURL`.
    public func findLatestTranscriptURL() -> URL? {
        let fileManager = FileManager.default
        guard let subdirs = try? fileManager.contentsOfDirectory(
            at: baseBrainURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return nil
        }

        var candidates: [(url: URL, date: Date)] = []
        for subdir in subdirs {
            let transcriptURL = subdir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            if fileManager.fileExists(atPath: transcriptURL.path),
               let attrs = try? fileManager.attributesOfItem(atPath: transcriptURL.path),
               let date = attrs[.modificationDate] as? Date {
                candidates.append((transcriptURL, date))
            }
        }

        candidates.sort { $0.date > $1.date }
        return candidates.first?.url
    }

    /// Checks the active transcript for newly appended log entries.
    public func checkForUpdates() {
        lock.lock()
        defer { lock.unlock() }

        guard let handler = eventHandler else { return }

        // Refresh transcript URL if a newer one appeared
        if let latest = findLatestTranscriptURL() {
            if currentTranscriptURL != latest {
                currentTranscriptURL = latest
                if let attrs = try? FileManager.default.attributesOfItem(atPath: latest.path),
                   let size = attrs[.size] as? UInt64 {
                    lastOffset = size
                }
                return
            }
        }

        guard let transcriptURL = currentTranscriptURL,
              let handle = try? FileHandle(forReadingFrom: transcriptURL) else {
            return
        }
        defer { try? handle.close() }

        // Check if file was truncated/recreated
        let currentSize = handle.seekToEndOfFile()
        if currentSize < lastOffset {
            lastOffset = 0
        }

        handle.seek(toFileOffset: lastOffset)
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return }

        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }

        // Protect against partial line reads
        let endsWithNewline = text.hasSuffix("\n")
        var lines = text.components(separatedBy: .newlines)
        if !endsWithNewline && !lines.isEmpty {
            let incomplete = lines.removeLast()
            let incompleteBytes = incomplete.utf8.count
            lastOffset += UInt64(data.count - incompleteBytes)
        } else {
            lastOffset += UInt64(data.count)
        }

        let now = clock()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            let type = obj["type"] as? String
            let status = obj["status"] as? String
            let toolCalls = obj["tool_calls"] as? [[String: Any]] ?? []

            if type == "USER_INPUT" {
                handler(AgentEvent(
                    agentID: agentID,
                    agentName: agentName,
                    kind: .working,
                    message: "Antigravity is working...",
                    timestamp: now
                ))
            } else if type == "PLANNER_RESPONSE" {
                let hasAskQuestion = toolCalls.contains { call in
                    if let function = call["function"] as? [String: Any],
                       let name = function["name"] as? String,
                       name == "ask_question" {
                        return true
                    }
                    return false
                }

                if hasAskQuestion {
                    handler(AgentEvent(
                        agentID: agentID,
                        agentName: agentName,
                        kind: .needsApproval,
                        message: "Antigravity needs input!",
                        timestamp: now
                    ))
                } else if status == "DONE" && toolCalls.isEmpty {
                    handler(AgentEvent(
                        agentID: agentID,
                        agentName: agentName,
                        kind: .done,
                        message: "Antigravity is done!",
                        timestamp: now
                    ))
                }
            }
        }
    }
}
