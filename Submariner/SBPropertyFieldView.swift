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
            if let string = stringMaybeSingular, !string.isEmpty {
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
    
    @ViewBuilder func ratingField(label: String, for property: KeyPath<Item, NSNumber?>, setter: @escaping (Int) -> Void) -> some View {
        if #available(macOS 13, *) {
            LabeledContent {
                let rating = valueIfSame(property: property)??.intValue ?? 0
                SBRatingView(rating: rating, setter: setter)
                    .border(.red)
                    .fixedSize()
            } label: {
                Text(label)
            }
        } else {
            numberField(label: label, for: property)
        }
    }
    
    @ViewBuilder func dateField(label: String, for property: KeyPath<Item, Date?>, formatter: Formatter? = nil) -> some View {
        if let dateMaybeSingular = valueIfSame(property: property) {
            if let date = dateMaybeSingular {
                if let formatter = formatter, let string = formatter.string(for: date) {
                    field(label: label, string: string)
                } else {
                    field(label: label, string: date.formatted())
                }
            }
            // no thing -> nothing
        } else {
            field(label: label, string: "...")
        }
    }
}
