//
//  SBPropertyFieldView.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-04-08.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import SwiftUI

/// Provides a way to easily make form entries for key paths on an item.
protocol SBPropertyFieldView: View {
    associatedtype Item
    
    var items: [Item] { get }
}

extension SBPropertyFieldView {
    func valueIfSame<T: Hashable>(property: KeyPath<Item, T>) -> T? {
        // one or none
        if items.count == 1 {
            return items[0][keyPath: property]
        } else if items.count == 0 {
            return nil
        }
        // if multiple
        let values = Set(items.map { $0[keyPath: property] })
        if values.count > 1 {
            return nil // too many
        } else {
            return items[0][keyPath: property]
        }
    }
    
    @ViewBuilder func field(label: String, string: String) -> some View {
        if #available(macOS 13, *) {
            LabeledContent {
                Text(string)
                    .textSelection(.enabled)
            } label: {
                Text(label)
            }
        } else {
            TextField(label, text: .constant(string))
        }
    }
    
    @ViewBuilder func stringField(label: String, for property: KeyPath<Item, String?>) -> some View {
        if let stringMaybeSingular = valueIfSame(property: property) {
            if let string = stringMaybeSingular {
                field(label: label, string: string)
            }
            // no thing -> nothing
        } else {
            field(label: label, string: "...")
        }
    }
    
    @ViewBuilder func numberField(label: String, for property: KeyPath<Item, NSNumber?>, formatter: Formatter? = nil) -> some View {
        if let numberMaybeSingular = valueIfSame(property: property) {
            if let number = numberMaybeSingular, number != 0 {
                if let formatter = formatter, let string = formatter.string(for: number) {
                    field(label: label, string: string)
                } else {
                    field(label: label, string: number.stringValue)
                }
            }
            // no thing -> nothing
        } else {
            field(label: label, string: "...")
        }
    }
}
