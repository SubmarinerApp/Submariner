//
//  SBVolumeIconTransformer.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-10.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa

@objc(SBVolumeIconTransformer) class SBVolumeIconTransformer: ValueTransformer {
    override class func allowsReverseTransformation() -> Bool {
        false
    }
    
    override class func transformedValueClass() -> AnyClass {
        return NSImage.self
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        // value is NSNumber
        if let volume = value as? Double {
            if (volume == 0) {
                return NSImage.init(systemSymbolName: "speaker.slash", accessibilityDescription: "Muted")
            }
            
            // XXX: Percentage format?
            let description = String.init(format: "%f", volume)
            if #available(macOS 13.0.0, *) {
                return NSImage.init(systemSymbolName: "speaker.wave.3", variableValue: volume, accessibilityDescription: description)
            }
            
            var name = ""
            if (volume >= 0.66) {
                name = "speaker.wave.3";
            } else if (volume >= 0.33) {
                name = "speaker.wave.2";
            } else {
                name = "speaker.wave.1";
            }
            return NSImage.init(systemSymbolName: name, accessibilityDescription: description)
        }
        return nil
    }
}
