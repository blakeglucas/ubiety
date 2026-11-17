//
//  SharedChangeObserver.swift
//  Ubiety
//
//  Created by blake on 11/17/26.
//


// SharedChangeObserver.swift
// Cross-process "something changed in the App Group" signal, using Darwin notifications.
//
// Add to every target (app + all extensions), or put it in your shared Core package.
//   • Extensions / shared write helpers call `SharedChangeObserver.post()` after writing.
//   • The app calls `SharedChangeObserver.addHandler { ... }` once and reloads/bumps in it.
//
// Darwin notifications carry no payload and are only delivered to processes that are
// currently running. Treat each one as "re-read from the App Group", and also reload
// when the app becomes active to catch anything posted while it was suspended.

import Foundation
import os

public enum SharedChangeObserver {

    /// Must be identical in every target. Reverse-DNS, unique to your app.
    public static let notificationName = "dev.bgcl.ubiety.ChangeBroadcast"

    public typealias Handler = @Sendable () -> Void

    // MARK: - Posting (safe to call from any process, including extensions)

    /// Tell every running process that shared data changed.
    /// The posting process receives it too, if it has handlers registered.
    public static func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName as CFString),
            nil,    // object: ignored by the Darwin center
            nil,    // userInfo: not supported by the Darwin center
            true    // deliverImmediately
        )
    }

    // MARK: - Observing (normally only the app does this)

    /// Registers a handler. Returns an ID you can pass to `removeHandler` (usually unnecessary).
    /// Handlers run on an arbitrary thread; hop to the main actor before touching UI state.
    @discardableResult
    public static func addHandler(_ handler: @escaping Handler) -> UUID {
        let id = UUID()
        let needsRegistration = state.withLock { s -> Bool in
            s.handlers[id] = handler
            let first = !s.registered
            s.registered = true
            return first
        }
        if needsRegistration { registerWithDarwinCenter() }
        return id
    }

    public static func removeHandler(_ id: UUID) {
        state.withLock { _ = $0.handlers.removeValue(forKey: id) }
    }

    // MARK: - Internals

    private struct State {
        var handlers: [UUID: Handler] = [:]
        var registered = false
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())

    /// Registered once per process. The callback is a C function pointer, so it can't
    /// capture anything; it calls back into this type's static state instead.
    private static func registerWithDarwinCenter() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in SharedChangeObserver.fire() },
            notificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    private static func fire() {
        // Copy out under the lock, call outside it, so a handler can add/remove handlers safely.
        let handlers = state.withLock { Array($0.handlers.values) }
        for handler in handlers { handler() }
    }
}
