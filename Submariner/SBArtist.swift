//
//  SBArtist+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData

@objc(SBArtist)
public class SBArtist: SBIndex {
    
    @objc override var starredBool: Bool {
        get {
            return starred != nil
        } set {
            // setting it locally is mostly for the sake of instant update - we should refresh the track later
            if starred != nil {
                starred = nil
                server?.unstar(tracks: [], albums: [], artists: [self])
            } else {
                starred = Date.now
                server?.star(tracks: [], albums: [], artists: [self])
            }
        }
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBArtist {
        let entity = NSEntityDescription.entity(forEntityName: "Artist", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBArtist
    }
}
