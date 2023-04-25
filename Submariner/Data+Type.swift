//
//  Data+Type.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers

extension Data {
    /// Useful for determining the type of an image from only bytes, such as from a tag.
    func guessImageType() -> UTType? {
        if let imgSrc = CGImageSourceCreateWithData(self as CFData, nil),
           let str = CGImageSourceGetType(imgSrc) {
            return UTType(str as String)
        }
        return nil
    }
}
