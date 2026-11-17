import FamilyControls
import SwiftData
import SwiftUI

struct AppGroupFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var group: AppGroup?
    
    @State private var name: String
    @State private var activeTime: Int
    @State private var cooldownTime: Int
    @State private var enforceWakeup: Bool
    @State private var wakeupTime: Date
    @State private var enforceBedtime: Bool
    @State private var bedtime: Date
    
    @State private var title: String
    @State private var isPickerShown = false
    @State private var selectedApps: FamilyActivitySelection
    
    init(group: AppGroup?) {
        self.group = group
        if group != nil {
            title = "Edit App Group"
        } else {
            title = "Create App Group"
        }
        _name = State(initialValue: group?.name ?? "")
        _selectedApps = State(initialValue: group?.selectedApps ?? FamilyActivitySelection())
        _activeTime = State(initialValue: group?.activeTime ?? 30)
        _cooldownTime = State(initialValue: group?.cooldownTime ?? 30)
        _enforceWakeup = State(initialValue: group?.wakeupTime != nil)
        _wakeupTime = State(initialValue: group?.wakeupTime
                            ?? Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!)
        _enforceBedtime = State(initialValue: group?.bedtime != nil)
        _bedtime = State(initialValue: group?.bedtime
                         ?? Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: .now)!)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Stepper("Active: \(activeTime) minutes", value: $activeTime, in: 15...240, step: 5)
                    Stepper("Cooldown: \(cooldownTime) minutes", value: $cooldownTime, in: 15...240, step: 5)
                    Toggle("Enforce Wakeup", isOn: $enforceWakeup)
                    if enforceWakeup {
                        DatePicker("Block Until:", selection: $wakeupTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("Enforce Bedtime", isOn: $enforceBedtime)
                    if enforceBedtime {
                        DatePicker("Block After:", selection: $bedtime, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section {
                    Button("Select Apps") {isPickerShown = true }
                        .familyActivityPicker(isPresented: $isPickerShown, selection: $selectedApps)
                }
                
                if !selectedApps.applicationTokens.isEmpty {
                    Section("Apps") {
                        ForEach(Array(selectedApps.applicationTokens), id: \.self) {token in
                            Label(token)
                        }
                    }
                }
                
                if !selectedApps.categoryTokens.isEmpty {
                    Section("Categories") {
                        ForEach(Array(selectedApps.categoryTokens), id: \.self) {token in
                            Label(token)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let group {
                            group.name = name
                            group.selectedApps = selectedApps
                            group.activeTime = activeTime
                            group.cooldownTime = cooldownTime
                            group.wakeupTime = enforceWakeup ? wakeupTime : nil
                            group.bedtime = enforceBedtime ? bedtime : nil
                        } else {
                            group = AppGroup(name: name,
                                             selectedApps: selectedApps,
                                             activeTime: activeTime,
                                             cooldownTime: cooldownTime,
                                             wakeupTime: enforceWakeup ? wakeupTime : nil,
                                             bedtime: enforceBedtime ? bedtime : nil,
                                            )
                            context.insert(group!)
                        }
                        
                        do {
                            try context.save()
                            try Enforcer.register(appGroup: group!)
                            dismiss()
                        } catch {
                            Log.error("FUCK: \(error)")
                        }
                    }
                    .disabled(name.isEmpty || (selectedApps.applicationTokens.isEmpty && selectedApps.categoryTokens.isEmpty))
                }
            }
        }
    }
}
