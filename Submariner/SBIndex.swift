//
//  SBIndex+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData

@objc(SBIndex)
public class SBIndex: SBMusicItem, SBStarrable {
    // implemented for SBArtist; stars are only relevant for artist, but the arrays are for SBIndex.
    // SBGroup has no need for starring (AFAIK?), so
    @objc var starredBool: Bool {
        get { false }
        set {}
    }
}
