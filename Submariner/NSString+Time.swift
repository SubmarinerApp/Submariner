//
//  NSString+Time.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc extension NSString {
    static let iso8601Formatter = ISO8601DateFormatter()
    static let rfc3339DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    @objc func dateTimeFromISO() -> NSDate? {
        return NSString.iso8601Formatter.date(from: self as String) as NSDate?
    }
    
    @objc func dateTimeFromRFC3339() -> NSDate? {
        return NSString.rfc3339DateFormatter.date(from: self as String) as NSDate?
    }
    
    static let componentFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    @objc static func stringWith(time: TimeInterval) -> NSString? {
        if time == 0 || time.isNaN {
            return "0:00"
        }
        
        return componentFormatter.string(from: time) as NSString?
    }
}
