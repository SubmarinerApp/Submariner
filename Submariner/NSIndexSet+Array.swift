//
//  IndexSet+Array.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-07-25.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Foundation

@objc extension NSIndexSet {
    @objc func toArray() -> [Int] {
        return Array(self)
    }
}
