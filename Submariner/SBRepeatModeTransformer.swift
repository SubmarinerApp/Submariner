//
//  SBRepeatModeTransformer.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-10.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa

@objcMembers class SBRepeatModeTransformer: ValueTransformer {
    let newMode: SBPlayerRepeatMode
    
    init(mode: SBPlayerRepeatMode) {
        self.newMode = mode
        super.init()
    }
    
    override class func allowsReverseTransformation() -> Bool {
        true
    }
    
    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        if let modeRaw = value as? Int, let passedMode = SBPlayerRepeatMode(rawValue: modeRaw) {
            return self.newMode == passedMode
        }
        return nil
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        if let enabled = value as? Bool {
            let ret = enabled ? newMode : .no
            return NSNumber.init(integerLiteral: ret.rawValue)
        }
        return nil
    }
}
