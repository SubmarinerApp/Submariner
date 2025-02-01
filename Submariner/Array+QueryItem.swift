//
//  Array+QueryItem.swift
//  Submariner
//
//  Created by Calvin Buckley on 2025-01-30.
//
//  Copyright (c) 2025 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Foundation

extension Array where Element == URLQueryItem {
    // Dictionaries aren't the right fit because the API takes multiple items of same name for an array
    // But it does mean that mapping it to a dictionary type access isn't ideal
    // As such, first element wins for gets, and append for inserts
    subscript(_ key: String) -> String? {
        get {
            self.first { $0.name == key }?.value
        }
        set {
            self.append(URLQueryItem(name: key, value: newValue))
        }
    }
}
