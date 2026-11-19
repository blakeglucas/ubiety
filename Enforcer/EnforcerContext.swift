//
//  EnforcerContext.swift
//  Ubiety
//
//  Created by blake on 10/5/26.
//

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

struct MessageError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

extension ApplicationToken {
    var debugID: String {
        guard let data = try? JSONEncoder().encode(self) else { return "<unencodable>" }
        return String(data.base64EncodedString().prefix(12))   // short, stable-ish prefix
    }
}

final class EnforcerContext {
    private static let defaults = UserDefaults(suiteName: "group.dev.bgcl.ubiety")!
    
    private static let cooldownDir: URL? = {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.dev.bgcl.ubiety") else { return nil }
        let dir = container.appendingPathComponent("cooldowns", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    static func save(appGroup: AppGroup) {
        defaults.set(try? JSONEncoder().encode(appGroup), forKey: "appGroup.\(appGroup.id)")
    }
    
    static func remove(id: UUID) {
        defaults.removeObject(forKey: "appGroup.\(id)")
    }
    
    static func load(id: UUID) -> AppGroup? {
        defaults.data(forKey: "appGroup.\(id)").flatMap { try? JSONDecoder().decode(AppGroup.self, from: $0) }
    }
    
    static func getAppGroups() throws -> [AppGroup] {
        let domain = defaults.persistentDomain(forName: "group.dev.bgcl.ubiety") ?? [:]
        let decoder = JSONDecoder()

        return try domain
            .filter { $0.key.hasPrefix("appGroup") }
            .compactMap { key, value in
                guard let data = value as? Data else { throw MessageError(message: "FUCK") }
                return try decoder.decode(AppGroup.self, from: data)
            }
    }
    
    static func tick(id: UUID, delta: Int = 1) -> Int {
        var val = defaults.integer(forKey: "ticks.appGroup.\(id)")
        val += delta;
        val = max(val, 0)
        defaults.set(val, forKey: "ticks.appGroup.\(id)")
        defaults.set(Date.now, forKey: "lastTick.appGroup.\(id)")
        SharedChangeObserver.post()
        return val
    }
    
    static func getTicks(id: UUID) -> Int {
        return defaults.integer(forKey: "ticks.appGroup.\(id)")
    }
    
    static func resetTicks(id: UUID) {
        defaults.set(0, forKey: "ticks.appGroup.\(id)")
        SharedChangeObserver.post()
    }
    
    static func getLastTick(id: UUID) -> Date? {
        return defaults.object(forKey: "lastTick.appGroup.\(id)") as? Date
    }
    
    private static func cooldownURL(_ token: ApplicationToken) throws -> URL? {
        let data = try JSONEncoder().encode(token)
        let name = data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return cooldownDir?.appendingPathComponent(name)
    }
    
    static func setCooldown(token: ApplicationToken, cooldownEnd: Date?) throws {
        guard let url = try cooldownURL(token) else {
            throw MessageError(message: "failed to get cooldownURL")
        }
        if let cooldownEnd {
            let text = cooldownEnd.ISO8601Format()
            do { try Data(text.utf8).write(to: url, options: .atomic) }
            catch { Log.error("cooldown write failed: \(error)", category: "cooldown") }
        } else {
            try? FileManager.default.removeItem(at: url)
        }
        SharedChangeObserver.post()
    }
    
    static func getCooldown(token: ApplicationToken) throws -> Date? {
        guard let url = try cooldownURL(token),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
          return try Date(text, strategy: .iso8601)
    }
}
