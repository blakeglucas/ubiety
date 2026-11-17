//
//  LogView.swift
//  Ubiety
//
//  Created by blake on 11/17/26.
//
import SwiftData
import SwiftUI

struct LogView: View {
    @State private var entries: [Log.Entry] = []
    @State private var beats: [String: Date] = [:]

    var body: some View {
        List {
            Section("Heartbeats") {
                ForEach(beats.sorted(by: { $0.key < $1.key }), id: \.key) { name, date in
                    LabeledContent(name, value: date.formatted(date: .omitted, time: .standard))
                }
            }
            Section("Log") {
                ForEach(entries.reversed()) { e in
                    VStack(alignment: .leading) {
                        Text("\(e.level.tag) \(e.process)/\(e.category) · \(e.date.formatted(date: .omitted, time: .standard))")
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text(e.message).font(.callout.monospaced())
                    }
                }
            }
        }
        .toolbar {
            ShareLink(item: Log.exportText())
            Button("Clear") { Log.clear(); reload() }
        }
        .refreshable { reload() }
        .onAppear { reload() }
    }

    private func reload() { entries = Log.readAll(); beats = Log.heartbeats() }
}
