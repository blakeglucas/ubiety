import FamilyControls
import SwiftData
import SwiftUI

@Model
final class AppGroup: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var selectedApps: FamilyActivitySelection
    var activeTime: Int
    var cooldownTime: Int
    var wakeupTime: Date?
    var bedtime: Date?
    
    init(name: String,
         selectedApps: FamilyActivitySelection = FamilyActivitySelection(),
         activeTime: Int,
         cooldownTime: Int,
         wakeupTime: Date?,
         bedtime: Date?,
    ) {
        self.name = name
        self.selectedApps = selectedApps
        self.activeTime = activeTime
        self.cooldownTime = cooldownTime
        self.wakeupTime = wakeupTime
        self.bedtime = bedtime
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, selectedApps, activeTime, cooldownTime, wakeupTime, bedtime
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        activeTime = try container.decode(Int.self, forKey: .activeTime)
        cooldownTime = try container.decode(Int.self, forKey: .cooldownTime)
        wakeupTime = try container.decodeIfPresent(Date.self, forKey: .wakeupTime)
        bedtime = try container.decodeIfPresent(Date.self, forKey: .bedtime)
        selectedApps = try container.decode(FamilyActivitySelection.self, forKey: .selectedApps)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(selectedApps, forKey: .selectedApps)
        try container.encode(activeTime, forKey: .activeTime)
        try container.encode(cooldownTime, forKey: .cooldownTime)
        try container.encodeIfPresent(wakeupTime, forKey: .wakeupTime)
        try container.encodeIfPresent(bedtime, forKey: .bedtime)
    }
}
