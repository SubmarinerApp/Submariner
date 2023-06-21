//
//  SBSubsonicParsingOperation.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-06-20.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBSubsonicParsingOperation")

class SBSubsonicParsingOperation2: SBOperation, XMLParserDelegate {
    let clientController: SBClientController
    let requestType: SBSubsonicRequestType
    let server: SBServer
    let xmlData: Data?
    let mimeType: String?
    
    // state
    var numberOfChildrens: Int = 0
    var playlistIndex: Int = 0
    
    // state for selected object
    var currentArtist: SBArtist?
    var currentAlbum: SBAlbum?
    var currentPodcast: SBPodcast?
    
    var currentCoverID: String?
    
    init!(managedObjectContext mainContext: NSManagedObjectContext!,
          clientController: SBClientController,
          requestType: SBSubsonicRequestType,
          server: NSManagedObjectID,
          xml: Data?,
          mimeType: String?) {
        self.requestType = requestType
        self.clientController = clientController
        self.server = mainContext.object(with: server) as! SBServer
        self.xmlData = xml
        self.mimeType = mimeType
        
        super.init(managedObjectContext: mainContext)
    }
    
    // #MARK: - NSOperation
    
    override func main() {
        synchronized(server) {
            defer {
                self.finish()
                self.saveThreadedContext()
            }
            do {
                if self.requestType == .getCoverArt, let mimeType = self.mimeType, mimeType.hasPrefix("image/") {
                    try mainImportCover()
                } else if let mimeType = self.mimeType, mimeType.contains("xml") {
                    // Navidrome and Subsonic differ by using application/ or text/
                    try mainXML()
                } else if let mimeType = self.mimeType, mimeType.contains("json") {
                    logger.error("Submariner doesn't support JSON")
                }
            } catch {
                DispatchQueue.main.async {
                    NSApplication.shared.presentError(error)
                }
            }
        }
    }
    
    // TODO: These should be factored out into separate classes
    private func mainImportCover() throws {
        let coversDir = SBAppDelegate.coverDirectory.appendingPathComponent(server.resourceName!)
        
        if !FileManager.default.fileExists(atPath: coversDir.path) {
            try FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
        }
        
        if let currentCoverID = self.currentCoverID, let data = self.xmlData {
            // we know mimeType is not null coming from main. worst case, ID3 covers are usually JPEG
            let fileType = UTType(mimeType: self.mimeType!) ?? data.guessImageType() ?? UTType.jpeg
            let fileName = coversDir.appendingPathComponent(currentCoverID, conformingTo: fileType)
            try data.write(to: fileName, options: [.atomic])
            
            if let cover = fetchCover(coverID: currentCoverID) {
                cover.imagePath = fileName.path as NSString
            }
        }
        
        NotificationCenter.default.post(name: .SBSubsonicCoversUpdated, object: nil)
        self.saveThreadedContext()
    }
    
    private func mainXML() throws {
        if let data = self.xmlData {
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
        }
    }
    
    // #MARK: - XML elements
    
    private func parseElementSubsonicResponse(attributeDict: [String: String]) {
        if attributeDict["status"] == "ok" {
            server.apiVersion = attributeDict["version"]
        }
        // ping response happens at end of document, errors as well
    }
    
    private func parseElementError(attributeDict: [String: String]) {
        logger.error("Subsonic error element, code \(attributeDict["code"] ?? "unknown", privacy: .public), \(attributeDict["message"] ?? "", privacy: .public)")
        NotificationCenter.default.post(name: .SBSubsonicConnectionFailed, object: attributeDict)
    }
    
    private func parseElementIndexes(attributeDict: [String: String]) {
        if let timestampString = attributeDict["timestamp"],
           let timestamp = Double(timestampString) {
            let date = Date(timeIntervalSince1970: timestamp)
            server.lastIndexesDate = date
        }
    }
    
    private func parseElementIndex(attributeDict: [String: String]) {
        if let indexName = attributeDict["name"] {
            if fetchGroup(groupName: indexName) != nil {
                return
            }
            logger.log("Creating new index group: \(indexName, privacy: .public)")
            let group = createGroup(attributes: attributeDict)
            server.addToIndexes(group)
            group.server = server
        }
    }
    
