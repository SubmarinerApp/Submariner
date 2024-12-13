//
//  SBServer+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBServer")

@objc(SBServer)
public class SBServer: SBResource {
    @objc var selectedTabIndex = 0
    
    public override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "playlists" {
            return Set(["resources"])
        } else if key == "resources" {
            return Set(["playlists"])
        } else if key == "licenseImage" {
            return Set(["isValidLicense"])
        }
        return Set()
    }
    
    // #MARK: - Supported Features
    
    // Core Data is a bad idea to persist this in, because transients are instance-local,
    // forcing us to persist this in Core Data (and persisting it is kinda stupid if it
    // gets upgraded, definitely not worth the schema change). We don't need to delete
    // items either; if the dictionary grows to where it becomes a problem, just restart.
    // This is NSNumber for Cocoa binding's sake
    fileprivate static var _supportsNowPlaying: [NSManagedObjectID: NSNumber] = [:]
    fileprivate static var _supportsPodcasts: [NSManagedObjectID: NSNumber] = [:]
    
    @objc dynamic var supportsNowPlaying: NSNumber {
        get {
            // ?? true is because we only set this if overriden to be unsupported
            return SBServer._supportsNowPlaying[self.objectID] ?? true
        }
        set {
            SBServer._supportsNowPlaying[self.objectID] = newValue
        }
    }
    
    @objc dynamic var supportsPodcasts: NSNumber {
        get {
            // ?? true is because we only set this if overriden to be unsupported
            return SBServer._supportsPodcasts[self.objectID] ?? true
        }
        set {
            SBServer._supportsPodcasts[self.objectID] = newValue
        }
    }
    
    func markNotSupported(feature: SBSubsonicRequestType) {
        switch (feature) {
        case .getNowPlaying:
            // not supported by OC Music, we special case because this gets called in the background
            supportsNowPlaying = false
            // we don't need to show a message here, since SBServerUserViewController will display this for us
        case .getPodcasts:
            // TODO: UI stuff beyond an initial dialog displayed once (switch away, hide UI like now playing SwiftUI view does, etc.)
            if supportsPodcasts.boolValue {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    // XXX: suppressable?
                    alert.alertStyle = .warning
                    alert.informativeText = "Podcasts aren't supported by the server \(self.resourceName ?? "")."
                    alert.messageText = "Unsupported Server Feature"
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
            supportsPodcasts = false
            return
        default:
            // this happened possibly unexpectedly, maybe without user interaction. do further special casing from here
            DispatchQueue.main.async {
                let alert = NSAlert()
                // XXX: suppressable?
                alert.alertStyle = .warning
                alert.informativeText = "The request type \(feature) isn't supported or implemented by the server \(self.resourceName ?? "")."
                alert.messageText = "Unsupported Server Feature"
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
    }
    
    // #MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        if self.home == nil {
            self.home = SBHome.init(entity: SBHome.entity(), insertInto: self.managedObjectContext)
        }
    }
    
    // #MARK: - Custom Accessors (Source List Tree Support)
    
    // This is used by outline views can return a variety of things.
    @objc dynamic var resources: NSSet? {
        get {
            self.willAccessValue(forKey: "resources")
            self.willAccessValue(forKey: "playlists")
            // seems we need to return a set at all for the outline view
            let result = self.primitiveValue(forKey: "playlists") as? NSSet ?? NSSet()
            self.didAccessValue(forKey: "playlists")
            self.didAccessValue(forKey: "resources")
            return result
        }
        set {
            self.willAccessValue(forKey: "resources")
            self.willAccessValue(forKey: "playlists")
            self.setPrimitiveValue(newValue, forKey: "playlists")
            self.didAccessValue(forKey: "playlists")
            self.didAccessValue(forKey: "resources")
        }
    }
    
    @objc dynamic var playlists: NSSet? {
        get {
            self.willAccessValue(forKey: "resources")
            self.willAccessValue(forKey: "playlists")
            // but i think this can be null?
            let result = self.primitiveValue(forKey: "playlists") as? NSSet
            self.didAccessValue(forKey: "playlists")
            self.didAccessValue(forKey: "resources")
            return result
        }
        set {
            self.willAccessValue(forKey: "resources")
            self.willAccessValue(forKey: "playlists")
            self.setPrimitiveValue(newValue, forKey: "playlists")
            self.didAccessValue(forKey: "playlists")
            self.didAccessValue(forKey: "resources")
        }
    }
    
    @objc var licenseImage: NSImage {
        if (self.isValidLicense?.boolValue == true) {
            return NSImage.init(named: NSImage.statusAvailableName)!
        }
        return NSImage.init(named: NSImage.statusUnavailableName)!
    }
    
    // #MARK: - Custom Accessors (Rename Directories)
    
    public override var resourceName: String? {
        get {
            self.willAccessValue(forKey: "resourceName")
            let result = self.primitiveValue(forKey: "resourceName") as! String?
            self.didAccessValue(forKey: "resourceName")
            return result
        }
        set {
            // The covers directory should be renamed, since it uses resource name.
            self.willChangeValue(forKey: "resourceName")
            // Rename here, since we can get changed by the edit server controller or source list,
            // so there's no bottleneck where we can place it.
            // XXX: Refactor to avoid having to keep doing this?
            let coversDir = SBAppDelegate.coverDirectory
            if let oldName = self.primitiveValue(forKey: "resourceName") as! String?,
               let newName = newValue {
                let oldDir = coversDir.appendingPathComponent(oldName)
                if oldName.isValidFileName(),
                   newName.isValidFileName(),
                   oldName != newName,
                   newName != "Local Library",
                   FileManager.default.fileExists(atPath: oldDir.path) {
                    let newDir = coversDir.appendingPathComponent(newName)
                    // Tie our success to if we moved the directory. If we let this get out of sync,
                    // it'll be very annoying for the user, while not fatal.
                    do {
                        try FileManager.default.moveItem(at: oldDir, to: newDir)
                        self.setPrimitiveValue(newName, forKey: "resourceName")
                    } catch {
                        DispatchQueue.main.async {
                            NSApp.presentError(error)
                        }
                    }
                } else if newName.isValidFileName(), newName != "Local Library" {
                    // If we're renaming a new server that has no content, it won't have a dir yet.
                    // No directory stuff to try, but do make sure we don't have an invalid name.
                    self.setPrimitiveValue(newName, forKey: "resourceName")
                }
            } else if let newName = newValue, newName.isValidFileName(), self.primitiveValue(forKey: "resourceName") == nil {
                // A new object will have a nil name, so it'll be safe.
                self.setPrimitiveValue(newName, forKey: "resourceName")
            }
            self.didChangeValue(forKey: "resourceName")
        }
    }
    
    // #MARK: - Custom Accessors (Keychain Support)
    
    static private var cachedPasswords: [SBServer.ID: String] = [:]
    
    @objc var password: String? {
        get {
            self.willAccessValue(forKey: "password")
            var ret: String? = nil
            if let primitivePassword = self.primitiveValue(forKey: "password") as! String?,
               primitivePassword != "" {
                // setting it will null it out and set cachedPassword
                self.password = primitivePassword
                ret = SBServer.cachedPasswords[self.id]
            } else if let cachedPassword = SBServer.cachedPasswords[self.id] {
                ret = cachedPassword
            } else if let urlString = self.url,
                      let url = URL.init(string: urlString),
                      let username = self.username,
                      let host = url.host {
                let attribs: [CFString: Any] = [
                    kSecClass: kSecClassInternetPassword,
                    kSecAttrServer: host,
                    kSecAttrAccount: username,
                    kSecAttrPath: "/",
                    kSecAttrPort: url.portWithHTTPFallback,
                    kSecAttrProtocol: url.keychainProtocol,
                    kSecMatchLimit: kSecMatchLimitOne,
                    kSecReturnData: NSNumber.init(booleanLiteral: true),
                    kSecReturnAttributes: NSNumber.init(booleanLiteral: true)
                ]
                var results: AnyObject? = nil
                logger.info("SBServer.password getter: Getting internet keychain for \(url.absoluteString) user \(username)")
                let keychainStatus = SecItemCopyMatching(attribs as CFDictionary, &results)
                if keychainStatus == errSecItemNotFound {
                    // ok to get unlike other errors
                    logger.info("SBServer.password getter: Keychain item not found")
                    ret = nil
                } else if keychainStatus != errSecSuccess {
                    let error = NSError(domain: NSOSStatusErrorDomain, code: Int(keychainStatus))
                    logger.error("SBServer.password getter: Keychain error \(error, privacy: .public)")
                    DispatchQueue.main.async {
                        NSApp.presentError(error)
                    }
                } else if let resultsDict = results as? [CFString: Any],
                          let passwordData = resultsDict[kSecValueData] as? Data { // success
                    logger.info("SBServer.password getter: Successfully got the password")
                    ret = String.init(data: passwordData, encoding: .utf8)
                    SBServer.cachedPasswords[self.id] = ret
                }
            }
            self.didAccessValue(forKey: "password")
            return ret
        }
        set {
            self.willChangeValue(forKey: "password")
            // XXX: should we invalidate the stored pw?
            SBServer.cachedPasswords.removeValue(forKey: self.id)

            // decompose URL
            if self.url != nil && self.username != nil {
                // don't do the keychain update here anymore
                SBServer.cachedPasswords[self.id] = newValue
                // clear out the remnant of Core Data stored password
                self.setPrimitiveValue("", forKey: "password")
            }
            self.willChangeValue(forKey: "password")
        }
    }
    
    @objc func updateKeychainPassword() {
        if let urlString = self.url,
           let url = URL.init(string: urlString),
           let username = self.username,
           let password = self.password,
           let host = url.host {
            let passwordData = password.data(using: .utf8) ?? Data()
            var attribs: [CFString: Any] = [
              kSecClass: kSecClassInternetPassword,
              kSecAttrServer: host,
              kSecAttrAccount: username,
              kSecAttrPath: "/",
              kSecAttrPort: url.portWithHTTPFallback,
              kSecAttrProtocol: url.keychainProtocol,
              kSecValueData: passwordData
            ]
            
            logger.info("SBServer.password new URL setter: Setting internet keychain for \(url) user \(username)")
            var ret = SecItemAdd(attribs as CFDictionary, nil)
            if ret == errSecDuplicateItem {
                logger.warning("SBServer.password old URL setter: Duplicate item, adding instead")
                attribs.removeValue(forKey: kSecValueData)
                let updateAttribs: [CFString: Any] = [
                    kSecValueData: passwordData
                ]
                ret = SecItemUpdate(attribs as CFDictionary, updateAttribs as CFDictionary)
            }
            if ret != errSecSuccess {
                let error = NSError(domain: NSOSStatusErrorDomain, code: Int(ret))
                logger.error("SBServer.password new URL setter: Keychain error \(error, privacy: .public)")
                DispatchQueue.main.async {
                    NSApp.presentError(error)
                }
            }
        }
    }
    
    @objc func updateKeychain(oldURL: URL, oldUsername: String) {
        if let url = self.url,
           let newURL = URL.init(string: url),
           let username = self.username,
           let password = self.password,
           let oldHost = oldURL.host,
           let host = newURL.host {
            let passwordData = password.data(using: .utf8) ?? Data()
            let attribs: [CFString: Any] = [
              kSecClass: kSecClassInternetPassword,
              kSecAttrServer: oldHost,
              kSecAttrAccount: oldUsername,
              kSecAttrPath: "/",
              kSecAttrPort: oldURL.portWithHTTPFallback,
              kSecAttrProtocol: oldURL.keychainProtocol,
              kSecValueData: passwordData
            ]
            
            let newAttribs: [CFString: Any] = [
                kSecAttrServer: host,
                kSecAttrAccount: username,
                kSecAttrPort: newURL.portWithHTTPFallback,
                kSecAttrProtocol: newURL.keychainProtocol,
                kSecValueData: passwordData
            ]
            
            logger.info("SBServer.password old URL setter: Setting internet keychain for \(oldURL) user \(oldUsername) vs \(newURL) user \(username)")
            let ret = SecItemUpdate(attribs as CFDictionary, newAttribs as CFDictionary)
            if ret == errSecItemNotFound {
                // Use the old method of having it be updated by the current values,
                // since we have nothing to update. This will create it in keychain.
                logger.info("SBServer.password old URL setter: Have to update for current value")
                self.updateKeychainPassword()
            } else if ret != errSecSuccess {
                let error = NSError(domain: NSOSStatusErrorDomain, code: Int(ret))
                logger.error("SBServer.password old URL setter: Keychain error \(error, privacy: .public)")
                DispatchQueue.main.async {
                    NSApp.presentError(error)
                }
            } else {
                logger.info("SBServer.password old URL setter: Success")
            }
        }
    }
    
    // #MARK: - Subsonic Client (Login)
    
    @objc func connect() {
        let request = SBSubsonicRequestOperation(server: self, request: .ping)
        request.main()
    }
    
    @objc func getServerLicense() {
        let request = SBSubsonicRequestOperation(server: self, request: .getLicense)
        request.main()
    }
    
    /**
     Gets the base query string parameters based on the server object's properties.
     
     The intent is to use these as a base, then add other options that your command requires.
     */
    @objc func getBaseParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let username = self.username, let password = self.password {
            parameters["u"] = username
            if self.useTokenAuth?.boolValue == true,
               // we can fall back to password if this somehow fails
               let saltBytes = Data(randomByteCount: 64) {
                parameters.removeValue(forKey: "p")
                let salt = String.hexStringFrom(bytes: saltBytes)
                parameters["s"] = salt
                let token = (password + salt).md5()
                parameters["t"] = token
            } else {
                parameters.removeValue(forKey: "t")
                parameters.removeValue(forKey: "s")
                let obfuscatedPassword = "enc:" + password.toHex()!
                parameters["p"] = obfuscatedPassword
            }
            parameters["v"] = UserDefaults.standard.string(forKey: "apiVersion")
            parameters["c"] = UserDefaults.standard.string(forKey: "clientIdentifier")
        }
        // XXX: Enable in release build?
        logger.info("Base params for \(self.url ?? "<no URL>"):")
        for (k, v) in parameters {
            if k == "p" || k == "t" || k == "s" {
                logger.info("\tSensitive parameter \(k, privacy: .public) = \(v.count) long")
            } else {
                logger.info("\tparameter \(k, privacy: .public) = \(v, privacy: .public)")
            }
        }
        return parameters
    }
    
    // #MARK: - Subsonic Client (Server Data)
    
    @objc func getArtists() {
        let request = SBSubsonicRequestOperation(server: self, request: .getArtists)
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc(getArtist:) func get(artist: SBArtist) {
        guard let artistId = artist.itemId else { return }
        let request = SBSubsonicRequestOperation(server: self, request: .getArtist(id: artistId))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc(getAlbum:) func get(album: SBAlbum) {
        guard let albumId = album.itemId else { return }
        let request = SBSubsonicRequestOperation(server: self, request: .getAlbum(id: albumId))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    func getTrack(trackID: String) {
        let request = SBSubsonicRequestOperation(server: self, request: .getTrack(id: trackID))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    func getCover(id: String, for albumID: String?) {
        let request = SBSubsonicRequestOperation(server: self, request: .getCoverArt(id: id, forAlbumId: albumID))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc func getAlbumListFor(type: SBAlbumListType) {
        let request = SBSubsonicRequestOperation(server: self, request: .getAlbumList(type: type))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc func getServerDirectories() {
        let request = SBSubsonicRequestOperation(server: self, request: .getDirectories)
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    func getServerDirectory(id: String) {
        let request = SBSubsonicRequestOperation(server: self, request: .getDirectory(id: id))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    // #MARK: - Subsonic Client (Playlists)
    
    @objc func getServerPlaylists() {
        let request = SBSubsonicRequestOperation(server: self, request: .getPlaylists)
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc func createPlaylist(name: String, tracks: [SBTrack]) {
        let request = SBSubsonicRequestOperation(server: self, request: .createPlaylist(name: name, tracks: tracks))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc func updatePlaylist(ID: String, tracks: [SBTrack]) {
        let request = SBSubsonicRequestOperation(server: self, request: .replacePlaylist(id: ID, tracks: tracks))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    // public ommited because Bool? not in objc
    @objc func updatePlaylist(ID: String,
                              name: String? = nil,
                              comment: String? = nil,
                              appending: [SBTrack]? = nil,
                              removing: [Int]? = nil) {
        let request = SBSubsonicRequestOperation(server: self, request: .updatePlaylist(id: ID, name: name, comment: comment, isPublic: nil, appending: appending, removing: removing))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    func updatePlaylist(ID: String,
                        name: String? = nil,
                        comment: String? = nil,
                        isPublic: Bool?,
                        appending: [SBTrack]? = nil,
                        removing: [Int]? = nil) {
        let request = SBSubsonicRequestOperation(server: self, request: .updatePlaylist(id: ID, name: name, comment: comment, isPublic: isPublic, appending: appending, removing: removing))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc func deletePlaylist(ID: String) {
        let request = SBSubsonicRequestOperation(server: self, request: .deletePlaylist(id: ID))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc func getPlaylistTracks(_ playlist: SBPlaylist) {
        guard let playlistId = playlist.itemId else { return }
        let request = SBSubsonicRequestOperation(server: self, request: .getPlaylist(id: playlistId))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    // #MARK: - Subsonic Client (Podcasts)
    
    @objc func getServerPodcasts() {
        let request = SBSubsonicRequestOperation(server: self, request: .getPodcasts)
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    // #MARK: - Subsonic Client (Now Playing)
    
    @objc func getNowPlaying() {
        if self.supportsNowPlaying == true {
            let request = SBSubsonicRequestOperation(server: self, request: .getNowPlaying)
            OperationQueue.sharedServerQueue.addOperation(request)
        }
    }
    
    func scrobble(id: String) {
        let request = SBSubsonicRequestOperation(server: self, request: .scrobble(id: id))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    // #MARK: - Subsonic Client (Search)
    
    @objc func search(query: String) {
        let request = SBSubsonicRequestOperation(server: self, request: .search(query: query))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc(getTopTracksForArtistName:) func getTopTracks(artistName: String) {
        let request = SBSubsonicRequestOperation(server: self, request: .getTopTracks(artistName: artistName))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc func getSimilarTracks(to artist: SBArtist) {
        let request = SBSubsonicRequestOperation(server: self, request: .getSimilarTracks(artist: artist))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    // #MARK: - Subsonic Client (Rating)
    
    @objc(setRating:forID:) func setRating(_ rating: Int, id: String) {
        let request = SBSubsonicRequestOperation(server: self, request: .setRating(id: id, rating: rating))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    func star(tracks: [SBTrack] = [], albums: [SBAlbum] = [], artists: [SBArtist] = [], directories: [SBDirectory] = []) {
        let request = SBSubsonicRequestOperation(server: self,
                                                 request: .star(tracks: tracks, albums: albums, artists: artists, directories: directories))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    func unstar(tracks: [SBTrack] = [], albums: [SBAlbum] = [], artists: [SBArtist] = [], directories: [SBDirectory] = []) {
        let request = SBSubsonicRequestOperation(server: self,
                                                 request: .unstar(tracks: tracks, albums: albums, artists: artists, directories: directories))
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    // #MARK: - Subsonic Client (Library Scan)
    
    @objc func scanLibrary() {
        let request = SBSubsonicRequestOperation(server: self, request: .scanLibrary)
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    @objc func getScanStatus() {
        let request = SBSubsonicRequestOperation(server: self, request: .getScanStatus)
        OperationQueue.sharedServerQueue.addOperation(request)
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBServer {
        let entity = NSEntityDescription.entity(forEntityName: "Server", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBServer
    }
}
