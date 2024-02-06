//
//  SBDirectory.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-05.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Foundation
import CoreData

@objc(SBDirectory)
public class SBDirectory: SBMusicItem {
    // #MARK: - Children wrapper
    
    override public class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "children" {
            return Set(["subdirectories", "tracks"])
        } else if key == "tracks" {
            return Set(["subdirectories", "children"])
        } else if key == "subdirectories" {
            return Set(["children", "tracks"])
        }
        return super.keyPathsForValuesAffectingValue(forKey: key)
    }
    
    // FIXME: keyPathsForValuesAffectingValue
    @objc dynamic var children: [SBMusicItem] {
        let directories = Array(self.subdirectories as? Set<SBDirectory> ?? Set())
            .sorted {
                let lhs = $0.itemName ?? ""
                let rhs = $1.itemName ?? ""
                return lhs.localizedCompare(rhs) == .orderedAscending
            } as [SBMusicItem]
        let tracks = Array(self.tracks as? Set<SBTrack> ?? Set())
            .sorted {
                let lhs = $0.path ?? ""
                let rhs = $1.path ?? ""
                return lhs.localizedCompare(rhs) == .orderedAscending
            } as [SBMusicItem]
        return directories + tracks
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBDirectory {
        let entity = NSEntityDescription.entity(forEntityName: "Directory", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBDirectory
    }
}
