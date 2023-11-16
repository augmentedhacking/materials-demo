//
//  ViewModel.swift
//  MaterialsDemo
//
//  Created by Nien Lam on 11/1/23.
//  Copyright © 2023 Line Break, LLC. All rights reserved.
//

import Foundation
import Combine

// MARK: - View model for handling communication between the UI and ARView.

@MainActor
class ViewModel: ObservableObject {
    // For locking position.
    @Published var positionIsLocked = false
    
    // For turning on/off entities.
    @Published var directionalLightEnabled = true
    @Published var sphereEnabled           = false
    @Published var boardEnabled            = false
    @Published var chairEnabled            = true
    
    // For filters. Idx of 0 turns off filters.
    @Published var filtersIdx = 0
}
