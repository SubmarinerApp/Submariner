//
//  SBRepeatModeButtonStateTransformer.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-05-02.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa

@objc(SBRepeatModeButtonStateTransformer) class SBRepeatModeButtonStateTransformer: ValueTransformer {
    override class func allowsReverseTransformation() -> Bool {
        true
    }
    
    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }
    
    func toButtonState(_ value: SBPlayer.RepeatMode) -> NSNumber {
        switch (value) {
        case .no:
            return NSNumber.init(integerLiteral: NSButton.StateValue.off.rawValue)
        case .one:
            return NSNumber.init(integerLiteral: NSButton.StateValue.on.rawValue)
        default: // .all
            return NSNumber.init(integerLiteral: NSButton.StateValue.mixed.rawValue)
        }
    }
    
    func toRepeatMode(_ value: NSButton.StateValue) -> NSNumber {
        switch (value) {
        case .off:
            return NSNumber.init(integerLiteral: SBPlayer.RepeatMode.no.rawValue)
        case .on:
            return NSNumber.init(integerLiteral: SBPlayer.RepeatMode.one.rawValue)
        default: // -1 / .mixed
            return NSNumber.init(integerLiteral: SBPlayer.RepeatMode.all.rawValue)
        }
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        if let value = value as? Int, let asEnum = SBPlayer.RepeatMode(rawValue: value) {
            return toButtonState(asEnum)
        }
        return nil
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        if let modeRaw = value as? Int {
            let asEnum = NSButton.StateValue(rawValue: modeRaw)
            return toRepeatMode(asEnum)
        }
        return nil
    }
}
