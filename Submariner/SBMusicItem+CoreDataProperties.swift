//
//  SBMusicItem+CoreDataProperties.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData


extension SBMusicItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SBMusicItem> {
        return NSFetchRequest<SBMusicItem>(entityName: "MusicItem")
    }

    //@NSManaged public var path: String?
    @NSManaged public var id: String?
    @NSManaged public var isLocal: NSNumber?
    @NSManaged public var itemName: String?
    @NSManaged public var isLinked: NSNumber?

}

extension SBMusicItem : Identifiable {

}
