//
//  SBMonospaceTextField.swift
//  Submariner
//
//  Created by Calvin Buckley on 2022-09-22.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc(SBMonospaceTextField)
class SBMonospaceTextField: NSTextField {
    var stringAttributes: Dictionary<NSAttributedString.Key, Any> = [:]
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // cache the NSFont. 11 is the alleged default, but 13 seems to match more
        let font = NSFont.monospacedDigitSystemFont(ofSize: self.font?.pointSize ?? 13, weight: NSFont.Weight.medium)
        stringAttributes = [ NSAttributedString.Key.font: font ]
        // XXX: try to get max width (-00:00), as we
        // but do reset the font value right now
        self.stringValue = self.stringValue
    }
    
    override var stringValue: String {
        get {
            return super.stringValue
        }
        set {
            // this seems expensive but we already make a new NSString in the callers
            let attributedString = NSAttributedString.init(string: newValue, attributes: stringAttributes)
            super.attributedStringValue = attributedString
        }
    }
}
