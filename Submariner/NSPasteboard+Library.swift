//
//  NSPasteboard+Library.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-27.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

// Mostly because SBDatabaseController, SBTracklistButton, and SBTracklistController basically all reimplemented this
extension NSPasteboard {
    @objc func libraryItems() -> [URL]? {
        guard let types = self.types, let pasteboardItems = pasteboardItems else {
            return nil
        }
        
        // the two types are explained in depth in PasteboardTypes+Submariner
        if types.contains(.libraryItem) {
            // there are multiple of these on a pasteboard containing a String (which is a URI for Core Data)
            return pasteboardItems.compactMap { item in
                let string = item.string(forType: .libraryItem)!
                return URL(string: string)
            }
        } else if types.contains(.libraryItems), let data = self.data(forType: .libraryItems) {
            // there is a single one of these (for now?) containing a [URL]
            return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: data) as? [URL]
        }
        return nil
    }
    
    // returns tracks for now, could return other music items?
    @objc func libraryItems(managedObjectContext moc: NSManagedObjectContext) -> [SBTrack]? {
        guard let urls = self.libraryItems() else {
            return nil
        }
        return urls.map { url in
            // these URLs should always be valid as drag source OID should be
            let objID = moc.persistentStoreCoordinator!.managedObjectID(forURIRepresentation: url)!
            return moc.object(with: objID) as! SBTrack
        }
    }
    
    @objc func rowIndices() -> IndexSet {
        guard let types = self.types, let pasteboardItems = pasteboardItems else {
            return IndexSet()
        }
        
        if types.contains(.rowIndex) {
            let indices = pasteboardItems.compactMap { item in
                let data = item.data(forType: .rowIndex)!
                // this is pretty gross
                return data.withUnsafeBytes { ptr in
                    ptr.load(as: Int.self)
                }
            }
            return IndexSet(indices)
        }
        return IndexSet()
    }
}
