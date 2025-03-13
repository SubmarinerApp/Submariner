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
    @NSManaged public var itemId: String?
    @NSManaged public var isLocal: NSNumber?
    @NSManaged public var itemName: String?
    @NSManaged public var isLinked: NSNumber?
    @NSManaged public var sortName: String?
    @NSManaged public var musicBrainzId: String?

}

extension SBMusicItem : Identifiable {

}
