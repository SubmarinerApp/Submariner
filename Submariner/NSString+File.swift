//
//  NSString+File.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers

@objc extension NSString {
    @objc func extensionForMIMEType() -> NSString? {
        return UTType(mimeType: self as String)?.preferredFilenameExtension as NSString?
    }
    
    static let illegalFilenameCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")
    
    @objc func isValidFileName() -> Bool {
        guard !self.isEqual(to: "") else {
            return false
        }
        
        let range = self.rangeOfCharacter(from: NSString.illegalFilenameCharacters)
        return range.location == NSNotFound
    }
}
