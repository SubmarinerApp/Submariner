//
//  NSData+Type.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc extension NSData {
    /// Useful for determining the type of an image from only bytes, such as from a tag.
    @objc func guessImageUTI() -> NSString? {
        if let imgSrc = CGImageSourceCreateWithData(self, nil),
           let str = CGImageSourceGetType(imgSrc) {
            return str
        }
        return nil
    }
}
