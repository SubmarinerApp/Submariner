//
//  SBSearchResult.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc class SBSearchResult: NSObject {
    enum QueryType {
        case search(query: String)
        case similarTo(artist: SBArtist)
        case topTracksFor(artistName: String)
    }
    
    var returnedTracks = 0
    
    /// Used for bindings and contains the actual tracks fetched from `fetchTracks:`.
    @objc var tracks: [SBTrack] = []
    let query: QueryType
    
    /// Contains the list of tracks to fetch on the main thread, and fills `tracks` from that.
    ///
    /// This can be appended to.
    var tracksToFetch: [NSManagedObjectID] = []
    
    /// Updates the tracks array after getting the results.
    ///
    /// This has to be done on the main thread, as the parse operation that builds the list runs off the main thread.
    func fetchTracks(managedObjectContext: NSManagedObjectContext) {
        tracks = tracksToFetch.map { trackID in
            managedObjectContext.object(with: trackID) as! SBTrack
        }
    }
    
    init(query: QueryType) {
        self.query = query
        super.init()
    }
}
