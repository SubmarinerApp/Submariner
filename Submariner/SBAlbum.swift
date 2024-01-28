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
    
    // HACK: because IKImageBrowserView gets the smallest size by default. unneeded in the future?
    static let nullCover = {
        // 600 -> max size in image browser view for now
        let config = NSImage.SymbolConfiguration(pointSize: 600, weight: .regular)
        let image = NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: "No Album Art")
        return image!.withSymbolConfiguration(config)
    }()
    
    override public func imageTitle() -> String? {
        return itemName
    }
    
    override public func imageUID() -> String? {
        return itemName
    }
    
    override public func imageRepresentationType() -> String! {
        // XXX: Can't use IKImageBrowserPathRepresentationType because [SBTrack coverImage] calls imageRepresentation.
        return IKImageBrowserNSImageRepresentationType
    }
    
    override public func imageRepresentation() -> Any! {
        if let cover = self.cover, let path = cover.imagePath as String? {
            return NSImage.init(byReferencingFile: path)
        }
        return SBAlbum.nullCover;
    }
    
    override public func imageVersion() -> Int {
        // Avoid constructing an image. I think this is only really used to check if it's loaded,
        // since the album artwork shouldn't change normally (and if it does, rare it'll be the same size).
        // XXX: Better method.
        if let cover = self.cover,
           let path = cover.imagePath as String?,
           let attribs = try? FileManager.default.attributesOfItem(atPath: path) {
            return attribs[FileAttributeKey.size] as! Int
        }
        return 0
    }
    
    // #MARK: - Derived Attributes
    
    // XXX: This is better off living in Core Data, but adding a derived attribute
    // (once you get past the other issues) causes loading the new model version
    // to fail with "Cannot migrate store in-place".
    //
    // Because of this, it seems a little janky (the old order might be kept, might
    // need to click albums to refresh the sorting properly?)
    @objc dynamic var year: NSNumber? {
        (self.tracks as? Set<SBTrack>)?.first?.year
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBAlbum {
        let entity = NSEntityDescription.entity(forEntityName: "Album", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBAlbum
    }
}
