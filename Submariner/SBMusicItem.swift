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
            self.willAccessValue(forKey: "path")
            var ret: NSString? = self.primitiveValue(forKey: "path") as! NSString?
            if let primitivePath = ret,
               let libraryDir = SBAppDelegate.sharedInstance().musicDirectory() as NSString?,
               self.isLocal?.boolValue == true {
                if primitivePath.isAbsolutePath {
                    // If absolute path is in music dir, correct it.
                    if primitivePath.hasPrefix(libraryDir as String) {
                        let offset = libraryDir.length + (libraryDir.hasSuffix("/") ? 0 : 1)
                        let trimmedPrefix = primitivePath.substring(from: offset)
                        self.path = trimmedPrefix
                        ret = trimmedPrefix as NSString?
                    }
                } else {
                    // relative
                    ret = libraryDir.appendingPathComponent(primitivePath as String) as NSString?
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
    /*
     
     [self willAccessValueForKey:@"path"];
     NSString *string = [self primitivePath];
     if (self.isLocalValue && string && [string isAbsolutePath]) {
         // If absolute path is in music dir, correct it.
         NSString *libraryDir = [[SBAppDelegate sharedInstance] musicDirectory];
         if ([string hasPrefix: libraryDir]) {
             NSUInteger offset = [libraryDir length] + ([libraryDir hasSuffix: @"/"] ? 0 : 1);
             NSString *trimmedPrefix = [string substringFromIndex: offset];
             [self setPrimitivePath: trimmedPrefix];
         }
     } else if (self.isLocalValue && string) {
         // Relative, but return the full directory.
         NSString *libraryDir = [[SBAppDelegate sharedInstance] musicDirectory];
         string = [libraryDir stringByAppendingPathComponent: string];
     }
     [self didAccessValueForKey:@"path"];
     return string;
     */
}
