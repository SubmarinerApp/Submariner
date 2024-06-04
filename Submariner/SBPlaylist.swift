//
//  SBPlaylist+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData

@objc(SBPlaylist)
public class SBPlaylist: SBResource {
    @objc var resources = NSSet()
    
    // #MARK: - Core Data NSSet backwards compatibility
    
    override public class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "tracks" {
            return Set(["trackIDs"])
        } else if key == "trackIDs" {
            return Set(["tracks"])
        }
        return super.keyPathsForValuesAffectingValue(forKey: key)
    }
    
    @objc dynamic var tracks: [SBTrack]? {
        get {
            // If tracks get deleted, compactMap means we can skip over them if they turn out to not exist anymore, without complicated schemes
            return trackIDs?.compactMap {
                if let moc = self.managedObjectContext,
                   let oid = moc.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: $0) {
                    return moc.object(with: oid) as? SBTrack
                }
                return nil
            }
        }
        set {
            if let tracks = newValue {
                self.trackIDs = tracks.map { $0.objectID.uriRepresentation() }
            }
        }
    }
    
    func add(track: SBTrack) {
        trackIDs?.append(track.objectID.uriRepresentation())
    }
    
    @objc(addTracks:) func add(tracks: [SBTrack]) {
        let additionalIDs = tracks.map { $0.objectID.uriRepresentation() }
        trackIDs?.append(contentsOf: additionalIDs)
    }
    
    @objc(removeTracksObject:) func remove(track: SBTrack) {
        trackIDs?.removeAll(where: { (id: URL) in
            id == track.objectID.uriRepresentation()
        })
    }
    
    func remove(indices: IndexSet) {
        trackIDs?.remove(atOffsets: indices)
    }
    
    @objc(moveIndices:toRow:) func moveTracks(fromOffsets indices: IndexSet, toOffset row: Int) {
        trackIDs?.move(fromOffsets: indices, toOffset: row)
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBPlaylist {
        let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBPlaylist
    }
}
