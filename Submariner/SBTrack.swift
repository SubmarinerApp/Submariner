//
//  SBTrack+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData
import UniformTypeIdentifiers

@objc(SBTrack)
public class SBTrack: SBMusicItem {
    public override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "durationString" {
            return Set(["duration"])
        } else if key == "playingImage" {
            return Set(["isPlaying"])
        } else if key == "onlineImage" {
            return Set(["isLocal"])
        }
        return Set()
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        if self.cover == nil {
            self.cover = SBCover.init(entity: SBCover.entity(), insertInto: self.managedObjectContext)
        }
    }
    
    @objc var durationString: String? {
        self.willAccessValue(forKey: "duration")
        let ret = NSString.stringWith(time: TimeInterval(duration?.intValue ?? 0))
        self.didAccessValue(forKey: "duration")
        return ret as String?
    }
    
    @objc func streamURL() -> URL? {
        let parameters = NSMutableDictionary()
        if let server = self.server, let url = server.url {
            server.getBaseParameters(parameters)
            parameters.setValue(UserDefaults.standard.string(forKey: "maxBitRate"), forKey: "maxBitRate")
            parameters.setValue(self.id, forKey: "id")
            
            return NSURL.URLWith(string: url, command: "rest/stream.view", parameters: parameters as! [String: String]?)
        }
        return nil
    }
    
    @objc func downloadURL() -> URL? {
        let parameters = NSMutableDictionary()
        if let server = self.server, let url = server.url {
            server.getBaseParameters(parameters)
            parameters.setValue(UserDefaults.standard.string(forKey: "maxBitRate"), forKey: "maxBitRate")
            parameters.setValue(self.id, forKey: "id")
            
            return NSURL.URLWith(string: url, command: "rest/download.view", parameters: parameters as! [String: String]?)
        }
        return nil
    }
    
    @objc var playingImage: NSImage? {
        if let playing = self.isPlaying, playing.boolValue {
            return NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: "Playing")
        }
        return nil
    }
    
    @objc var coverImage: NSImage {
        // change this if imageRepresentation is optimized
        return self.album?.imageRepresentation() as! NSImage
    }
    
    @objc var artistString: String? {
        if let album = self.album,
           let albumArtist = album.artist,
           let albumArtistName = albumArtist.itemName {
            return albumArtistName
        }
        return artistName
    }
    
    @objc var albumString: String? {
        return self.album?.itemName
    }
    
    @objc var onlineImage: NSImage {
        if self.localTrack != nil || self.isLocal?.boolValue == true {
            return NSImage(systemSymbolName: "bolt.horizontal.fill", accessibilityDescription: "Cached")!
        }
        return NSImage(systemSymbolName: "bolt.horizontal", accessibilityDescription: "Online")!
    }
    
    @objc func isVideo() -> Bool {
        if let contentType = self.contentType,
           let utType = UTType(mimeType: contentType) {
            return utType.conforms(to: .video)
        }
        return false
    }
    
    @objc func macOSCompatibleContentType() -> String? {
        if let contentType = self.contentType,
           contentType == "audio/x-flac" {
            return "audio/flac"
        }
        return self.contentType
    }
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBTrack {
        let entity = NSEntityDescription.entity(forEntityName: "Track", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBTrack
    }
}
