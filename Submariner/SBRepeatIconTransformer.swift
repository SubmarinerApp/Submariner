//
//  SBRepeatIconTransformer.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-10.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa

@objcMembers class SBRepeatIconTransformer: ValueTransformer {
    override class func allowsReverseTransformation() -> Bool {
        false
    }
    
    override class func transformedValueClass() -> AnyClass {
        return NSImage.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        // value is NSNumber-based enum
        if let modeRaw = value as? Int, let mode = SBPlayerRepeatMode(rawValue: modeRaw) {
            switch (mode) {
            case .no:
                return NSImage.init(systemSymbolName: "repeat.circle", accessibilityDescription: "Repeat None")
            case .one:
                return NSImage.init(systemSymbolName: "repeat.1.circle.fill", accessibilityDescription: "Repeat One")
            case .all:
                return NSImage.init(systemSymbolName: "repeat.circle.fill", accessibilityDescription: "Repeat All")
            @unknown default:
                fatalError()
            }
        }
        return nil
    }
}
