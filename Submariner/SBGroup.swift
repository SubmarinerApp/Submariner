//
//  SBGroup+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData

@objc(SBGroup)
public class SBGroup: SBIndex {
    // XXX: KVO bindings likely in the library controllers want this, presumably in case
    @objc dynamic var albums: NSSet {
        return NSSet()
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBGroup {
        let entity = NSEntityDescription.entity(forEntityName: "Group", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBGroup
    }
}
