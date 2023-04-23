//
//  SBCover+CoreDataProperties.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData


extension SBCover {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SBCover> {
        return NSFetchRequest<SBCover>(entityName: "Cover")
    }

    //@NSManaged public var imagePath: String?
    @NSManaged public var album: SBAlbum?
    @NSManaged public var track: SBTrack?

}
