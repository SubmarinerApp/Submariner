//
//  SBTracklistButton.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

/// Acts as a drop target for library items, so they can be added to the tracklist.
@objc class SBTracklistButton: NSButton {
    static let libraryType = NSPasteboard.PasteboardType.init(rawValue: "SBLibraryTableViewDataType")
    
    // we need this to be able to convert from URIs to actual objects
    // we could get say the DatabaseController to hold the MOC for us, but this is fine I guess
    @objc var managedObjectContext: NSManagedObjectContext? = nil

    @objc override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // only triggered if we get a library item
        return .copy
    }
    
    @objc override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        do {
            if let moc = managedObjectContext,
               let data = sender.draggingPasteboard.data(forType: SBTracklistButton.libraryType),
               let tracks = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: data) as? [URL] {
                // deserialize them
                let deserialized = tracks.map { url in
                    // this should always give us a valid object ID,
                    // since we sourced good URLs from drag source
                    let objID = (moc.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url))! as NSManagedObjectID
                    return moc.object(with: objID) as! SBTrack
                }
                // then add them
                SBPlayer.sharedInstance().add(tracks: deserialized, replace: false)
                return true
            }
        } catch { }
        return false
    }
    
    @objc override func awakeFromNib() {
        super.awakeFromNib()
        
        // it doesn't make sense to register SBTracklistTableViewDataType,
        // since that assumes the tracklist is already open
        registerForDraggedTypes([SBTracklistButton.libraryType])
    }
    
    // XXX: Consider, do we show the tracklist if we're being dropped onto?
    // Does that make sense? Would it then make sense to still be a target?
}
