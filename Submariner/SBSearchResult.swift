//
//  SBSearchResult.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc class SBSearchResult: NSObject {
    /// Used for bindings and contains the actual tracks fetched from `fetchTracks:`.
    @objc var tracks: [SBTrack] = []
    @objc let query: String // NSString
    
    /// Contains the list of tracks to fetch on the main thread, and fills `tracks` from that.
    ///
    /// This can be appended to.
    var tracksToFetch: [NSManagedObjectID] = []
    
    /// Updates the tracks array after getting the results.
    ///
    /// This has to be done on the main thread, as the parse operation that builds the list runs off the main thread.
    @objc func fetchTracks(managedObjectContext: NSManagedObjectContext) {
        tracks = tracksToFetch.map { trackID in
            managedObjectContext.object(with: trackID) as! SBTrack
        }
    }
    
    @objc(initWithQuery:) init(query: String) {
        self.query = query
        super.init()
    }
}
