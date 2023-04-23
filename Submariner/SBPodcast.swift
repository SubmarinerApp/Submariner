//
//  SBPodcast+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData

@objc(SBPodcast)
public class SBPodcast: SBMusicItem {
    @objc func statusImage() -> NSImage {
        if channelStatus == "new" || channelStatus == "completed" {
            return NSImage(named: NSImage.statusAvailableName)!
        }
        if channelStatus == "error" || channelStatus == "deleted" {
            return NSImage(named: NSImage.statusUnavailableName)!
        }
        return NSImage(named: NSImage.statusPartiallyAvailableName)!
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBPodcast {
        let entity = NSEntityDescription.entity(forEntityName: "Podcast", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBPodcast
    }
}
