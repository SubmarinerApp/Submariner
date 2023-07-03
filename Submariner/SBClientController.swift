//
//  SBClientController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-06-13.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBClientController")

@objc class SBClientController: NSObject {
    let managedObjectContext: NSManagedObjectContext
    let server: SBServer // XXX: weak?
    
    var parameters: [String: String] = [:]
    
    @objc init(managedObjectContext: NSManagedObjectContext, server: SBServer) {
        self.managedObjectContext = managedObjectContext
        self.server = server
        super.init()
    }
    
    // #MARK: - HTTP Requests
    
    private func request(url: URL, type: SBSubsonicRequestType, customization: ((SBSubsonicParsingOperation2) -> Void)? = nil) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let request = URLRequest(url: url)
        
        if let username = server.username, let password = server.password {
            let loginString = "\(username):\(password)"
            if let loginData = loginString.data(using: .utf8) {
                let base64login = loginData.base64EncodedString()
                let authHeader = "Basic \(base64login)"
                config.httpAdditionalHeaders = ["Authorization": authHeader]
            }
        } else {
            logger.warning("Empty username/password, no authorization header will be included.")
            logger.warning("username nil? \(self.server.username == nil) password nil? \(self.server.password == nil)")
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            // sensitive because &p= contains user password
            logger.info("Handling URL \(url, privacy: .sensitive)")
            logger.info("\tAPI endpoint \(url.path, privacy: .public)")
            
            if let error = error {
                DispatchQueue.main.async {
                    NSApp.presentError(error)
                }
                return
            } else if let response = response as? HTTPURLResponse {
                logger.info("\tStatus code is \(response.statusCode)")
                // Note that Subsonic and Navidrome return app-level error bodies in HTTP 200
                if response.statusCode != 200 {
                    let message = "HTTP \(response.statusCode) for \(url.path)"
                    let userInfo = [NSLocalizedDescriptionKey: message]
                    // XXX: Right domain?
                    let error = NSError(domain: NSURLErrorDomain, code: response.statusCode, userInfo: userInfo)
                    DispatchQueue.main.async {
                        NSApp.presentError(error)
                    }
                    return
                }
                
                if let operation = SBSubsonicParsingOperation2(managedObjectContext: self.managedObjectContext,
                                                               client: self,
                                                               requestType: type,
                                                               server: self.server.objectID,
                                                               xml: data,
                                                               mimeType: response.mimeType) {
                    if let customization = customization {
                        customization(operation)
                    }
                    OperationQueue.sharedServerQueue.addOperation(operation)
                }
            }
        }
        task.resume()
    }
    
    // #MARK: - Request Messages
    
    @objc func connect(server: SBServer) {
        parameters = parameters.mergedCopyFrom(dictionary: server.getBaseParameters())
        let url = URL.URLWith(string: server.url!, command: "rest/ping.view", parameters: parameters)
        request(url: url!, type: .ping)
    }
    
    @objc func getLicense() {
        let url = URL.URLWith(string: server.url!, command: "rest/getLicense.view", parameters: parameters)
        request(url: url!, type: .getLicence)
    }
    
    @objc func getIndexes() {
        let url = URL.URLWith(string: server.url!, command: "rest/getIndexes.view", parameters: parameters)
        request(url: url!, type: .getIndexes)
    }
    
    @objc(getIndexesSince:) func getIndexes(since: Date) {
        var params = parameters
        params["ifModifiedSince"] = String(format: "%00.f", since.timeIntervalSince1970)
        
        let url = URL.URLWith(string: server.url!, command: "rest/getIndexes.view", parameters: params)
        request(url: url!, type: .getIndexes)
    }
    
    @objc(getAlbumsForArtist:) func getAlbums(artist: SBArtist) {
        var params = parameters
        params["id"] = artist.id
        
        let url = URL.URLWith(string: server.url!, command: "rest/getMusicDirectory.view", parameters: params)
        request(url: url!, type: .getAlbumDirectory)
    }
    
    @objc(getCoverWithID:) func getCover(id: String) {
        var params = parameters
        params["id"] = id
        
        let url = URL.URLWith(string: server.url!, command: "rest/getCoverArt.view", parameters: params)
        request(url: url!, type: .getCoverArt) { operation in
            operation.currentCoverID = id
        }
    }
    
    @objc(getTracksForAlbumID:) func getTracks(albumID: String) {
        var params = parameters
        params["id"] = albumID
        
        let url = URL.URLWith(string: server.url!, command: "rest/getMusicDirectory.view", parameters: params)
        request(url: url!, type: .getTrackDirectory)
    }
    
    @objc func getPlaylists() {
        let url = URL.URLWith(string: server.url!, command: "rest/getPlaylists.view", parameters: parameters)
        request(url: url!, type: .getPlaylists)
    }
    
    @objc func getPlaylist(_ playlist: SBPlaylist) {
        var params = parameters
        params["id"] = playlist.id
        
        let url = URL.URLWith(string: server.url!, command: "rest/getPlaylist.view", parameters: params)
        request(url: url!, type: .getPlaylist)
    }
    
    @objc func getPodcasts() {
        let url = URL.URLWith(string: server.url!, command: "rest/getPodcasts.view", parameters: parameters)
        request(url: url!, type: .getPodcasts)
    }
    
    @objc(deletePlaylistWithID:) func deletePlaylist(id: String) {
        var params = parameters
        params["id"] = id
        
        let url = URL.URLWith(string: server.url!, command: "rest/deletePlaylist.view", parameters: params)
        request(url: url!, type: .deletePlaylist)
    }
    
    @objc(createPlaylistWithName:tracks:) func createPlaylist(name: String, tracks: [SBTrack]) {
        var params = parameters
        params["name"] = name
        
        // XXX: DRY this with update
        let allParams = params.map { (k, v) in  URLQueryItem(name: k, value: v) } +
            tracks.map { track in URLQueryItem(name: "songID", value: track.id) }
        
        let url = URL.URLWith(string: server.url!, command: "rest/createPlaylist.view", queryItems: allParams)
        request(url: url!, type: .createPlaylist)
    }
    
    @objc(updatePlaylistWithID:tracks:) func updatePlaylist(playlistID: String, tracks: [SBTrack]) {
        var params = parameters
        params["playlistId"] = playlistID
        
        let allParams = params.map { (k, v) in  URLQueryItem(name: k, value: v) } +
            tracks.map { track in URLQueryItem(name: "songID", value: track.id) }
        
        let url = URL.URLWith(string: server.url!, command: "rest/createPlaylist.view", queryItems: allParams)
        request(url: url!, type: .createPlaylist)
    }
    
    @objc(getAlbumListForType:) func getAlbumList(type: SBSubsonicRequestType) {
        var params = parameters
        switch type {
        case .getAlbumListRandom:
            params["type"] = "random"
        case .getAlbumListNewest:
            params["type"] = "newest"
        case .getAlbumListFrequent:
            params["type"] = "frequent"
        case .getAlbumListHighest:
            params["type"] = "highest"
        case .getAlbumListRecent:
            params["type"] = "recent"
        default:
            abort()
        }
        
        let url = URL.URLWith(string: server.url!, command: "rest/getAlbumList.view", parameters: params)
        request(url: url!, type: type)
    }
    
    @objc func getNowPlaying() {
        let url = URL.URLWith(string: server.url!, command: "rest/getNowPlaying.view", parameters: parameters)
        request(url: url!, type: .getNowPlaying)
    }
    
    @objc(getUserWithName:) func getUser(username: String) {
        var params = parameters
        params["username"] = username
        
        let url = URL.URLWith(string: server.url!, command: "rest/getUser.view", parameters: params)
        request(url: url!, type: .getUser)
    }
    
    @objc func search(_ query: String) {
        var params = parameters
        params["query"] = query
        params["songCount"] = "100" // XXX: Configurable? Pagination?
        
        let url = URL.URLWith(string: server.url!, command: "rest/search2.view", parameters: params)
        request(url: url!, type: .search) { operation in
            operation.currentSearch = SBSearchResult(query: query)
        }
    }
    
    @objc(setRating:forID:) func setRating(_ rating: Int, id: String) {
        var params = parameters
        params["rating"] = String(rating)
        params["id"] = id
        
        let url = URL.URLWith(string: server.url!, command: "rest/setRating.view", parameters: params)
        request(url: url!, type: .setRating)
    }
    
    @objc func scrobble(id: String) {
        var params = parameters
        params["id"] = id
        let currentTimeMS = Int64(Date().timeIntervalSince1970 * 1000)
        params["time"] = String(currentTimeMS)
        
        let url = URL.URLWith(string: server.url!, command: "rest/scrobble.view", parameters: params)
        request(url: url!, type: .scrobble)
    }
}

extension Dictionary {
    func mergedCopyFrom(dictionary: Dictionary) -> Dictionary {
        var new = self
        for (k, v) in dictionary {
            new[k] = v
        }
        return new
    }
}
