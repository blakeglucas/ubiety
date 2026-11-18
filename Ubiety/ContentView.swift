import SwiftData
import SwiftUI
import FamilyControls

struct ContentView: View {
    @Environment(RefreshSignal.self) private var signal
    @Environment(\.modelContext) private var context
    @Query var appGroups: [AppGroup]
    
    @State private var searchText = ""
    @State private var isAddFormOpen = false
    @State private var editGroup: AppGroup?
    @State private var deleteGroup: AppGroup?
    
    var body: some View {
        NavigationStack {
            let _ = signal.version;
            List(appGroups) { group in
                let ticks = EnforcerContext.getTicks(id: group.id)
                let isOnCooldown = group.selectedApps.applicationTokens.allSatisfy({ EnforcerContext.getCooldown(token: $0) != nil})
                Button {
                    editGroup = group;
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            if isOnCooldown {
                                Image(systemName: "lock.shield")
                            } else {
                                ProgressRing(progress: Double(ticks) / Double(group.activeTime + 1), lineWidth: 3)
                                    .frame(width:16, height:16)
                                    .tint(.purple)
                            }
                        }
                        .frame(width: 24)
                        
                        Text(group.name)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)

                    }
                }
                .foregroundStyle(.primary)
                .swipeActions {
                    Button (role: .destructive) {
                        deleteGroup = group
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }.alert(
                "Delete \"\(deleteGroup?.name ?? "")\"?",
                isPresented: Binding(get: {deleteGroup != nil}, set: { if !$0 { deleteGroup = nil } }),
                presenting: deleteGroup
            ) { group in
                Button ("Delete", role: .destructive) {
                    context.delete(group)
                    Enforcer.unregister(id: group.id)
                }
            } message: { _ in
                Text("This will remove all restrictions but cannot be undone.")
            }
            .sheet(item: $editGroup) { group in
                AppGroupFormView(group: group)
            }
            .navigationTitle("App Groups")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        LogView().navigationTitle("Logs")
                    } label: {
                        Label("Logs", systemImage: "chart.line.text.clipboard")
                    }
                }
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add", systemImage: "plus") {
                        isAddFormOpen = true
                    }
                }
            }.sheet(isPresented: $isAddFormOpen) {
                AppGroupFormView(group: nil)
            }
        }
    }
}

#Preview {
    ContentView()
}
