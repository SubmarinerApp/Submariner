//
//  NSImage+Additions.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc extension NSImage {
    @objc func imageTintedWith(color: NSColor) -> NSImage {
        guard let copiedImage = self.copy() as? NSImage? else {
            return self
        }
        let bounds = CGRect(origin: .zero, size: self.size)
        let context = NSGraphicsContext.current!
        context.saveGraphicsState()
        defer {
            context.restoreGraphicsState()
        }
        // TODO: This is deprecated in macOS 13, convert to imageWithSize:flipped:drawingHandler:
        copiedImage?.lockFocus()
        color.set()
        bounds.fill(using: .sourceAtop)
        copiedImage?.unlockFocus()
        return copiedImage!
    }
}
