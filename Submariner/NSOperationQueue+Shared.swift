//
//  NSOperationQueue+Shared.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-21.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Foundation

@objc extension OperationQueue {
    // Note that in Swift, static variables are implicitly lazy
    @objc static var sharedServerQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    @objc static var sharedDownloadQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}
