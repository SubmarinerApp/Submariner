//
//  SBCollectionViewFlowLayout.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-12.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

@objc(SBCollectionViewFlowLayout) class SBCollectionViewFlowLayout: NSCollectionViewFlowLayout {
    private func updateZoomLevel(_ zoomLevel: Double) {
        // TODO: Save the original value somewhere and use that instead of hardcoding
        itemSize = NSSize(width: 250.0 * zoomLevel, height: 225.0 * zoomLevel)
    }
    
    private var zoomObservation: NSKeyValueObservation?
    
    private func commonInit() {
        zoomObservation = UserDefaults.standard.observe(\.coverSize, options: [.initial, .new]) { defaults, change in
            if let zoomLevel = change.newValue {
                self.updateZoomLevel(zoomLevel.doubleValue)
            }
        }
    }
    
    override init() {
        super.init()
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
}
