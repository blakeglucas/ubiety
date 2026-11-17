//
//  EnforcerExtension.swift
//  Ubiety
//
//  Created by blake on 10/5/26.
//

import DeviceActivity

class EnforcerExtension: DeviceActivityMonitor {
    override init() {
        super.init()
        Log.startupCheck()
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        guard let (phase, id) = activity.parsed, phase == .tick,
            let group = EnforcerContext.load(id: id)
        else { return }
        try? Enforcer.onTick(group: group)
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        Log.debug("interval started...")
        guard let (phase, id) = activity.parsed,
            let group = EnforcerContext.load(id: id)
        else { return }
        Log.debug("  \(group.name): \(phase)")
        if phase == .night {
            _ = try? Enforcer.shield(appGroup: group, phase: .night)
        } else if phase == .usage {
            Enforcer.checkUsageRestore(group: group)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        Log.debug("interval ended...")
        guard let (phase, id) = activity.parsed,
            let group = EnforcerContext.load(id: id)
        else { return }
        Log.debug("  \(group.name): \(phase)")
        switch phase {
        case .night:
            Enforcer.unshield(id: id, phase: .night)
        case .cooldown:
            try? Enforcer.onCooldownEnd(group: group)
        case .tick:
            break
        case .usage:
            Enforcer.checkUsageRestore(group: group, startNext: true)
        }
    }
}
