//
//  RefreshSignal.swift
//  Ubiety
//
//  Created by blake on 11/17/26.
//
import Observation

@Observable
final class RefreshSignal {
    var version = 0
    func bump() { version += 1 }
}
