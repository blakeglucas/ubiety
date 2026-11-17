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
    
    static func setCooldown(token: ApplicationToken, cooldownEnd: Date?) {
        if cooldownEnd == nil {
            defaults.removeObject(forKey: "cdts.app.\(token)")
        } else {
            defaults.set(cooldownEnd, forKey: "cdts.app.\(token)")
        }
        SharedChangeObserver.post()
    }
    
    static func getCooldown(token: ApplicationToken) -> Date? {
        return defaults.object(forKey: "cdts.app.\(token)") as? Date
    }
}
