//
//  SBRatingView.swift
//  Submariner
//
//  Created by Calvin Buckley on 2025-03-13.
//
//  Copyright (c) 2025 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa
import SwiftUI

struct SBRatingView: NSViewRepresentable {
    typealias NSViewType = NSLevelIndicator
    
    // XXX: Binding?
    var rating: Int
    var setter: (Int) -> Void
    
    func makeNSView(context: Context) -> NSLevelIndicator {
        let levelIndicator = NSLevelIndicator(frame: .zero)
        levelIndicator.levelIndicatorStyle = .rating
        levelIndicator.isEditable = true
        levelIndicator.target = context.coordinator
        levelIndicator.action = #selector(Coordinator.action(_:))
        return levelIndicator
    }
    
    func updateNSView(_ nsView: NSLevelIndicator, context: Context) {
        context.coordinator.parent = self
        nsView.integerValue = rating
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        var parent: SBRatingView
        
        init(parent: SBRatingView) {
            self.parent = parent
        }
        
        @objc func action(_ sender: NSLevelIndicator) {
            parent.setter(sender.integerValue)
        }
    }
}
