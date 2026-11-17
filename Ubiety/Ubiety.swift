import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI
import UserNotifications

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
                        try await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound])
                    } catch {
                        Log.error("Initialization failed: \(error)")
                    }
                    SharedChangeObserver.addHandler {
                        Task {
                            @MainActor in signal.bump()
                        }
                    }
                }
        }.modelContainer(for: AppGroup.self)
    }
}

extension String: @retroactive Error {}
extension String: @retroactive LocalizedError {
    public var errorDescription: String? { return self }
}
