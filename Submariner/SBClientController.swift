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
    
    private func request(url: URL, type: SBSubsonicParsingOperation.RequestType, customization: ((SBSubsonicParsingOperation) -> Void)? = nil) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let request = URLRequest(url: url)
        // No auth header needed since we just pass them over query string
        
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
                // HTTP 404s are used for unsupported features in Subsonic and Navidrome,
                // but OC Music uses code 70 Subsonic responses
                if response.statusCode == 404 {
                    self.server.markNotSupported(feature: type)
                    return
                } else if response.statusCode == 429 {
                    // Newer versions of Navidrome back getCoverArt w/ third-party APIs.
                    // As such, it rate limits API requests that can invoke them.
                    // Instead of bothering the user, retry the request later.

                    // Retry-After is seconds or a specific date
                    let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                    logger.info("Retrying w/ Retry-After value \(retryAfter ?? "<nil>")")

                    if let retryAfter = retryAfter,
                       let specificDate = retryAfter.dateTimeFromHTTP() {
                        _ = Timer(fire: specificDate, interval: 0, repeats: false) { timer in
                            self.request(url: url, type: type, customization: customization)
                            timer.invalidate()
                        }
                    } else {
                        // handle if Retry-After is valid, invalid, or missing
                        let seconds = TimeInterval(retryAfter ?? "5") ?? 5
                        _ = Timer(timeInterval: seconds, repeats: false) { timer in
                            self.request(url: url, type: type, customization: customization)
                            timer.invalidate()
                        }
                    }
                    return
                } else if response.statusCode != 200 {
                    let message = "HTTP \(response.statusCode) for \(url.path)"
                    let userInfo = [NSLocalizedDescriptionKey: message]
                    // XXX: Right domain?
                    let error = NSError(domain: NSURLErrorDomain, code: response.statusCode, userInfo: userInfo)
                    DispatchQueue.main.async {
                        NSApp.presentError(error)
                    }
                    return
                }
                
                if let operation = SBSubsonicParsingOperation(managedObjectContext: self.managedObjectContext,
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
    
    // HACK: eat the nils here if some stupid nil happens,
    // without needing to change logic in real func or add ifs to all the callsites
    private func request(url: URL?, type: SBSubsonicParsingOperation.RequestType, customization: ((SBSubsonicParsingOperation) -> Void)? = nil) {
        if let url = url {
            request(url: url, type: type, customization: customization)
        } else {
            logger.error("URL was nil for request \(String(describing: type)), the server URL likely needs to be reset")
        }
    }
    
    // #MARK: - Request Messages
    
    @objc func connect(server: SBServer) {
        parameters = parameters.mergedCopyFrom(dictionary: server.getBaseParameters())
        let url = URL.URLWith(string: server.url, command: "rest/ping.view", parameters: parameters)
        request(url: url, type: .ping)
    }
    
    @objc func getLicense() {
        let url = URL.URLWith(string: server.url, command: "rest/getLicense.view", parameters: parameters)
        request(url: url, type: .getLicense)
    }
    
    func getArtists() {
        let url = URL.URLWith(string: server.url, command: "rest/getArtists.view", parameters: parameters)
        request(url: url, type: .getArtists)
    }
    
    func get(artist: SBArtist) {
        var params = parameters
        if artist.itemId == nil {
            // can happen because of now playing/search

            return
        }
        params["id"] = artist.itemId
        
        let url = URL.URLWith(string: server.url, command: "rest/getArtist.view", parameters: params)
        request(url: url, type: .getArtist) { operation in
            operation.currentArtistID = artist.itemId
        }
    }
    
    func getCover(id: String, for albumID: String? = nil) {
        var params = parameters
        params["id"] = id
        
        let url = URL.URLWith(string: server.url, command: "rest/getCoverArt.view", parameters: params)
        request(url: url, type: .getCoverArt) { operation in
            operation.currentCoverID = id
            operation.currentAlbumID = albumID
        }
    }
    
    func getTrack(trackID: String) {
        var params = parameters
        params["id"] = trackID
        
        let url = URL.URLWith(string: server.url, command: "rest/getSong.view", parameters: params)
        request(url: url, type: .getTrack)
    }
    
    func get(album: SBAlbum) {
        var params = parameters
        params["id"] = album.itemId
        
        let url = URL.URLWith(string: server.url, command: "rest/getAlbum.view", parameters: params)
        request(url: url, type: .getAlbum) { operation in
            operation.currentAlbumID = album.itemId
        }
    }
    
    @objc func getPlaylists() {
        let url = URL.URLWith(string: server.url, command: "rest/getPlaylists.view", parameters: parameters)
        request(url: url, type: .getPlaylists)
    }
    
    @objc func getPlaylist(_ playlist: SBPlaylist) {
        var params = parameters
        params["id"] = playlist.itemId
        
        let url = URL.URLWith(string: server.url, command: "rest/getPlaylist.view", parameters: params)
        request(url: url, type: .getPlaylist) { operation in
            operation.currentPlaylistID = playlist.itemId
        }
    }
    
    @objc func getPodcasts() {
        let url = URL.URLWith(string: server.url, command: "rest/getPodcasts.view", parameters: parameters)
        request(url: url, type: .getPodcasts)
    }
    
    @objc(deletePlaylistWithID:) func deletePlaylist(id: String) {
        var params = parameters
        params["id"] = id
        
        let url = URL.URLWith(string: server.url, command: "rest/deletePlaylist.view", parameters: params)
        request(url: url, type: .deletePlaylist) { operation in
            operation.currentPlaylistID = id
        }
    }
    
    @objc(createPlaylistWithName:tracks:) func createPlaylist(name: String, tracks: [SBTrack]) {
        var params = parameters
        params["name"] = name
        
        // XXX: DRY this with update
        let allParams = params.map { (k, v) in  URLQueryItem(name: k, value: v) } +
            tracks.map { track in URLQueryItem(name: "songId", value: track.itemId) }
        
        let url = URL.URLWith(string: server.url, command: "rest/createPlaylist.view", queryItems: allParams)
        request(url: url, type: .createPlaylist)
    }
    
    @objc(updatePlaylistWithID:tracks:) func updatePlaylist(playlistID: String, tracks: [SBTrack]) {
        var params = parameters
        params["playlistId"] = playlistID
        
        let allParams = params.map { (k, v) in  URLQueryItem(name: k, value: v) } +
            tracks.map { track in URLQueryItem(name: "songId", value: track.itemId) }
        
        let url = URL.URLWith(string: server.url, command: "rest/createPlaylist.view", queryItems: allParams)
        request(url: url, type: .updatePlaylist) { operation in
            operation.currentPlaylistID = playlistID
        }
    }
    
    func updatePlaylist(ID: String,
                        name: String? = nil,
                        comment: String? = nil,
                        isPublic: Bool? = nil,
                        appending: [SBTrack]? = nil,
                        removing: [Int]? = nil) {
        var params = parameters
        params["playlistId"] = ID
        if let name = name {
            params["name"] = name
        }
        if let comment = comment {
            params["comment"] = comment
        }
        if let isPublic = isPublic {
            params["public"] = "\(isPublic)"
        }
        
        let allParams = params.map { (k, v) in  URLQueryItem(name: k, value: v) } +
            (appending?.map { track in URLQueryItem(name: "songIdToAdd", value: track.itemId) } ?? []) +
            (removing?.map { index in URLQueryItem(name: "songIndexToRemove", value: "\(index)") } ?? [])
        
        let url = URL.URLWith(string: server.url, command: "rest/updatePlaylist.view", queryItems: allParams)
        request(url: url, type: .updatePlaylist) { operation in
            operation.currentPlaylistID = ID
        }
        
    }
    
    @objc(getAlbumListForType:) func getAlbumList(type: SBSubsonicParsingOperation.RequestType) {
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
            logger.error("getAlbumList type: unrecognized")
            abort()
        }
        
        let url = URL.URLWith(string: server.url, command: "rest/getAlbumList2.view", parameters: params)
        request(url: url, type: type)
    }
    
    @objc func getNowPlaying() {
        let url = URL.URLWith(string: server.url, command: "rest/getNowPlaying.view", parameters: parameters)
        request(url: url, type: .getNowPlaying)
    }
    
    @objc(getUserWithName:) func getUser(username: String) {
        var params = parameters
        params["username"] = username
        
        let url = URL.URLWith(string: server.url, command: "rest/getUser.view", parameters: params)
        request(url: url, type: .getUser)
    }
    
    @objc func search(_ query: String) {
        var params = parameters
        params["query"] = query
        params["songCount"] = "100" // XXX: Configurable? Pagination?
        
        let url = URL.URLWith(string: server.url, command: "rest/search3.view", parameters: params)
        request(url: url, type: .search) { operation in
            operation.currentSearch = SBSearchResult(query: query)
        }
    }
    
    @objc(setRating:forID:) func setRating(_ rating: Int, id: String) {
        var params = parameters
        params["rating"] = String(rating)
        params["id"] = id
        
        let url = URL.URLWith(string: server.url, command: "rest/setRating.view", parameters: params)
        request(url: url, type: .setRating)
    }
    
    @objc func scrobble(id: String) {
        var params = parameters
        params["id"] = id
        let currentTimeMS = Int64(Date().timeIntervalSince1970 * 1000)
        params["time"] = String(currentTimeMS)
        
        let url = URL.URLWith(string: server.url, command: "rest/scrobble.view", parameters: params)
        request(url: url, type: .scrobble)
    }
    
    @objc func scanLibrary() {
        let url = URL.URLWith(string: server.url, command: "rest/startScan.view", parameters: parameters)
        request(url: url, type: .getNowPlaying)
    }
    
    @objc func getScanStatus() {
        let url = URL.URLWith(string: server.url, command: "rest/getScanStatus.view", parameters: parameters)
        request(url: url, type: .getNowPlaying)
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
