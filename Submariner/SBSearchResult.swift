//
//  SBSearchResult.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc class SBSearchResult: NSObject {
    @objc var tracks: [SBTrack] = []
    @objc let query: String // NSString
    
    // FIXME: Nasty hack for SBServerSearchController since the tracks were sourced from a different thread
    // it should be an array of IDs and the UI thread fetches that
    @objc func replaceManagedInstancesForThread(managedObjectContext: NSManagedObjectContext) {
        tracks = tracks.map { track in
            managedObjectContext.object(with: track.objectID) as! SBTrack
        }
    }
    
    @objc(initWithQuery:) init(query: String) {
        self.query = query
        super.init()
    }
}
