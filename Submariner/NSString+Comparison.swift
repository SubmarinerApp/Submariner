//
//  NSString+Comparison.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-05-14.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Foundation

extension NSString {
    private func isUnknownValue(_ string: String) -> Bool {
        return string.starts(with: "[Unknown") && string.last == "]"
    }
    
    @objc func artistListCompare(_ rhs: String) -> ComparisonResult {
        let lhs = self as String
        // Our goal with this is to kick the special unknown values to the bottom.
        // For example in Navidrome, there is the [Unknown] index group as well as
        // [Unknown Artist] and [Unknown Album]. The default sorting behaviours from
        // Foundation are unpleasant and put the group after the artist, or put them
        // in the middle of the list.
        // This is Navidrome specific unfortunately.
        // In the future other comparison changes could be made.
        let lhsUnknown = isUnknownValue(lhs)
        let rhsUnknown = isUnknownValue(rhs)
        if lhsUnknown && !rhsUnknown {
            return .orderedDescending
        } else if !lhsUnknown && rhsUnknown {
            return .orderedAscending
        } else if lhsUnknown && rhsUnknown {
            // we won't see special items of the same length
            return lhs.count < rhs.count ? .orderedAscending : .orderedDescending
        }
        
        return self.caseInsensitiveCompare(rhs)
    }
}
