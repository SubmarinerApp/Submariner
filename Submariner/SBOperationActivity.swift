//
//  SBOperationActivity.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc class SBOperationActivity: NSObject {
    @objc var operationName = ""
    @objc var operationInfo = ""
    
    // TODO: Convert to non-ObjC int/float types
    @objc var operationPercent = NSNumber(value: 0)
    @objc var operationCurrent = NSNumber(value: 0)
    @objc var operationTotal = NSNumber(value: 0)
    
    @objc var indeterminated = false
}
