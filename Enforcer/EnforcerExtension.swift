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
        Enforcer.onTick(group: group)
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        guard let (phase, id) = activity.parsed,
            let group = EnforcerContext.load(id: id)
        else { return }
        if phase == .night {
            Enforcer.shield(appGroup: group, phase: .night)
        } else if phase == .usage {
            Enforcer.checkUsageRestore(group: group)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        guard let (phase, id) = activity.parsed,
            let group = EnforcerContext.load(id: id)
        else { return }
        switch phase {
        case .night:
            Enforcer.unshield(id: id, phase: .night)
        case .cooldown:
            Enforcer.onCooldownEnd(group: group)
        case .tick:
            break
        case .usage:
            Enforcer.checkUsageRestore(group: group, startNext: true)
        }
    }
}
