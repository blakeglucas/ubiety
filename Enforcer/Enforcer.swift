//
//  Enforcer.swift
//  Ubiety
//
//  Created by blake on 10/5/26.
//

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

func notify(title: String, body: String, after seconds: TimeInterval? = nil) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let trigger = seconds.map {
        UNTimeIntervalNotificationTrigger(timeInterval: $0, repeats: false)
    }

    let request = UNNotificationRequest(
        identifier: UUID().uuidString, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request)
}

enum Phase: String, CaseIterable { case usage, cooldown, night, tick }

extension DeviceActivityName {
    init(_ phase: Phase, _ id: UUID, _ suffix: String = "") {
        self.init("\(phase.rawValue).\(id.uuidString)\(suffix.count > 0 ? "." + suffix : "")")
    }
    var parsed: (phase: Phase, id: UUID)? {
        let parts = rawValue.split(separator: ".").map(String.init)
        guard parts.count >= 2,
              let phase = Phase(rawValue: parts[0]),
              let id = UUID(uuidString: parts[1]) else { return nil }
        return (phase, id)
    }
}

extension DeviceActivityEvent.Name {
    static let limit = Self("limit")
    static let use = Self("use")
}

enum Enforcer {
    private static let center = DeviceActivityCenter()
    private static let cal = Calendar.current
    private static let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    
    static func load() throws {
        Log.startupCheck()
        let groups = try EnforcerContext.getAppGroups()
        for group in groups {
            try start(appGroup: group)
        }
    }
    
    static func register(appGroup: AppGroup) throws {
        Log.debug("registered '\(appGroup.name)' (\(appGroup.id))")
        EnforcerContext.save(appGroup: appGroup)
        stop(appGroup.id)
        try start(appGroup: appGroup)
    }
    
    static func unregister(id: UUID) {
        Log.debug("unregister \(id)")
        stop(id)
        EnforcerContext.remove(id: id)
    }
    
    static func start(appGroup: AppGroup) throws {
        Log.debug("start watching '\(appGroup.name)' (\(appGroup.id))")
        try startTicking(appGroup: appGroup)
        try startUseTracking(group: appGroup)
    }
    
    static func startTicking(appGroup: AppGroup) throws {
        Log.debug("ticking for '\(appGroup.name)' group")
        let event = DeviceActivityEvent(
            applications: appGroup.selectedApps.applicationTokens,
            categories: appGroup.selectedApps.categoryTokens,
            webDomains: appGroup.selectedApps.webDomainTokens,
            threshold: DateComponents(minute: 1)
        )
        try center.startMonitoring(
            .init(.tick, appGroup.id),
            during: DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59),
                repeats: true
            ),
            events: [.limit: event]
        )
    }
    
    static func onTick(group: AppGroup) throws {
        let ticks = EnforcerContext.tick(id: group.id)
        Log.debug("\(group.name): \(ticks) / \(group.activeTime)")
        if ticks > group.activeTime {
            try startCooldown(appGroup: group)
        } else {
            try startTicking(appGroup: group)
        }
    }
    
    static func startUseTracking(group: AppGroup) throws {
        let now = Date.now
        for slot in 0..<3 {
            let start = now.addingTimeInterval(Double(slot) * 5 * 60)
            try initUseTrackingWindow(group: group, start: start)
        }
        
    }
    
    private static func initUseTrackingWindow(group: AppGroup, start: Date) throws {
        let startComponents = cal.dateComponents([.minute], from: start)
        Log.debug("Starting monitoring window beginning at \(startComponents.minute!)")
        try center.startMonitoring(
            .init(.usage, group.id, "\(startComponents.minute!)"),
            during: DeviceActivitySchedule(
                intervalStart: startComponents,
                intervalEnd: cal.dateComponents([.minute], from: start.addingTimeInterval(15 * 60)),
                repeats: false
            ),
        )
    }
    
    static func checkUsageRestore(group: AppGroup, startNext: Bool = false) {
        Log.debug("checking usage restoration for \(group.name) (\(group.id))")
        let ticks = EnforcerContext.getTicks(id: group.id)
        let lastTick = EnforcerContext.getLastTick(id: group.id)
        Log.debug("ticks: \(ticks), lastTick: \(lastTick.map { $0.formatted(.iso8601) } ?? "never" )")
        if abs(Date.now.timeIntervalSince(lastTick ?? Date.now)) >= 9 * 60 && ticks > 0 { // TODO tune time
            let newTicks = EnforcerContext.tick(id: group.id, delta: -5)
            Log.debug("\(group.name) inactive, accumulated ticks now: \(newTicks)")
            notify(title: "Bonus Time!", body: "Inactivity reward: 5 bonus minutes for '\(group.name)'")
        } else {
            Log.debug("no bonus time for \(group.name)")
        }
        if startNext {
            do {
                try initUseTrackingWindow(group: group, start: Date.now.addingTimeInterval(15 * 60))
            } catch {
                Log.error("failed to init next use tracking window: \(error)")
            }
        }
    }
    
    static func resetUsage(appGroup: AppGroup) throws {
        center.stopMonitoring([.init(.tick, appGroup.id)])
        center.stopMonitoring([.init(.usage, appGroup.id)])
        EnforcerContext.resetTicks(id: appGroup.id)
        try start(appGroup: appGroup)
    }
    
    static func startCooldown(appGroup: AppGroup) throws {
        Log.debug("starting cooldown \(appGroup.name) (\(appGroup.id))")
        let now = Date.now
        let cooldownLength = max(appGroup.cooldownTime, 15)
        let end = now.addingTimeInterval(Double(cooldownLength) * 60)
        for token in appGroup.selectedApps.applicationTokens {
            EnforcerContext.setCooldown(token: token, cooldownEnd: end)
        }
        try shield(appGroup: appGroup, phase: Phase.cooldown)
        try center.startMonitoring(
            .init(.cooldown, appGroup.id),
            during: DeviceActivitySchedule(
                intervalStart: cal.dateComponents(fields, from: now),
                intervalEnd: cal.dateComponents(fields, from: end),
                repeats: false
            )
        )
    }
    
    static func onCooldownEnd(group: AppGroup) throws {
        Log.debug("cooldown end for: \(group.name) (\(group.id))")
        for token in group.selectedApps.applicationTokens {
            EnforcerContext.setCooldown(token: token, cooldownEnd: nil) // FIXME this will clear overlapping cooldowns for same app across groups
        }
        Enforcer.unshield(id: group.id, phase: .cooldown)
        notify(title: "Cooldown Over", body: "'\(group.name)' group is now unlocked")
        try Enforcer.resetUsage(appGroup: group)
    }
    
    static func shield(appGroup: AppGroup, phase: Phase) throws {
        Log.debug("shielding \(appGroup.name) (\(appGroup.id)), phase: \(phase.rawValue)")
        let store = ManagedSettingsStore(named: .init("\(phase.rawValue).\(appGroup.id)"))
        store.shield.applications = appGroup.selectedApps.applicationTokens
        store.shield.applicationCategories = .specific(appGroup.selectedApps.categoryTokens)
        store.shield.webDomains = appGroup.selectedApps.webDomainTokens
    }
    
    static func unshield(id: UUID, phase: Phase) {
        Log.debug("unshielding \(id), phase: \(phase.rawValue)")
        ManagedSettingsStore(named: .init("\(phase.rawValue).\(id)")).clearAllSettings()
    }
    
    private static func stop(_ id: UUID) {
        center.stopMonitoring(Phase.allCases.map { .init($0, id) })
        Phase.allCases.forEach { unshield(id: id, phase: $0) }
    }
}
