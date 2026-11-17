//
//  Log.swift
//  Ubiety
//
//  Created by blake on 11/17/26.
//


// Log.swift
// Shared logging for the app and all extensions (monitor, shield configuration, shield action).
// Add this file to every target (Target Membership) or put it in your shared Core package
// (mark the API `public` — it already is).
//
// Each log call goes to two places:
//   1. os.Logger  → live in Console.app (filter by subsystem "com.you.app")
//   2. A JSON-lines file per process in the App Group container → readable later from the app
//
// One file per process avoids two processes writing to the same file at once.

import Foundation
import os

public enum Log {

    // MARK: - Configuration

    public static let subsystem = "dev.bgcl.ubiety"
    public static let appGroup = "group.\(subsystem)"
    public static var minimumLevel: Level = .debug        // raise in release builds if you like
    static let maxFileBytes = 256 * 1024                  // rotate at 256 KB (keeps 2 files per process)

    /// Short name for the current process, e.g. "app", "monitor", "shieldconfig".
    /// Derived from the last component of the bundle ID.
    public static let process: String = {
        let id = Bundle.main.bundleIdentifier ?? "unknown"
        let last = id.components(separatedBy: ".").last ?? id
        return id == subsystem ? "app" : last.lowercased()
    }()

    // MARK: - Levels

    public enum Level: Int, Codable, Comparable, Sendable, CaseIterable {
        case debug, info, notice, error, fault

        public static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }

        var osType: OSLogType {
            switch self {
            case .debug:  return .debug
            case .info:   return .info
            case .notice: return .default
            case .error:  return .error
            case .fault:  return .fault
            }
        }

        public var tag: String { ["DBG", "INF", "NOT", "ERR", "FLT"][rawValue] }
    }

    // MARK: - Entry (one line in the log file)

    public struct Entry: Codable, Sendable, Identifiable {
        public var id: String { "\(date.timeIntervalSince1970)-\(process)-\(line)-\(message.hashValue)" }
        public let date: Date
        public let level: Level
        public let process: String
        public let category: String
        public let message: String
        public let file: String
        public let line: Int
    }

    // MARK: - Public logging API

    public static func debug(_ message: @autoclosure () -> String, category: String = "general",
                             file: String = #fileID, line: Int = #line) {
        log(.debug, message(), category: category, file: file, line: line)
    }

    public static func info(_ message: @autoclosure () -> String, category: String = "general",
                            file: String = #fileID, line: Int = #line) {
        log(.info, message(), category: category, file: file, line: line)
    }

    public static func notice(_ message: @autoclosure () -> String, category: String = "general",
                              file: String = #fileID, line: Int = #line) {
        log(.notice, message(), category: category, file: file, line: line)
    }

    public static func error(_ message: @autoclosure () -> String, category: String = "general",
                             file: String = #fileID, line: Int = #line) {
        log(.error, message(), category: category, file: file, line: line)
    }

    public static func fault(_ message: @autoclosure () -> String, category: String = "general",
                             file: String = #fileID, line: Int = #line) {
        log(.fault, message(), category: category, file: file, line: line)
    }

    public static func log(_ level: Level, _ message: @autoclosure () -> String,
                           category: String = "general",
                           file: String = #fileID, line: Int = #line) {
        guard level >= minimumLevel else { return }
        let msg = message()

        // 1. Unified logging (Console.app). Marked public so it's readable without a debugger.
        Logger(subsystem: subsystem, category: category)
            .log(level: level.osType, "[\(process, privacy: .public)] \(msg, privacy: .public)")

        // 2. App Group file.
        guard let url = fileURL else { return }
        let entry = Entry(date: Date(), level: level, process: process, category: category,
                          message: msg, file: file, line: line)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard var data = try? encoder.encode(entry) else { return }
        data.append(0x0A) // newline

        // Synchronous so the line is on disk before an extension callback returns.
        writeQueue.sync { append(data, to: url) }
    }

    // MARK: - Health check (call first thing in every target)

    /// Logs whether this process can reach the App Group and records a heartbeat.
    /// Call from the app at launch and at the top of every extension callback / init.
    /// A missing heartbeat for a process in the app's log viewer = broken entitlement for that target.
    public static func startupCheck() {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)

        guard container != nil else {
            // Can't write to the file, so make it loud in Console.app.
            Logger(subsystem: subsystem, category: "health").fault(
                "[\(process, privacy: .public)] App Group '\(appGroup, privacy: .public)' UNAVAILABLE — check the App Groups capability and entitlements file for this target")
            return
        }

        UserDefaults(suiteName: appGroup)?.set(Date(), forKey: "heartbeat.\(process)")
        debug("startup OK, bundle=\(Bundle.main.bundleIdentifier ?? "?")", category: "health")
    }

    /// Last time each process ran `startupCheck()`, read from the shared defaults.
    public static func heartbeats() -> [String: Date] {
        guard let domain = UserDefaults(suiteName: appGroup)?.persistentDomain(forName: appGroup)
        else { return [:] }
        var result: [String: Date] = [:]
        for (key, value) in domain where key.hasPrefix("heartbeat.") {
            if let date = value as? Date { result[String(key.dropFirst("heartbeat.".count))] = date }
        }
        return result
    }

    // MARK: - Reading (use from the app, not from extensions)

    /// All entries from every process, oldest first, capped at `limit` most recent.
    public static func readAll(limit: Int = 2000) -> [Entry] {
        guard let dir = logsDirectory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil)
        else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        var entries: [Entry] = []
        for file in files where file.pathExtension == "jsonl" {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") {
                if let entry = try? decoder.decode(Entry.self, from: Data(line.utf8)) {
                    entries.append(entry)
                }
            }
        }
        entries.sort { $0.date < $1.date }
        return Array(entries.suffix(limit))
    }

    /// Everything as plain text, e.g. for a ShareLink or copying to the clipboard.
    public static func exportText() -> String {
        readAll(limit: .max).map { e in
            "\(e.date.formatted(.iso8601)) \(e.level.tag) [\(e.process)/\(e.category)] \(e.message)  (\(e.file):\(e.line))"
        }.joined(separator: "\n")
    }

    /// Deletes all log files from every process.
    public static func clear() {
        guard let dir = logsDirectory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil)
        else { return }
        for file in files { try? FileManager.default.removeItem(at: file) }
    }

    // MARK: - Internals

    private static let writeQueue = DispatchQueue(label: "\(subsystem).log.write")

    static let logsDirectory: URL? = {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        else { return nil }
        let dir = container.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let fileURL: URL? =
        logsDirectory?.appendingPathComponent("\(process).jsonl")

    private static func append(_ data: Data, to url: URL) {
        let fm = FileManager.default

        // Rotate: current → .1 (overwriting the previous .1).
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        if let size = attrs?[.size] as? Int, size > maxFileBytes {
            let rotated = url.deletingPathExtension().appendingPathExtension("1.jsonl")
            try? fm.removeItem(at: rotated)
            try? fm.moveItem(at: url, to: rotated)
        }

        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}
