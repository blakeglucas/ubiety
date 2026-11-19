//
//  ShieldConfigurationExtension.swift
//  ShieldConfiguration
//
//  Created by blake on 10/5/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension : ShieldConfigurationDataSource {
    override init() {
        super.init()
        Log.startupCheck()
    }
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        var cooldown: Date? = nil
        if let token = application.token {
            cooldown = try? EnforcerContext.getCooldown(token: token)
        }
        return makeShield(name: application.localizedDisplayName, cooldownEnd: cooldown)
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        var cooldown: Date? = nil
        if let token = application.token {
            cooldown = try? EnforcerContext.getCooldown(token: token)
        }
        return makeShield(name: application.localizedDisplayName, cooldownEnd: cooldown)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeShield(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeShield(name: webDomain.domain)
    }

    private func makeShield(name: String?, cooldownEnd: Date? = nil) -> ShieldConfiguration {
        let availAtStmt = cooldownEnd.map { "at \($0.formatted(date: .omitted, time: .shortened))" } ?? "soon"
        Log.error("making shield for cooldown ending \(availAtStmt)")
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: .systemIndigo.withAlphaComponent(0.6),
            icon: UIImage(systemName: "hourglass"),
            title: .init(text: "\(name ?? "This app") is on cooldown", color: .label),
            subtitle: .init(text: "It'll be back \(availAtStmt).", color: .secondaryLabel),
//            primaryButtonLabel: .init(text: "OK", color: .white),
//            primaryButtonBackgroundColor: .purple,
        )
    }
}
