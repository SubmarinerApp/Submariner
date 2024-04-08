//
//  Binding+Nil.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-04-08.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import SwiftUI

// https://alanquatermain.me/programming/swiftui/2019-11-15-CoreData-and-bindings/
extension Binding {
    init(_ source: Binding<Value?>, replacingNilWith nilValue: Value) where Value: Equatable {
        self.init(
            get: { source.wrappedValue ?? nilValue },
            set: { newValue in
                if newValue == nilValue {
                    source.wrappedValue = nil
                }
                else {
                    source.wrappedValue = newValue
                }
        })
    }
}
