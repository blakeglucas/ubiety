//
//  ProgressRing.swift
//  Ubiety
//
//  Created by blake on 11/17/26.
//
import SwiftData
import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
        }
    }
}
