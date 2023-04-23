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
public class SBAlbum: SBMusicItem {
    // #MARK: - IKImageBrowserView
    
    static let nullCover = NSImage(named: "NoArtwork")
    
    override public func imageTitle() -> String? {
        return itemName // XXX: willAccessValueForKey?
    }
    
    override public func imageUID() -> String? {
        return itemName // XXX: willAccessValueForKey?
    }
    
    override public func imageRepresentationType() -> String! {
        // XXX: Can't use IKImageBrowserPathRepresentationType because [SBTrack coverImage] calls imageRepresentation.
        return IKImageBrowserNSImageRepresentationType
    }
    
    override public func imageRepresentation() -> Any! {
        if let cover = self.cover, let path = cover.imagePath {
            return NSImage.init(byReferencingFile: path as String)
        }
        return SBAlbum.nullCover;
    }
    
    override public func imageVersion() -> Int {
        // Avoid constructing an image. I think this is only really used to check if it's loaded,
        // since the album artwork shouldn't change normally (and if it does, rare it'll be the same size).
        // XXX: Better method.
        if let cover = self.cover,
           let path = cover.path,
           let attribs = try? FileManager.default.attributesOfItem(atPath: path) {
            return attribs[FileAttributeKey.size] as! Int
        }
        return 0
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBAlbum {
        let entity = NSEntityDescription.entity(forEntityName: "Album", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBAlbum
    }
}
