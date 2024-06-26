//
//  SBMusicItem+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData

@objc(SBMusicItem)
public class SBMusicItem: NSManagedObject {
    // Cover overrides imagePath, but this applies to Track/Episode/Artist/Album,
    // which exist when they're a local item. Make relative, but unlike Cover, don't
    // move, since we might not be the owners of it. (It does make the "user moved
    // the path" case more annoying though, but local items can always be destroyed
    // and recreated easily.
    @objc var path: String? {
        get {
            // FIXME: Refactor this to make sense for direct URL use
            let libraryDir = SBAppDelegate.musicDirectory.path
            self.willAccessValue(forKey: "path")
            var ret: String? = self.primitiveValue(forKey: "path") as! String?
            if let primitivePath = ret,
               self.isLocal?.boolValue == true {
                if primitivePath.hasPrefix("/") {
                    // If absolute path is in music dir, correct it.
                    if primitivePath.hasPrefix(libraryDir) {
                        let offset = libraryDir.lengthOfBytes(using: .utf8) + (libraryDir.hasSuffix("/") ? 0 : 1)
                        let offsetIndex = String.Index(utf16Offset: offset, in: primitivePath)
                        let trimmedPrefix = String(primitivePath[offsetIndex...])
                        self.path = trimmedPrefix
                        ret = trimmedPrefix
                    }
                } else {
                    // relative
                    ret = libraryDir + "/" + primitivePath
                }
            }
            self.didAccessValue(forKey: "path")
            return ret as String?
        }
        set {
            self.willChangeValue(forKey: "path")
            self.setPrimitiveValue(newValue, forKey: "path")
            self.didChangeValue(forKey: "path")
        }
    }
}
