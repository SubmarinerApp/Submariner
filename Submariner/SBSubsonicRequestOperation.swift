//
//  SBClientController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-06-13.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBSubsonicRequestOperation")

class SBSubsonicRequestOperation: SBOperation {
    typealias ParsingCustomization = ((SBSubsonicParsingOperation) -> Void)
    
    var server: SBServer!
    
    var parameters: [URLQueryItem] = []
    let request: SBSubsonicRequestType
    var customization: ParsingCustomization? = nil
    var endpoint: String! // XXX: Make into let
    // Note that POST method is supported by almost all servers, even Subsonic,
    // but OpenSubsonic API says to check for the extension first.
    let usesPost: Bool
    
    init(server: SBServer, request: SBSubsonicRequestType) {
        parameters = server.getBaseQueryItems()
        self.request = request
        
        // name is temporary, and we're on the same thread as what passed us this i hope
        let baseName = "Requesting from \(server.resourceName ?? "server")"
        self.usesPost = server.supportsFormPost.boolValue
        super.init(managedObjectContext: server.managedObjectContext!, name: baseName)
        self.server = threadedContext.object(with: server.objectID) as? SBServer
        
        buildUrl()
        
        DispatchQueue.main.async {
            self.name = "\(baseName): \(self.endpoint!)"
        }
    }
    
    // #MARK: - HTTP Requests
    
    private func buildFormParams() -> String {
        self.parameters.map { item in
            "\(item.name)=\(item.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }.joined(separator: "&")
    }
    
    private func request(url: URL, type: SBSubsonicRequestType, customization: ParsingCustomization? = nil) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url)
        if self.usesPost {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = self.buildFormParams().data(using: .utf8)
        }
        // No auth header needed since we just pass them over query string
        
