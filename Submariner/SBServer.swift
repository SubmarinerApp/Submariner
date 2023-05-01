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
    
    // #MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        if self.home == nil {
            self.home = SBHome.init(entity: SBHome.entity(), insertInto: self.managedObjectContext)
        }
    }
    
    // #MARK: - Custom Accessors (Source List Tree Support)
    
    @objc var resources: NSSet {
        get {
            self.willAccessValue(forKey: "resources")
            self.willAccessValue(forKey: "playlists")
            let result = self.primitiveValue(forKey: "playlists") as! NSSet
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
    
    @objc var playlist: NSSet {
        get {
            self.willAccessValue(forKey: "resources")
            self.willAccessValue(forKey: "playlists")
            let result = self.primitiveValue(forKey: "playlists") as! NSSet
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
            let coversDir = URL.init(fileURLWithPath: SBAppDelegate.sharedInstance().coverDirectory())
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
            } else if let newName = newValue, self.primitiveValue(forKey: "resourceName") == nil {
                // A new object will have a nil name, so it'll be safe.
                self.setPrimitiveValue(newName, forKey: "resourceName")
            }
            self.didChangeValue(forKey: "resourceName")
        }
    }
    
    // #MARK: - Custom Accessors (Subsonic Client)
    
    @objc lazy var clientController: SBClientController = {
        let clientController = SBClientController(managedObjectContext: self.managedObjectContext)
        clientController?.server = self
        return clientController!
    }()
    
    // #MARK: - Custom Accessors (Keychain Support)
    
    // instance local
    private var cachedPassword: String? = nil
    
    @objc var password: String? {
        get {
            self.willAccessValue(forKey: "password")
            var ret: String? = nil
            if let primitivePassword = self.primitiveValue(forKey: "password") as! String?,
               primitivePassword != "" {
                // setting it will null it out and set cachedPassword
                self.password = primitivePassword
                ret = cachedPassword
            } else if let cachedPassword = self.cachedPassword {
                ret = cachedPassword
            } else if let urlString = self.url,
                      let url = URL.init(string: urlString),
                      let username = self.username {
                let attribs: [CFString: Any] = [
                    kSecClass: kSecClassInternetPassword,
                    kSecAttrServer: url.host!,
                    kSecAttrAccount: username,
                    kSecAttrPath: "/",
                    kSecAttrPort: url.portWithHTTPFallback,
                    kSecAttrProtocol: url.keychainProtocol,
                    kSecMatchLimit: kSecMatchLimitOne,
                    kSecReturnData: NSNumber.init(booleanLiteral: true),
                    kSecReturnAttributes: NSNumber.init(booleanLiteral: true)
                ]
                var results: AnyObject? = nil
                print("SBServer.password getter: Getting internet keychain for", url, "user", username)
                let keychainStatus = SecItemCopyMatching(attribs as CFDictionary, &results)
                if keychainStatus == errSecItemNotFound {
                    // ok to get unlike other errors
                    print("SBServer.password getter: Keychain item not found")
                    ret = nil
                } else if keychainStatus != errSecSuccess {
                    let error = NSError(domain: NSOSStatusErrorDomain, code: Int(keychainStatus))
                    print("SBServer.password getter: Keychain error", error)
                    DispatchQueue.main.async {
                        NSApp.presentError(error)
                    }
                } else if let resultsDict = results as? [CFString: Any],
                          let passwordData = resultsDict[kSecValueData] as? Data { // success
                    print("SBServer.password getter: Successfully got the password")
                    ret = String.init(data: passwordData, encoding: .utf8)
                    cachedPassword = ret
                }
            }
            self.didAccessValue(forKey: "password")
            return ret
        }
        set {
            self.willChangeValue(forKey: "password")
            // XXX: should we invalidate the stored pw?
            self.cachedPassword = nil

            // decompose URL
            if self.url != nil && self.username != nil {
                // don't do the keychain update here anymore
                cachedPassword = newValue
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
           let password = self.password {
            let passwordData = password.data(using: .utf8) ?? Data()
            var attribs: [CFString: Any] = [
              kSecClass: kSecClassInternetPassword,
              kSecAttrServer: url.host!,
              kSecAttrAccount: username,
              kSecAttrPath: "/",
              kSecAttrPort: url.portWithHTTPFallback,
              kSecAttrProtocol: url.keychainProtocol,
              kSecValueData: passwordData
            ]
            
            print("SBServer.password new URL setter: Setting internet keychain for", url, "user", username)
            var ret = SecItemAdd(attribs as CFDictionary, nil)
            if ret == errSecDuplicateItem {
                print("SBServer.password old URL setter: Duplicate item, adding instead")
                attribs.removeValue(forKey: kSecValueData)
                let updateAttribs: [CFString: Any] = [
                    kSecValueData: passwordData
                ]
                ret = SecItemUpdate(attribs as CFDictionary, updateAttribs as CFDictionary)
            }
            if ret != errSecSuccess {
                let error = NSError(domain: NSOSStatusErrorDomain, code: Int(ret))
                print("SBServer.password new URL setter: Keychain error", error)
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
           let password = self.password {
            let passwordData = password.data(using: .utf8) ?? Data()
            let attribs: [CFString: Any] = [
              kSecClass: kSecClassInternetPassword,
              kSecAttrServer: oldURL.host!,
              kSecAttrAccount: oldUsername,
              kSecAttrPath: "/",
              kSecAttrPort: oldURL.portWithHTTPFallback,
              kSecAttrProtocol: oldURL.keychainProtocol,
              kSecValueData: passwordData
            ]
            
            let newAttribs: [CFString: Any] = [
                kSecAttrServer: newURL.host!,
                kSecAttrAccount: username,
                kSecAttrPort: newURL.portWithHTTPFallback,
                kSecAttrProtocol: newURL.keychainProtocol,
                kSecValueData: passwordData
            ]
            
            print("SBServer.password old URL setter: Setting internet keychain for", oldURL, "user", oldUsername, "vs", newURL, "user", username)
            let ret = SecItemUpdate(attribs as CFDictionary, newAttribs as CFDictionary)
            if ret == errSecItemNotFound {
                // Use the old method of having it be updated by the current values,
                // since we have nothing to update. This will create it in keychain.
                print("SBServer.password old URL setter: Have to update for current value")
                self.updateKeychainPassword()
            } else if ret != errSecSuccess {
                let error = NSError(domain: NSOSStatusErrorDomain, code: Int(ret))
                print("SBServer.password old URL setter: Keychain error", error)
                DispatchQueue.main.async {
                    NSApp.presentError(error)
                }
            } else {
                print("SBServer.password old URL setter: Success")
            }
        }
    }
    
    // #MARK: - Subsonic Client (Login)
    
    @objc func connect() {
        self.clientController.connect(to: self)
    }
    
    @objc func getServerLicense() {
        self.clientController.getLicense()
    }
    
    @objc func getBaseParameters(_ parameters: NSMutableDictionary) {
        if let username = self.username, let password = self.password {
            parameters.setValue(username, forKey: "u")
            if self.useTokenAuth?.boolValue == true {
                parameters.removeObject(forKey: "p")
                var saltBytes = Data(count: 64)
                let saltResult = saltBytes.withUnsafeMutableBytes { mutableData in
                    SecRandomCopyBytes(kSecRandomDefault, 64, mutableData)
                }
                if saltResult != errSecSuccess {
                    abort()
                }
                let salt = String.hexStringFrom(bytes: saltBytes)
                parameters.setValue(salt, forKey: "s")
                let token = String.init(format: "%@%@", password, salt).md5()
                parameters.setValue(token, forKey: "t")
            } else {
                parameters.removeObject(forKey: "t")
                parameters.removeObject(forKey: "s")
                let obfuscatedPassword = String.init(format: "enc:%@", password.toHex()!)
                parameters.setValue(obfuscatedPassword, forKey: "p")
            }
            parameters.setValue(UserDefaults.standard.string(forKey: "apiVersion"), forKey: "v")
            parameters.setValue(UserDefaults.standard.string(forKey: "clientIdentifier"), forKey: "c")
        }
    }
    
    // #MARK: - Subsonic Client (Server Data)
    
    @objc func getServerIndexes() {
        if let lastIndexesDate = self.lastIndexesDate {
            self.clientController.getIndexesSince(lastIndexesDate)
        } else {
            self.clientController.getIndexes()
        }
    }
    
    @objc func getAlbumsFor(artist: SBArtist) {
        self.clientController.getAlbumsFor(artist)
    }
    
    @objc func getTracksFor(albumID: String) {
        self.clientController.getTracksForAlbumID(albumID)
    }
    
    @objc func getAlbumListFor(type: SBSubsonicRequestType) {
        self.clientController.getAlbumList(for: type)
    }
    
    // #MARK: - Subsonic Client (Playlists)
    
    @objc func getServerPlaylists() {
        self.clientController.getPlaylists()
    }
    
    @objc func createPlaylist(name: String, tracks: [SBTrack]) {
        self.clientController.createPlaylist(withName: name, tracks: tracks)
    }
    
    @objc func updatePlaylist(ID: String, tracks: [SBTrack]) {
        self.clientController.updatePlaylist(withID: ID, tracks: tracks)
    }
    
    @objc func deletePlaylist(ID: String) {
        self.clientController.deletePlaylist(withID: ID)
    }
    
    @objc func getPlaylistTracks(_ playlist: SBPlaylist) {
        self.clientController.getPlaylist(playlist)
    }
    
    // #MARK: - Subsonic Client (Podcasts)
    
    @objc func getServerPodcasts() {
        self.clientController.getPodcasts()
    }
    
    // #MARK: - Subsonic Client (Now Playing)
    
    @objc func getNowPlaying() {
        self.clientController.getNowPlaying()
    }
    
    // #MARK: - Subsonic Client (Search)
    
    @objc func search(query: String) {
        self.clientController.search(query)
    }
    
    // #MARK: - Subsonic Client (Rating)
    
    @objc(setRating:forID:) func setRating(_ rating: Int, id: String) {
        self.clientController.setRating(rating, forID: id)
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBServer {
        let entity = NSEntityDescription.entity(forEntityName: "Server", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBServer
    }
}
