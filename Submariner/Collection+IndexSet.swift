//
//  Collection+IndexSet.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-01-01.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Foundation

extension Collection where Index == IndexSet.Element {
    subscript(_ indexSet: IndexSet) -> [Self.Element] {
        indexSet.map { index in
            self[index]
        }
    }
}