        let task = session.dataTask(with: request) { data, response, error in
            if self.usesPost {
                logger.info("Handling POST URL \(url, privacy: .public)")
            } else {
                // sensitive because &p= contains user password
                logger.info("Handling URL \(url, privacy: .sensitive)")
                logger.info("\tAPI endpoint \(url.path, privacy: .public)")
            }
            
            defer { self.finish() }
            
            if let error = error {
                DispatchQueue.main.async {
                    NSApp.presentError(error)
                }
                return
            } else if let response = response as? HTTPURLResponse {
                logger.info("\tStatus code is \(response.statusCode)")
                // Note that Subsonic and Navidrome return app-level error bodies in HTTP 200
                switch (response.statusCode) {
                case 404, 410, 501:
                    // For unsupported features, it may vary. 404 is used for features that
                    // seem unknown to the server in Subsonic and Navidrome. Navidrome at least
                    // uses 501 for features that may be implemented in the future, and 410 for
                    // features that will never be implemented. OwnCloud Music returns a 200 with
                    // a code 70 Subsonic error instead, so we handle that in the response parser.
                    self.server.markNotSupported(feature: type)
                    return
                case 429:
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
                case 200: // OK, continue
                    break
                default:
                    let message = "HTTP \(response.statusCode) for \(url.path)"
                    let userInfo = [NSLocalizedDescriptionKey: message]
                    // XXX: Right domain?
                    let error = NSError(domain: NSURLErrorDomain, code: response.statusCode, userInfo: userInfo)
                    DispatchQueue.main.async {
                        NSApp.presentError(error)
                    }
                    return
                }
                
                if let operation = SBSubsonicParsingOperation(managedObjectContext: self.mainContext,
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
    
    override func main() {
        let queryParameters = self.usesPost ? [] : self.parameters
        guard let baseUrl = server.url else {
            logger.error("Base server URL was nil for request \(String(describing: self.request)), the server URL likely needs to be reset")
            self.finish()
            return
        }
        guard let url = URL.URLWith(string: baseUrl, command: "rest/\(endpoint!).view", parameters: queryParameters) else {
            logger.error("URL was nil for request \(String(describing: self.request)), the server URL likely needs to be reset")
            self.finish()
            return
        }
        
        request(url: url, type: self.request, customization: self.customization)
    }
    
    private func buildUrl() {
        switch request {
        case .ping:
            endpoint = "ping"
        case .getOpenSubsonicExtensions:
            endpoint = "getOpenSubsonicExtensions"
        case .getLicense:
            endpoint = "getLicense"
        case .getCoverArt(id: let id, forAlbumId: let albumId):
            parameters["id"] = id
            endpoint = "getCoverArt"
            customization = { operation in
                operation.currentCoverID = id
                operation.currentAlbumID = albumId
            }
        case .getPlaylists:
            endpoint = "getPlaylists"
        case .getAlbumList(type: let type):
            parameters["type"] = type.subsonicParameter()
            parameters["count"] = String(10)
            endpoint = "getAlbumList2"
        case .updateAlbumList(type: let type):
            parameters["type"] = type.subsonicParameter()
            parameters["count"] = String(10)
            parameters["offset"] = String(server.home?.albums?.count ?? 0)
            endpoint = "getAlbumList2"
        case .getPlaylist(id: let id):
            parameters["id"] = id
            endpoint = "getPlaylist"
            customization = { operation in
                operation.currentPlaylistID = id
            }
        case .deletePlaylist(id: let id):
            parameters["id"] = id
            endpoint = "deletePlaylist"
            customization = { operation in
                operation.currentPlaylistID = id
            }
        case .createPlaylist(name: let name, tracks: let tracks):
            parameters["name"] = name
            
            // XXX: DRY this with update
            parameters += tracks.map { track in URLQueryItem(name: "songId", value: track.itemId) }
            
            endpoint = "createPlaylist"
        case .getNowPlaying:
            endpoint = "getNowPlaying"
        case .search(query: let query):
            parameters["query"] = query
            parameters["songCount"] = "100" // XXX: Configurable?
            endpoint = "search3"
            customization = { operation in
                operation.currentSearch = SBSearchResult(query: .search(query: query))
            }
        case .updateSearch(existingResult: let existingResult):
            switch existingResult.query {
            case .search(let query):
                parameters["query"] = query
                parameters["songCount"] = "100"
                parameters["songOffset"] = String(existingResult.tracks.count)
                endpoint = "search3"
            default: // shouldn't happen
                break
            }
            existingResult.returnedTracks = 0
            customization = { operation in
                operation.currentSearch = existingResult
            }
        case .setRating(id: let id, rating: let rating):
            parameters["rating"] = String(rating)
            parameters["id"] = id
            endpoint = "setRating"
        case .getPodcasts:
            endpoint = "getPodcasts"
        case .scrobble(id: let id):
            parameters["id"] = id
            let currentTimeMS = Int64(Date().timeIntervalSince1970 * 1000)
            parameters["time"] = String(currentTimeMS)
            endpoint = "scrobble"
        case .scanLibrary:
            endpoint = "startScan"
        case .getScanStatus:
            endpoint = "getScanStatus"
        case .replacePlaylist(id: let id, tracks: let tracks):
            parameters["playlistId"] = id
            
            parameters += tracks.map { track in URLQueryItem(name: "songId", value: track.itemId) }
            
            endpoint = "createPlaylist"
            customization = { operation in
                operation.currentPlaylistID = id
            }
        case .updatePlaylist(id: let id, name: let name, comment: let comment, isPublic: let isPublic, appending: let appending, removing: let removing):
            parameters["playlistId"] = id
            if let name = name {
                parameters["name"] = name
            }
            if let comment = comment {
                parameters["comment"] = comment
            }
            if let isPublic = isPublic {
                parameters["public"] = "\(isPublic)"
            }
            
            parameters += appending?.map { track in URLQueryItem(name: "songIdToAdd", value: track.itemId) } ?? []
            parameters += removing?.map { index in URLQueryItem(name: "songIndexToRemove", value: "\(index)") } ?? []
            
            endpoint = "updatePlaylist"
            customization = { operation in
                operation.currentPlaylistID = id
            }
        case .getArtists:
            endpoint = "getArtists"
        case .getArtist(id: let id):
            parameters["id"] = id
            endpoint = "getArtist"
            customization = { operation in
                operation.currentArtistID = id
            }
        case .getAlbum(id: let id):
            parameters["id"] = id
            endpoint = "getAlbum"
            customization = { operation in
                operation.currentAlbumID = id
            }
        case .getTrack(id: let id):
            parameters["id"] = id
            endpoint = "getSong"
        case .getDirectories:
            // XXX: there is a lastIndexDate param but since the changeover to ID3 tag primary, that's not relevant anymore
            endpoint = "getIndexes"
        case .getDirectory(id: let id):
            parameters["id"] = id
            endpoint = "getMusicDirectory"
        case .star(tracks: let tracks, albums: let albums, artists: let artists, directories: let directories):
            parameters += tracks.map { track in URLQueryItem(name: "id", value: track.itemId) }
            parameters += directories.map { track in URLQueryItem(name: "id", value: track.itemId) }
            parameters += albums.map { album in URLQueryItem(name: "albumId", value: album.itemId) }
            parameters += artists.map { artist in URLQueryItem(name: "artistId", value: artist.itemId) }
            endpoint = "star"
        case .unstar(tracks: let tracks, albums: let albums, artists: let artists, directories: let directories):
            parameters += tracks.map { track in URLQueryItem(name: "id", value: track.itemId) }
            parameters += directories.map { track in URLQueryItem(name: "id", value: track.itemId) }
            parameters += albums.map { album in URLQueryItem(name: "albumId", value: album.itemId) }
            parameters += artists.map { artist in URLQueryItem(name: "artistId", value: artist.itemId) }
            endpoint = "unstar"
        case .getTopTracks(let artistName):
            parameters["artist"] = artistName
            endpoint = "getTopSongs"
            customization = { operation in
                operation.currentSearch = SBSearchResult(query: .topTracksFor(artistName: artistName))
            }
        case .getSimilarTracks(let artist):
            parameters["id"] = artist.itemId
            endpoint = "getSimilarSongs2"
            customization = { operation in
                operation.currentSearch = SBSearchResult(query: .similarTo(artist: artist))
            }
        }
    }
}