    private func parseElementArtist(attributeDict: [String: String]) {
        if let id = attributeDict["id"], let name = attributeDict["name"] {
            if fetchArtist(id: id) != nil {
                return
            }
            logger.log("Creating new artist with ID: \(id, privacy: .public) and name \(name, privacy: .public)")
            let artist = createArtist(attributes: attributeDict)
            server.addToIndexes(artist)
            artist.server = server
        }
    }
    
    private func parseElementDirectory(attributeDict: [String: String]) {
        if requestType == .getAlbumDirectory {
            if let id = attributeDict["id"], let artist = fetchArtist(id: id) {
                currentArtist = artist
            }
        } else if requestType == .getTrackDirectory {
            if let id = attributeDict["id"], let album = fetchAlbum(id: id, artist: currentArtist) {
                currentAlbum = album
            }
        } else {
            logger.warning("Invalid request type \(self.requestType.rawValue, privacy: .public) for directory element")
        }
    }
    
    private func parseElementChildForAlbumDirectory(attributeDict: [String: String]) {
        // Try not to consume an object that doesn't make sense. For now, we assume a hierarchy of
        // Artist/Album/Track.ext. Navidrome is happy to oblige us and make up a hierarchy, but
        // Subsonic doesn't guarantee it when it gives you the real FS layout.
        if let currentArtist = self.currentArtist,
           attributeDict["isDir"] == "true",
           let id = attributeDict["id"],
           let name = attributeDict["title"] {
            // TODO: This whole metaphor is translated from Objective-C and is kinda clumsy.
            var album = fetchAlbum(id: id, artist: currentArtist)
            if album == nil {
                logger.log("Creating new album with ID: \(id, privacy: .public) and name \(name, privacy: .public)")
                album = createAlbum(attributes: attributeDict)
                // now assume not nil
                album!.artist = currentArtist
                currentArtist.addToAlbums(album!)
            }
            
            // the track may not have a cover assigned yet
            if let cover = album!.cover {
                // the album already has a cover
                logger.info("Album ID \(id, privacy: .public) already has a cover")
            } else if let coverID = attributeDict["coverArt"],
                      let cover = fetchCover(coverID: coverID) {
                // the album doesn't have a cover, but somehow the ID exists already
                logger.warning("Album ID \(id, privacy: .public) isn't assigned to cover \(coverID, privacy: .public)")
                // so assign it
                cover.album = album!
                album!.cover = cover
            } else if let coverID = attributeDict["coverArt"] {
                // there is no cover
                logger.log("Creating new cover with ID: \(coverID, privacy: .public) for album ID \(id, privacy: .public)")
                let cover = createCover(attributes: attributeDict)
                cover.album = album!
                album!.cover = cover
            }
            
            // now fetch that cover after we initialized one
            if let cover = album!.cover, let coverID = cover.id,
               (cover.imagePath == nil || !FileManager.default.fileExists(atPath: cover.imagePath! as String)) {
                // file doesn't exist, fetch it
                logger.log("Fetching file for cover with ID: \(coverID, privacy: .public)")
                clientController.getCover(id: coverID)
            }
        }
    }
    
    private func parseElementChildForTrackDirectory(attributeDict: [String: String]) {
        if let currentAlbum = self.currentAlbum, attributeDict["isDir"] == "false",
           let id = attributeDict["id"] {
            if let track = fetchTrack(id: id) {
                
            }
        }
    }
    
    private func parseElementChild(attributeDict: [String: String]) {
        if requestType == .getAlbumDirectory {
            parseElementChildForAlbumDirectory(attributeDict: attributeDict)
        } else if requestType == .getTrackDirectory {
        } else {
            logger.warning("Invalid request type \(self.requestType.rawValue, privacy: .public) for child element")
        }
    }
    
