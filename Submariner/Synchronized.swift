//
//  Synchronized.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-06-20.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Foundation

// https://stackoverflow.com/a/61458763
@discardableResult
public func synchronized<T>(_ lock: AnyObject, closure:() -> T) -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }

    return closure()
}

@discardableResult
public func synchronized<T>(_ lock: AnyObject, closure:() throws -> T) throws -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }

    return try closure()
}
