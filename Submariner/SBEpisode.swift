//
//  SBEpisode+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData

@objc(SBEpisode)
public class SBEpisode: SBTrack {
    @objc var statusImage: NSImage {
        if episodeStatus == "new" || episodeStatus == "completed" {
            return NSImage(named: NSImage.statusAvailableName)!
        }
        if episodeStatus == "error" || episodeStatus == "deleted" {
            return NSImage(named: NSImage.statusUnavailableName)!
        }
        return NSImage(named: NSImage.statusPartiallyAvailableName)!
    }
    
    @objc override func streamURL() -> URL? {
        let parameters = NSMutableDictionary()
        if let isLocal = self.isLocal, isLocal.boolValue,
           let path = self.path, FileManager.default.fileExists(atPath: path) {
            return URL.init(fileURLWithPath: path)
        } else if let server = self.server, let url = server.url {
            server.getBaseParameters(parameters)
            parameters.setValue(self.streamID, forKey: "id")
            
            return NSURL.URLWith(string: url, command: "rest/stream.view", parameters: parameters as! [String: String]?)
        }
        return nil
    }
    
    @objc override func downloadURL() -> URL? {
        let parameters = NSMutableDictionary()
        if let server = self.server, let url = server.url {
            server.getBaseParameters(parameters)
            parameters.setValue(self.streamID, forKey: "id")
            
            return NSURL.URLWith(string: url, command: "rest/download.view", parameters: parameters as! [String: String]?)
        }
        return nil
    }
    
    override public var artistName: String? {
        get {
            return self.podcast?.itemName
        }
        set {
            super.artistName = newValue
        }
    }
    
    @objc override var albumString: String? {
        self.episodeDescription
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) override class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBEpisode {
        let entity = NSEntityDescription.entity(forEntityName: "Episode", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBEpisode
    }
}
