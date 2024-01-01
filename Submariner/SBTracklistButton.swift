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
    var dragLingerTimer: Timer?
    
    @objc weak var databaseController: SBDatabaseController!

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // only triggered if we get a library item
        dragLingerTimer = Timer(timeInterval: 1, repeats: false, block: { timer in
            if (self.databaseController.isTracklistShown != true) {
                self.databaseController.toggleTrackList(self)
            }
            timer.invalidate()
        })
        // we need common runloop mode, NOT the event tracking one, or dragging blocks the timer
        RunLoop.main.add(dragLingerTimer!, forMode: .common)
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        dragLingerTimer?.invalidate()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer {
            dragLingerTimer?.invalidate()
        }
        do {
            if let moc = databaseController.managedObjectContext,
               let data = sender.draggingPasteboard.data(forType: .libraryType),
               let tracks = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: data) as? [URL] {
                let deserialized = tracks.map { url in
                    // this should always give us a valid object ID,
                    // since we sourced good URLs from drag source
                    let objID = moc.persistentStoreCoordinator!.managedObjectID(forURIRepresentation: url)!
                    return moc.object(with: objID) as! SBTrack
                }
                // then add them
                SBPlayer.sharedInstance().add(tracks: deserialized, replace: false)
                return true
            }
        } catch { }
        return false
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // it doesn't make sense to register SBTracklistTableViewDataType,
        // since that assumes the tracklist is already open
        registerForDraggedTypes([.libraryType])
    }
}
