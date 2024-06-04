//
//  SBPlaylistMigrationPolicy.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-06-01.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Foundation
import CoreData

@objc(SBPlaylistV8MigrationPolicy) class SBPlaylistV8MigrationPolicy: NSEntityMigrationPolicy {
    var manager: NSMigrationManager!
    
    private func playlistIndex(for track: NSManagedObject) -> Int {
        return (track.primitiveValue(forKey: "playlistIndex") as? NSNumber)?.intValue ?? 0
    }
    
    private func tracksFromTrackSet(_ tracks: Set<NSManagedObject>) -> [NSManagedObject] {
        return tracks.sorted { lhs, rhs in
            return playlistIndex(for: lhs) < playlistIndex(for: rhs)
        }.map { return $0 }
    }
    
    // HACK: Migration between stores will break object URIs; they are not stable with a heavyweight migration.
    // We need to take the source instances, get their equivalent in the destination store, and store those URIs instead.
    private func destinationURIsFromSourceObjects(_ objects: [NSManagedObject]) -> [URL] {
        // TrackToTrack defined in MigrateV7ToV8
        return manager.destinationInstances(forEntityMappingName: "TrackToTrack", sourceInstances: objects).map { $0.objectID.uriRepresentation() }
    }
    
    @objc(entriesFromTracks:) func entriesFrom(tracks: NSSet?) -> [URL] {
        // this must be an NSManagedObject, so we'll have to access it via primitiveValue et al
        if let oldTracks = tracks as? Set<NSManagedObject> {
            return destinationURIsFromSourceObjects(tracksFromTrackSet(oldTracks))
        }
        return []
    }
    
    // we need this to save the Manager
    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        self.manager = manager
        try super.begin(mapping, with: manager)
    }
}
