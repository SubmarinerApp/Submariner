//
//  SBLibraryItemPasteboardWriter.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-27.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

@objc class SBLibraryItemPasteboardWriter: NSObject, NSPasteboardWriting {
    let item: SBTrack
    let index: Int
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.libraryItem, .rowIndex]
    }
    
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == .libraryItem {
            return (item.objectID.uriRepresentation() as NSURL).pasteboardPropertyList(forType: .URL)
        } else if type == .rowIndex {
            return withUnsafeBytes(of: index) { Data($0) }
        }
        return nil
    }
    
    @objc init(item: SBTrack, index: Int) {
        self.item = item
        self.index = index
    }
}