    // #MARK: - XML delegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        numberOfChildrens += 1
        if elementName == "subsonic-response" {
            // don't count ourselves
            numberOfChildrens -= 0
            parseElementSubsonicResponse(attributeDict: attributeDict)
        } else if elementName == "error" {
            parseElementError(attributeDict: attributeDict)
        } else if elementName == "indexes" {
            parseElementIndexes(attributeDict: attributeDict)
        } else if elementName == "index" { // build group index
            parseElementIndex(attributeDict: attributeDict)
        } else if elementName == "artist" { // build artist index
            parseElementArtist(attributeDict: attributeDict)
        } else if elementName == "directory" { // a directory...
            parseElementDirectory(attributeDict: attributeDict)
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "podcast" {
            currentPodcast = nil
        } else if elementName == "playlist" {
            playlistIndex = 0
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        logger.error("XML parsing error \(parseError, privacy: .public)")
        DispatchQueue.main.async {
            NSApp.presentError(parseError)
        }
    }
    
    // #MARK: - Fetch Core Data objects
    // TODO: These might make more sense on their Core Data classes.
    
    private func fetchGroup(groupName: String) -> SBGroup? {
        let fetchRequest = NSFetchRequest<SBGroup>(entityName: "Group")
        fetchRequest.predicate = NSPredicate(format: "(itemName == %@) && (server == %@)", groupName, server)
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchArtist(id: String) -> SBArtist? {
        let fetchRequest = NSFetchRequest<SBArtist>(entityName: "Artist")
        fetchRequest.predicate = NSPredicate(format: "(id == %@) && (server == %@)", id, server)
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchArtist(name: String) -> SBArtist? {
        let fetchRequest = NSFetchRequest<SBArtist>(entityName: "Artist")
        fetchRequest.predicate = NSPredicate(format: "(itemName == %@) && (server == %@)", name, server)
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchAlbum(id: String, artist: SBArtist? = nil) -> SBAlbum? {
        let fetchRequest = NSFetchRequest<SBAlbum>(entityName: "Album")
        if let artist = artist {
            fetchRequest.predicate = NSPredicate(format: "(id == %@) && (artist == %@)", id, artist)
        } else {
            fetchRequest.predicate = NSPredicate(format: "(id == %@)", id)
        }
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchAlbum(name: String, artist: SBArtist? = nil) -> SBAlbum? {
        let fetchRequest = NSFetchRequest<SBAlbum>(entityName: "Album")
        if let artist = artist {
            fetchRequest.predicate = NSPredicate(format: "(itemName == %@) && (artist == %@)", name, artist)
        } else {
            fetchRequest.predicate = NSPredicate(format: "(itemName == %@)", name)
        }
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchCover(coverID: String) -> SBCover? {
        let fetchRequest = NSFetchRequest<SBCover>(entityName: "Cover")
        // XXX: server on predicate here?
        fetchRequest.predicate = NSPredicate(format: "(id == %@)", coverID)
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchTrack(id: String, album: SBAlbum? = nil) -> SBTrack? {
        let fetchRequest = NSFetchRequest<SBTrack>(entityName: "Track")
        if let album = album {
            fetchRequest.predicate = NSPredicate(format: "(server == %@) && (id == %@) && (album == %@)", server, id, album)
        } else {
            fetchRequest.predicate = NSPredicate(format: "(server == %@) && (id == %@)", server, id)
        }
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchAlbum(name: String, album: SBAlbum? = nil) -> SBTrack? {
        let fetchRequest = NSFetchRequest<SBTrack>(entityName: "Track")
        if let album = album {
            fetchRequest.predicate = NSPredicate(format: "(server == %@) && (itemName == %@) && (artist == %@)", server, name, album)
        } else {
            fetchRequest.predicate = NSPredicate(format: "(server == %@) && (itemName == %@)", server, name)
        }
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    // #MARK: - Create Core Data objects
    
    private func createGroup(attributes: [String: String]) -> SBGroup {
        let group = SBGroup.insertInManagedObjectContext(context: threadedContext)
        
        if let name = attributes["name"] {
            group.itemName = name
        }
        
        return group
    }
    
    private func createArtist(attributes: [String: String]) -> SBArtist {
        let artist = SBArtist.insertInManagedObjectContext(context: threadedContext)
        
        if let name = attributes["name"] {
            artist.itemName = name
        }
        // i think it's in other contexts
        if let artistName = attributes["artist"] {
            artist.itemName = artistName
        }
        
        if let id = attributes["id"] {
            artist.id = id
        }
        
        artist.isLocal = false
        
        return artist
    }
    
    private func createAlbum(attributes: [String: String]) -> SBAlbum {
        let album = SBAlbum.insertInManagedObjectContext(context: threadedContext)
        
        if let name = attributes["title"] {
            album.itemName = name
        }
        
        if let id = attributes["id"] {
            album.id = id
        }
        
        // don't assume cover yet
        
        album.isLocal = false
        
        return album
    }
    
    private func createCover(attributes: [String: String]) -> SBCover {
        let cover = SBCover.insertInManagedObjectContext(context: threadedContext)
        
        if let id = attributes["coverArt"] {
            cover.id = id
        }
        
        return cover
    }
}
