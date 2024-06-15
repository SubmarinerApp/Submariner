//
//  SBAlbum+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData

@objc(SBAlbum)
public class SBAlbum: SBMusicItem, SBStarrable {
    static let nullCover = NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: "No Album Art")
    
    override public func imageRepresentation() -> Any! {
        if let cover = self.cover, let path = cover.imagePath as String? {
            return NSImage.init(byReferencingFile: path)
        }
        return SBAlbum.nullCover;
    }
    
    @objc var starredBool: Bool {
        get {
            return starred != nil
        } set {
            // setting it locally is mostly for the sake of instant update - we should refresh the track later
            if starred != nil {
                starred = nil
                artist?.server?.unstar(tracks: [], albums: [self], artists: [])
            } else {
                starred = Date.now
                artist?.server?.star(tracks: [], albums: [self], artists: [])
            }
        }
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBAlbum {
        let entity = NSEntityDescription.entity(forEntityName: "Album", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBAlbum
    }
}
