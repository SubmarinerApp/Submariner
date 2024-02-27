//
//  SBLibraryPasteboardWriter.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-26.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

// This class only works because we use it for album views, which only support a single selection,
// and represent multiple tracks. For the track table views, use SBLibraryItemPasteboardWriter.
@objc class SBLibraryPasteboardWriter: NSObject, NSPasteboardWriting {
    var items: [SBTrack]
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.libraryItems]
    }
    
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        guard type == .libraryItems else {
            return nil
        }
        let uris = items.map { $0.objectID.uriRepresentation() }
        // We can't put NSURLs into what can be represented in a plist, so just send data,
        // as the other end will unarchive like always
        return try? NSKeyedArchiver.archivedData(withRootObject: uris, requiringSecureCoding: true)
    }
    
    @objc init(items: [SBTrack]) {
        self.items = items
    }
}
