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
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBPlaylist {
        let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBPlaylist
    }
}
