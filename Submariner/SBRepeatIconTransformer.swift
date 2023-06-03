//
//  SBRepeatIconTransformer.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-10.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa

@objc(SBRepeatIconTransformer) class SBRepeatIconTransformer: ValueTransformer {
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
            case .one:
                return NSImage.init(systemSymbolName: "repeat.1", accessibilityDescription: "Repeat One")
            case .all:
                return NSImage.init(systemSymbolName: "repeat", accessibilityDescription: "Repeat All")
            @unknown default:
                return NSImage.init(systemSymbolName: "repeat", accessibilityDescription: "Repeat None")
            }
        }
        return nil
    }
}
