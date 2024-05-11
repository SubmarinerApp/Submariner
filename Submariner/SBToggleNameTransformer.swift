//
//  SBToggleNameTransformer.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-05-11.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

@objc(SBToggleNameTransformer) class SBToggleNameTransformer: ValueTransformer {
    let name: String
    
    init(name: String) {
        self.name = name
        super.init()
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return false
    }
    
    override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        if let valueNumber = value as? NSNumber?, valueNumber == true {
            return "Hide \(name)"
        } else {
            return "Show \(name)"
        }
    }
}
