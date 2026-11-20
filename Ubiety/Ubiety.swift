import BackgroundTasks
import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI
import UserNotifications

let SWEEP_APP_KEY = "dev.bgcl.ubiety.sweep"

func scheduleSweep() async {
    let request = BGAppRefreshTaskRequest(identifier: SWEEP_APP_KEY)
    request.earliestBeginDate = .now.addingTimeInterval(15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}

@main struct Ubiety: App {
    @State private var signal = RefreshSignal()
    init() {
        Log.startupCheck()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(signal)
                .task {
                    do {
                        try await AuthorizationCenter.shared
                            .requestAuthorization(for: .individual)
                        try Enforcer.load()
//                        try await UNUserNotificationCenter.current()
//                            .requestAuthorization(options: [.alert, .sound])
                        SharedChangeObserver.addHandler {
                            Task {
                                @MainActor in signal.bump()
                            }
                        }
                        Enforcer.sweepExpiredCooldowns()
                    } catch {
                        Log.error("Initialization failed: \(error)")
                    }
                }
        }.modelContainer(for: AppGroup.self).backgroundTask(
            .appRefresh(SWEEP_APP_KEY)
        ) {
            await Enforcer.sweepExpiredCooldowns()
            await scheduleSweep()
        }
    }
}

extension String: @retroactive Error {}
extension String: @retroactive LocalizedError {
    public var errorDescription: String? { return self }
}
