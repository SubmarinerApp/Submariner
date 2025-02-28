//
//  SBCover+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBCover")

@objc(SBCover)
public class SBCover: SBMusicItem {
    // We don't have a relationship directly with SBServer, but we can ask our relatives
    var server: SBServer? {
        if let album = self.album, let artist = album.artist {
            return artist.server
        } else if let track = self.track {
            return track.server
        }
        return nil
    }
    
    // utility funcs for coversDir
    private func trackIsLocal(_ track: SBTrack?) -> Bool {
        if let track = track {
            return track.isLocal?.boolValue == true && track.server == nil
        }
        return false
    }
    
    private func albumIsLocal(_ album: SBAlbum?) -> Bool {
        if let album = album, let albumArtist = album.artist {
            return album.isLocal?.boolValue == true && albumArtist.server == nil
        }
        return false
    }
    
    func coversDir(_ coverDir: NSString) -> NSString? {
        var append: String? = nil
        if let server = self.server {
            append = server.resourceName
        } else if self.isLocal?.boolValue == true ||
                    trackIsLocal(self.track) || albumIsLocal(self.album) {
            // For imported media.
            // XXX: local import doesn't set local attrib on covers yet,
            // but not super important if track or album have it
            append = "Local Library"
        }
        if let append = append {
            return coverDir.appendingPathComponent(append) as NSString
        }
        return nil
    }
    
    func coversDir() -> NSString? {
        return coversDir(SBAppDelegate.coverDirectory.path as NSString)
    }
    
    // This is overriden so that consumers don't need to handle the difference
    // between absolute and relative paths themselves. Ideally, the relative path
    // is stored (for portability), and the absolute path provides for any consumers
    // needing to load the file. By overriding the getter, we reduce refactoring.
    //
    // XXX: Why is there a difference between MusicItem.path and Cover.imagePath?
    @objc var imagePath: NSString? {
        get {
            self.willAccessValue(forKey: "imagePath")
            let currentPath = self.primitiveValue(forKey: "imagePath") as! NSString?
            // XXX: SBImportOperation was setting this, but SBSubsonicParsingOperation was not
            let fallbackPath = self.primitiveValue(forKey: "path") as! NSString?
            if let currentPath = currentPath ?? fallbackPath {
                if !currentPath.isAbsolutePath, let coversDir = coversDir() {
                    self.didAccessValue(forKey: "imagePath")
                    return coversDir.appendingPathComponent(currentPath as String) as NSString
                } else {
                    // this shouldn't happen but sure
                    self.didAccessValue(forKey: "imagePath")
                    return currentPath
                }
            }
            self.didAccessValue(forKey: "imagePath")
            return nil
        }
        set {
            self.willChangeValue(forKey: "imagePath")
            self.setPrimitiveValue(newValue, forKey: "imagePath")
            self.didChangeValue(forKey: "imagePath")
        }
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBCover {
        let entity = NSEntityDescription.entity(forEntityName: "Cover", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBCover
    }
}
