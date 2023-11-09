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

extension NSNotification.Name{
    static let SBSubsonicConnectionFailed = NSNotification.Name("SBSubsonicConnectionFailedNotification")
    static let SBSubsonicConnectionSucceeded = NSNotification.Name("SBSubsonicConnectionSucceededNotification")
    static let SBSubsonicIndexesUpdated = NSNotification.Name("SBSubsonicIndexesUpdatedNotification")
    static let SBSubsonicAlbumsUpdated = NSNotification.Name("SBSubsonicAlbumsUpdatedNotification")
    static let SBSubsonicTracksUpdated = NSNotification.Name("SBSubsonicTracksUpdatedNotification")
    // "SBSubsonicCoversUpdatedNotification" defined elsewhere
    static let SBSubsonicPlaylistsUpdated = NSNotification.Name("SBSubsonicPlaylistsUpdatedNotification")
    static let SBSubsonicPlaylistUpdated = NSNotification.Name("SBSubsonicPlaylistUpdatedNotification")
    static let SBSubsonicNowPlayingUpdated = NSNotification.Name("SBSubsonicNowPlayingUpdatedNotification")
    static let SBSubsonicUserInfoUpdated = NSNotification.Name("SBSubsonicUserInfoUpdatedNotification")
    static let SBSubsonicPlaylistsCreated = NSNotification.Name("SBSubsonicPlaylistsCreatedNotification")
    static let SBSubsonicSearchResultUpdated = NSNotification.Name("SBSubsonicSearchResultUpdatedNotification")
    static let SBSubsonicPodcastsUpdated = NSNotification.Name("SBSubsonicPodcastsUpdatedNotification")
    static let SBSubsonicLibraryScanDone = NSNotification.Name("SBSubsonicLibraryScanDone")
    static let SBSubsonicLibraryScanProgress = NSNotification.Name("SBSubsonicLibraryScanProgress")
}

class SBSubsonicParsingOperation: SBOperation, XMLParserDelegate {
    @objc(SBSubsonicRequestType) enum RequestType: Int {
        @objc(SBSubsonicRequestUnknown) case unknown = -1
        @objc(SBSubsonicRequestPing) case ping = 0
        @objc(SBSubsonicRequestGetLicence) case getLicense = 1 // XXX: Duplicated 24?
        @objc(SBSubsonicRequestGetMusicFolders) case getMusicFolders = 2
        @objc(SBSubsonicRequestGetIndexes) case getIndexes = 3
        @objc(SBSubsonicRequestGetMusicDirectory) case getMusicDirectory = 4
        @objc(SBSubsonicRequestGetAlbumDirectory) case getAlbumDirectory = 5
        @objc(SBSubsonicRequestGetTrackDirectory) case getTrackDirectory = 6
        @objc(SBSubsonicRequestGetCoverArt) case getCoverArt = 7
        @objc(SBSubsonicRequestStream) case requestStream = 8
        @objc(SBSubsonicRequestGetPlaylists) case getPlaylists = 9
        @objc(SBSubsonicRequestGetAlbumListRandom) case getAlbumListRandom = 10
        @objc(SBSubsonicRequestGetAlbumListNewest) case getAlbumListNewest = 11
        @objc(SBSubsonicRequestGetAlbumListHighest) case getAlbumListHighest = 12
        @objc(SBSubsonicRequestGetAlbumListFrequent) case getAlbumListFrequent = 13
        @objc(SBSubsonicRequestGetAlbumListRecent) case getAlbumListRecent = 14
        @objc(SBSubsonicRequestGetPlaylist) case getPlaylist = 15
        @objc(SBSubsonicRequestDeletePlaylist) case deletePlaylist = 16
        @objc(SBSubsonicRequestCreatePlaylist) case createPlaylist = 17
        @objc(SBSubsonicRequestGetChatMessages) case getChatMessages = 18
        @objc(SBSubsonicRequestAddChatMessage) case addChatMessage = 19
        @objc(SBSubsonicRequestGetNowPlaying) case getNowPlaying = 20
        @objc(SBSubsonicRequestGetUser) case getUser = 21
        @objc(SBSubsonicRequestSearch) case search = 22
        @objc(SBSubsonicRequestSetRating) case setRating = 23
        @objc(SBSubsonicRequestGetPodcasts) case getPodcasts = 25
        @objc(SBSubsonicRequestSetScrobble) case scrobble = 26
        @objc(SBSubsonicRequestScanLibrary) case scanLibrary = 27
        @objc(SBSubsonicRequestGetScanStatus) case getScanStatus = 28
        @objc(SBSubsonicRequestUpdatePlaylist) case updatePlaylist = 29
        @objc(SBSubsonicRequestGetArtists) case getArtists = 30
        @objc(SBSubsonicRequestGetArtist) case getArtist = 31
        @objc(SBSubsonicRequestGetAlbum) case getAlbum = 32
    }
    
    let clientController: SBClientController
    let requestType: RequestType
    var server: SBServer
    let xmlData: Data?
    let mimeType: String?
    
    // state
    var errored: Bool = false
    var playlistIndex: Int = 0
    
    // state for selected object
    var currentPlaylist: SBPlaylist?
    var currentArtist: SBArtist?
    var currentAlbum: SBAlbum?
    var currentPodcast: SBPodcast?
    var currentSearch: SBSearchResult?
    
    var currentPlaylistID: String?
    var currentArtistID: String?
    var currentAlbumID: String?
    var currentCoverID: String?
    
    init!(managedObjectContext mainContext: NSManagedObjectContext!,
          client: SBClientController,
          requestType: RequestType,
          server: NSManagedObjectID,
          xml: Data?,
          mimeType: String?) {
        self.requestType = requestType
        self.clientController = client
        // HACK: we need to throw this away, so we can reinit with threadedContext from SBOperation
        self.server = mainContext.object(with: server) as! SBServer
        self.xmlData = xml
        self.mimeType = mimeType
        
        super.init(managedObjectContext: mainContext, name: "Parsing Subsonic Request")
        self.server = threadedContext.object(with: server) as! SBServer
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
        errored = true
        if attributeDict["code"] == "70" { // Not found
            // delete the object we're requesting since it doesn't exist
            // that, or we need to mark the feature as unsupported so we don't do it again
            // (which is cleared on restart of app)
            if let message = attributeDict["message"], message.contains("not supported") {
                server.markNotSupported(feature: requestType)
                // if it's unsupported we don't need to go through with the rest
                return
            }
            
            if let currentPlaylistID = self.currentPlaylistID, let playlistToDelete = fetchPlaylist(id: currentPlaylistID) {
                threadedContext.delete(playlistToDelete)
            } else if let currentArtistID = self.currentArtistID, let artistToDelete = fetchArtist(id: currentArtistID) {
                threadedContext.delete(artistToDelete)
            } else if let currentAlbumID = self.currentAlbumID, let albumToDelete = fetchAlbum(id: currentAlbumID) {
                threadedContext.delete(albumToDelete)
            }
            // XXX: Cover, podcast, track? Do we need to remove it from any sets?
        }
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
            logger.info("Creating new index group: \(indexName, privacy: .public)")
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
            // for cases where we have artists without IDs from i.e. getNowPlaying/search2
            if let existingArtist = fetchArtist(name: name) {
                existingArtist.itemId = id
                // as we don't do it in updateTrackDependencies
                server.addToIndexes(existingArtist)
                return
            }
            logger.info("Creating new artist with ID: \(id, privacy: .public) and name \(name, privacy: .public)")
            // we don't do anything with the return value since it gets put into core data
            let artist = createArtist(attributes: attributeDict)
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
            var album = fetchAlbum(id: id)
            if album == nil {
                logger.info("Creating new album with ID: \(id, privacy: .public) and name \(name, privacy: .public)")
                album = createAlbum(attributes: attributeDict)
                // now assume not nil
            }
            album!.artist = currentArtist
            currentArtist.addToAlbums(album!)
            
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
                logger.info("Creating new cover with ID: \(coverID, privacy: .public) for album ID \(id, privacy: .public)")
                let cover = createCover(attributes: attributeDict)
                cover.album = album!
                album!.cover = cover
            }
            
            // now fetch that cover after we initialized one
            if let cover = album!.cover, let coverID = cover.itemId,
               (cover.imagePath == nil || !FileManager.default.fileExists(atPath: cover.imagePath! as String)) {
                // file doesn't exist, fetch it
                logger.info("Fetching file for cover with ID: \(coverID, privacy: .public)")
                clientController.getCover(id: coverID)
            }
        }
    }
    
    private func parseElementChildForTrackDirectory(attributeDict: [String: String]) {
        if let currentAlbum = self.currentAlbum, attributeDict["isDir"] == "false",
           let id = attributeDict["id"], let name = attributeDict["title"] {
            if let track = fetchTrack(id: id)  {
                // Update
                logger.info("Updating track with ID: \(id, privacy: .public) and name \(name, privacy: .public)")
                updateTrack(track, attributes: attributeDict)
                track.album = currentAlbum
                currentAlbum.addToTracks(track)
            } else {
                // Create
                logger.info("Creating new track with ID: \(id, privacy: .public) and name \(name, privacy: .public)")
                let track = createTrack(attributes: attributeDict)
                // now assume not nil
                track.album = currentAlbum
                currentAlbum.addToTracks(track)
            }
        }
    }
    
    private func parseElementChild(attributeDict: [String: String]) {
        if requestType == .getAlbumDirectory {
            parseElementChildForAlbumDirectory(attributeDict: attributeDict)
        } else if requestType == .getTrackDirectory {
            parseElementChildForTrackDirectory(attributeDict: attributeDict)
        } else {
            logger.warning("Invalid request type \(self.requestType.rawValue, privacy: .public) for child element")
        }
    }
    
    private func parseElementAlbumList(attributeDict: [String: String]) {
        // Clear the ServerHome controller
        server.home?.albums = nil
    }
    
    private func parseElementAlbum(attributeDict: [String: String]) {
        // We must have a parent (artist) to assign to.
        // Use tag based approach; getAlbumList2 and search3 use this.
        if let artistId = attributeDict["artistId"], let id = attributeDict["id"] {
            var artist = fetchArtist(id: artistId)
            if artist == nil {
                // handles the different context fine
                logger.info("Creating new artist with ID: \(artistId, privacy: .public) for album ID \(id, privacy: .public)")
                artist = createArtist(attributes: attributeDict)
            }
            
            var album = fetchAlbum(id: id)
            if album == nil {
                logger.info("Creating new album with ID: \(id, privacy: .public) for artist ID \(artistId, privacy: .public)")
                album = createAlbum(attributes: attributeDict)
            }
            
            // for future song elements under this one
            if requestType == .getAlbum {
                currentAlbum = album
            }
            
            if album!.artist == nil {
                album!.artist = artist
                artist?.addToAlbums(album!)
            }
            server.home?.addToAlbums(album!)
            album!.home = server.home
            
            if let coverArt = attributeDict["coverArt"] {
                if album?.cover == nil {
                    logger.info("Creating new cover with ID: \(coverArt, privacy: .public) for album ID \(id, privacy: .public)")
                    let cover = createCover(attributes: attributeDict)
                    cover.album = album
                    album!.cover = cover
                }
                
                if album?.cover?.imagePath == nil {
                    clientController.getCover(id: coverArt)
                }
            }
        }
    }
    
    private func parseElementPlaylist(attributeDict: [String: String]) {
        if requestType == .getPlaylists,
           let id = attributeDict["id"], let name = attributeDict["name"] {
            var playlist = fetchPlaylist(id: id)
            if playlist == nil {
                logger.info("Failed to fetch playlist ID \(id, privacy: .public), trying name \(name, privacy: .public)")
                playlist = fetchPlaylist(name: name)
            }
            if playlist == nil {
                logger.info("Creating playlist with ID \(id, privacy: .public), trying name \(name, privacy: .public)")
                playlist = createPlaylist(attributes: attributeDict)
            } else if let playlist = playlist {
                // we have an existing playlist, update it
                updatePlaylist(playlist, attributes: attributeDict)
            }
        } else if requestType == .getPlaylist, let id = attributeDict["id"] {
            currentPlaylist = fetchPlaylist(id: id)
        } else {
            logger.warning("Invalid request type \(self.requestType.rawValue, privacy: .public) for playlist element")
        }
    }
    
    private func parseElementEntryForPlaylist(attributeDict: [String: String]) {
        if let currentPlaylist = self.currentPlaylist, let id = attributeDict["id"] {
            if let track = fetchTrack(id: id) {
                let exists = currentPlaylist.tracks?.contains { (playlistTrack: SBTrack) in
                    return track.itemId == playlistTrack.itemId
                } ?? false
                logger.info("Adding track (and updating) with ID: \(id, privacy: .public) to playlist \(currentPlaylist.itemId ?? "(no ID?)", privacy: .public), exists? \(exists) index? \(self.playlistIndex)")
                
                updateTrackDependenciesForDirectoryIndex(track, attributeDict: attributeDict, shouldFetchAlbumArt: false)
                
                // limitation if the same track exists twice
                track.playlistIndex = NSNumber(value: playlistIndex)
                playlistIndex += 1
                
                if !exists {
                    currentPlaylist.addToTracks(track)
                    track.playlist = currentPlaylist
                }
            } else {
                // if the track doesn't exist yet, it'll be born without context. provide that context (artist/album/cover)
                // FIXME: Should we update *existing* tracks regardless? For previous cases they were pulled anew...
                logger.info("Creating new track with ID: \(id, privacy: .public) for playlist \(currentPlaylist.itemId ?? "(no ID?)", privacy: .public)")
                let track = createTrack(attributes: attributeDict)
                updateTrackDependenciesForDirectoryIndex(track, attributeDict: attributeDict, shouldFetchAlbumArt: false)
                
                track.playlistIndex = NSNumber(value: playlistIndex)
                playlistIndex += 1
                
                currentPlaylist.addToTracks(track)
                track.playlist = currentPlaylist
            }
        } else {
            logger.warning("No current playlist, even though we have an entry element?")
        }
    }
    
    private func parseElementEntryForNowPlaying(attributeDict: [String: String]) {
        // Ignore it if it isn't music - podcasts don't return their podcast metadata,
        // but ID3 as if they were a track in the music library. The resulting track
        // is weird and malformed.
        if let type = attributeDict["type"], type != "music" {
            logger.info("Ignoring now playing entry for non-music")
            return
        }
        
        // XXX: really weird for more than track since we can't use the normal constuctors we have in the class
        let nowPlaying = createNowPlaying(attributes: attributeDict)
        var attachedTrack: SBTrack?
        
        if let id = attributeDict["id"] {
            attachedTrack = fetchTrack(id: id)
            if attachedTrack == nil {
                logger.info("Creating track ID \(id, privacy: .public) for now playing entry")
                attachedTrack = createTrack(attributes: attributeDict)
            }
        }
        nowPlaying.track = attachedTrack
        attachedTrack?.nowPlaying = nowPlaying
        
        updateTrackDependenciesForTag(attachedTrack!, attributeDict: attributeDict)
        
        // do it here
        nowPlaying.server = server
        server.addToNowPlayings(nowPlaying)
    }
    
    private func parseElementEntry(attributeDict: [String: String]) {
        if requestType == .getPlaylist {
            parseElementEntryForPlaylist(attributeDict: attributeDict)
        } else if requestType == .getNowPlaying {
            parseElementEntryForNowPlaying(attributeDict: attributeDict)
        } else {
            logger.warning("Invalid request type \(self.requestType.rawValue, privacy: .public) for entry element")
        }
    }
    
    private func parseElementSong(attributeDict: [String: String]) {
        if let currentSearch = self.currentSearch, let id = attributeDict["id"] {
            if let track = fetchTrack(id: id) {
                logger.info("Creating track ID \(id, privacy: .public) for search")
                // the song element has the same format as the one used in nowPlaying, complete with artist name without ID
                updateTrackDependenciesForTag(track, attributeDict: attributeDict)
                // objc version did some check in playlist, which didn't make sense
                currentSearch.tracksToFetch.append(track.objectID)
            } else {
                logger.info("Creating track ID \(id, privacy: .public) for search")
                let track = createTrack(attributes: attributeDict)
                updateTrackDependenciesForTag(track, attributeDict: attributeDict)
                currentSearch.tracksToFetch.append(track.objectID)
            }
        } else if let currentAlbum = self.currentAlbum, let id = attributeDict["id"], let name = attributeDict["title"] {
            // like parseElementChildForTrackDirectory; shouldn't need to call update dependencies...
            if let track = fetchTrack(id: id)  {
                // Update
                logger.info("Updating track with ID: \(id, privacy: .public) and name \(name, privacy: .public)")
                updateTrack(track, attributes: attributeDict)
                track.album = currentAlbum
                currentAlbum.addToTracks(track)
            } else {
                // Create
                logger.info("Creating new track with ID: \(id, privacy: .public) and name \(name, privacy: .public)")
                let track = createTrack(attributes: attributeDict)
                // now assume not nil
                track.album = currentAlbum
                currentAlbum.addToTracks(track)
            }
        } else {
            logger.warning("Song ID was nil for get album or search")
        }
    }
    
    private func parseElementLicense(attributeDict: [String: String]) {
        if let validString = attributeDict["valid"] {
            server.isValidLicense = NSNumber(value: validString == "true")
        }
        // note that these can be empty which can confuse user if we don't set them
        if let email = attributeDict["email"] {
            server.licenseEmail = email
        } else {
            server.licenseEmail = ""
        }
        if let date = attributeDict["date"]?.dateTimeFromISO() {
            server.licenseDate = date
        } else {
            server.licenseDate = Date()
        }
    }
    
    private func parseElementChannel(attributeDict: [String: String]) {
        if let id = attributeDict["id"] {
            var podcast = fetchPodcast(id: id)
            if podcast == nil {
                logger.info("Creating podcast ID \(id, privacy: .public)")
                podcast = createPodcast(attributes: attributeDict)
            }
            
            currentPodcast = podcast
        }
    }
    
    private func parseElementScanStatus(attributeDict: [String: String]) {
        // Navidrome extends the Subsonic schema with lastScan (date) and folderCount (int)
        if let scanningString = attributeDict["scanning"] {
            // The initial scan starts with false, it seems
            if scanningString == "true" || requestType == .scanLibrary {
                // FIXME: include "count" and others in a message
                postServerNotification(.SBSubsonicLibraryScanProgress)
            } else {
                postServerNotification(.SBSubsonicLibraryScanDone)
            }
        }
    }
    
    private func parseElementEpisode(attributeDict: [String: String]) {
        if let currentPodcast = self.currentPodcast, let id = attributeDict["id"] {
            var episode = fetchEpisode(id: id)
            if episode != nil {
                logger.info("Creating episode ID \(id, privacy: .public)")
                episode = createEpisode(attributes: attributeDict)
            }
            
            if currentPodcast.episodes?.contains(episode!) == true && attributeDict["status"] == episode?.episodeStatus {
                // FIXME: This seems very bad, we should update the object instead (convert createEpisode to updateEpisode)
                currentPodcast.removeFromEpisodes(episode!)
                episode = createEpisode(attributes: attributeDict)
                currentPodcast.addToEpisodes(episode!)
            } else {
                currentPodcast.addToEpisodes(episode!)
            }
            
            // FIXME: yeah, this is how it was before, it doesn't make much sense
            if let streamID = attributeDict["streamId"] {
                var track = fetchTrack(id: streamID)
                if track == nil, let albumID = attributeDict["parent"] {
                    clientController.getTracks(albumID: albumID)
                } else {
                    episode!.track = track
                }
            }
            
            // there was some commented out stuff for covers, who knows if it ever works
        }
    }
    
    // #MARK: - XML delegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        logger.debug("Encountered XML element \(elementName, privacy: .public)")
        if elementName == "subsonic-response" {
            parseElementSubsonicResponse(attributeDict: attributeDict)
        } else if elementName == "error" {
            parseElementError(attributeDict: attributeDict)
        } else if elementName == "indexes" || elementName == "artists" { // directory or tag based index...
            parseElementIndexes(attributeDict: attributeDict)
        } else if elementName == "index" { // build group index
            parseElementIndex(attributeDict: attributeDict)
        } else if elementName == "artist" { // build artist index
            parseElementArtist(attributeDict: attributeDict)
        } else if elementName == "directory" { // a directory...
            parseElementDirectory(attributeDict: attributeDict)
        } else if elementName == "child" { // ...and a directory's child item
            parseElementChild(attributeDict: attributeDict)
        } else if elementName == "albumList" || elementName == "albumList2" { // the ServerHome controller's album list...
            parseElementAlbumList(attributeDict: attributeDict)
        } else if elementName == "album" { // ...and its albums
            parseElementAlbum(attributeDict: attributeDict)
        } else if elementName == "playlists" {
            // nothing anymore
        } else if elementName == "playlist" {
            parseElementPlaylist(attributeDict: attributeDict)
        } else if elementName == "entry" { // for playlist or now playing
            parseElementEntry(attributeDict: attributeDict)
        } else if elementName == "user" {
            // XXX: do parsing here?
            NotificationCenter.default.post(name: .SBSubsonicUserInfoUpdated, object: attributeDict)
        } else if elementName == "song" { // search2 results
            parseElementSong(attributeDict: attributeDict)
        } else if elementName == "license" {
            parseElementLicense(attributeDict: attributeDict)
        } else if elementName == "channel" {
            parseElementChannel(attributeDict: attributeDict)
        } else if elementName == "episode" {
            parseElementEpisode(attributeDict: attributeDict)
        } else if elementName == "nowPlaying" {
            // nop
        } else if elementName == "scanStatus" {
            parseElementScanStatus(attributeDict: attributeDict)
        } else {
            logger.error("Unknown XML element \(elementName, privacy: .public), attributes \(attributeDict, privacy: .public)")
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "podcast" {
            currentPodcast = nil
        } else if elementName == "playlist" {
            playlistIndex = 0
        }
    }
    
    private func postServerNotification(_ notificationName: NSNotification.Name) {
        NotificationCenter.default.post(name: notificationName, object: server.objectID)
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        logger.info("Finished XML processing")
        threadedContext.processPendingChanges()
        saveThreadedContext()
        
        if requestType == .ping && !errored {
            postServerNotification(.SBSubsonicConnectionSucceeded)
        } else if requestType == .updatePlaylist {
            postServerNotification(.SBSubsonicPlaylistUpdated)
        } else if requestType == .createPlaylist {
            postServerNotification(.SBSubsonicPlaylistsCreated)
        } else if requestType == .getIndexes {
            postServerNotification(.SBSubsonicIndexesUpdated)
        } else if requestType == .getAlbumDirectory {
            postServerNotification(.SBSubsonicAlbumsUpdated)
        } else if requestType == .getTrackDirectory {
            postServerNotification(.SBSubsonicTracksUpdated)
        } else if requestType == .getPlaylists {
            postServerNotification(.SBSubsonicPlaylistsUpdated)
        } else if requestType == .getPlaylist {
            currentPlaylist = nil
        } else if requestType == .getNowPlaying {
            postServerNotification(.SBSubsonicNowPlayingUpdated)
        } else if requestType == .search {
            NotificationCenter.default.post(name: .SBSubsonicSearchResultUpdated, object: currentSearch)
        } else if requestType == .getPodcasts {
            postServerNotification(.SBSubsonicPodcastsUpdated)
        }
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
        fetchRequest.predicate = NSPredicate(format: "(itemId == %@) && (server == %@)", id, server)
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
            fetchRequest.predicate = NSPredicate(format: "(itemId == %@) && (artist == %@)", id, artist)
        } else {
            fetchRequest.predicate = NSPredicate(format: "(itemId == %@)", id)
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
        fetchRequest.predicate = NSPredicate(format: "(itemId == %@)", coverID)
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchTrack(id: String, album: SBAlbum? = nil) -> SBTrack? {
        let fetchRequest = NSFetchRequest<SBTrack>(entityName: "Track")
        if let album = album {
            fetchRequest.predicate = NSPredicate(format: "(server == %@) && (itemId == %@) && (album == %@)", server, id, album)
        } else {
            fetchRequest.predicate = NSPredicate(format: "(server == %@) && (itemId == %@)", server, id)
        }
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchPlaylist(id: String) -> SBPlaylist? {
        let fetchRequest = NSFetchRequest<SBPlaylist>(entityName: "Playlist")
        fetchRequest.predicate = NSPredicate(format: "(itemId == %@) && (server == %@)", id, server)
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchPlaylist(name: String) -> SBPlaylist? {
        let fetchRequest = NSFetchRequest<SBPlaylist>(entityName: "Playlist")
        fetchRequest.predicate = NSPredicate(format: "(resourceName == %@) && (server == %@)", name, server)
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchPodcast(id: String) -> SBPodcast? {
        let fetchRequest = NSFetchRequest<SBPodcast>(entityName: "Podcast")
        fetchRequest.predicate = NSPredicate(format: "(itemId == %@) && (server == %@)", id, server)
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchEpisode(id: String) -> SBEpisode? {
        let fetchRequest = NSFetchRequest<SBEpisode>(entityName: "Episode")
        fetchRequest.predicate = NSPredicate(format: "(itemId == %@) && (server == %@)", id, server)
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
        
        // note that for the <album> context it has both the artist and album in the same element,
        // but this should override that. it may be worth making the context an arg to make sure
        // instead of relying on overrides though
        if let name = attributes["name"] {
            artist.itemName = name
        }
        // in album element context
        if let artistName = attributes["artist"] {
            artist.itemName = artistName
        }
        
        if let id = attributes["id"] {
            artist.itemId = id
        }
        // in album element context
        if let id = attributes["artistId"] {
            artist.itemId = id
        }
        
        artist.isLocal = false
        server.addToIndexes(artist)
        artist.server = server
        
        return artist
    }
    
    private func createAlbum(attributes: [String: String]) -> SBAlbum {
        let album = SBAlbum.insertInManagedObjectContext(context: threadedContext)
        
        // ID3 based routes use name instead of title
        if let name = attributes["name"] {
            album.itemName = name
        }
        
        if let id = attributes["id"] {
            album.itemId = id
        }
        
        // don't assume cover yet
        
        album.isLocal = false
        
        return album
    }
    
    // NOT USED YET - this makes sense only if you're using the tag based APIs
    private func updateTrackDependenciesForTag(_ track: SBTrack, attributeDict: [String: String], shouldFetchAlbumArt: Bool = true) {
        var attachedArtist: SBArtist?
        // is this right for album artist? the artist object can get corrected on fetch though...
        if let artistID = attributeDict["artistId"] {
            attachedArtist = fetchArtist(id: artistID)
            if attachedArtist == nil, let artistName = attributeDict["artist"] {
                logger.info("Creating artist ID \(artistID, privacy: .public) for tag based entry")
                attachedArtist = SBArtist.insertInManagedObjectContext(context: threadedContext)
                // this special case isn't as bad as Now Playing
                attachedArtist!.itemId = artistID
                attachedArtist!.itemName = artistName
                attachedArtist!.isLocal = false
                attachedArtist!.server = server
                server.addToIndexes(attachedArtist!)
            }
        }
        
        var attachedAlbum: SBAlbum?
        // same idea
        if let albumID = attributeDict["albumId"] {
            attachedAlbum = fetchAlbum(id: albumID, artist: attachedArtist)
            if attachedAlbum == nil, let albumName = attributeDict["albumName"] {
                logger.info("Creating album ID \(albumID, privacy: .public) for tag based entry")
                // XXX: Lack of ID seems like it'll be agony
                attachedAlbum = SBAlbum.insertInManagedObjectContext(context: threadedContext)
                attachedAlbum!.itemId = albumID
                attachedAlbum!.itemName = albumName
                attachedAlbum!.isLocal = false
                if let attachedArtist = attachedArtist {
                    attachedAlbum?.artist = attachedArtist
                    attachedArtist.addToAlbums(attachedAlbum!)
                }
                
                server.home?.addToAlbums(attachedAlbum!)
                attachedAlbum!.home = server.home
            }
        }
        
        // the track doesn't need to know this, so scope doesn't matter
        if let attachedAlbum = attachedAlbum, let coverID = attributeDict["coverArt"] {
            var attachedCover: SBCover?
            
            attachedCover = fetchCover(coverID: coverID)
            
            if attachedCover?.itemId == nil || attachedCover?.itemId == "" {
                logger.info("Creating cover ID \(coverID, privacy: .public) for tag based entry")
                attachedCover = createCover(attributes: attributeDict)
                attachedCover!.album = attachedAlbum
                attachedAlbum.cover = attachedCover!
            }
            
            if shouldFetchAlbumArt {
                clientController.getCover(id: coverID)
            }
        }
        
        if let attachedAlbum = attachedAlbum {
            attachedAlbum.addToTracks(track)
            track.album = attachedAlbum
        }
    }
    
    // not as good as former, but we have to use it until we switch to using tag based metadata instead of hierarchy index
    private func updateTrackDependenciesForDirectoryIndex(_ track: SBTrack, attributeDict: [String: String], shouldFetchAlbumArt: Bool = true) {
        var attachedAlbum: SBAlbum?
        var attachedCover: SBCover?
        var attachedArtist: SBArtist?
        
        // set these if not already set (prev versions might not have for tracks where first seen was from now playing/search)
        if let albumID = attributeDict["parent"] {
            // we might not have the artist here to attach to
            attachedAlbum = fetchAlbum(id: albumID)
            if attachedAlbum == nil {
                logger.info("Creating album ID \(albumID, privacy: .public) for index based entry")
                // not using normal construction
                attachedAlbum = SBAlbum.insertInManagedObjectContext(context: threadedContext)
                attachedAlbum?.itemId = albumID
                if let name = attributeDict["album"] {
                    attachedAlbum?.itemName = name
                }
                attachedAlbum?.isLocal = false
                
                attachedAlbum?.addToTracks(track)
                track.album = attachedAlbum
                
                // XXX: do this here?
                server.home?.addToAlbums(attachedAlbum!)
                attachedAlbum!.home = server.home
            } else if track.album == nil {
                attachedAlbum?.addToTracks(track)
                track.album = attachedAlbum
            }
        }
        
        if let attachedAlbum = attachedAlbum, let coverID = attributeDict["coverArt"] {
            attachedCover = fetchCover(coverID: coverID)
            
            if attachedCover?.itemId == nil || attachedCover?.itemId == "" {
                logger.info("Creating cover ID \(coverID, privacy: .public) for index based entry")
                attachedCover = createCover(attributes: attributeDict)
                attachedCover!.album = attachedAlbum
                attachedAlbum.cover = attachedCover!
            }
            
            if shouldFetchAlbumArt {
                clientController.getCover(id: coverID)
            }
        }
        
        if let attachedAlbum = attachedAlbum, let artistName = attributeDict["artist"] {
            // XXX: try using artistId - may be tag based in subsonic so wouldn't match right ID...
            attachedArtist = fetchArtist(name: artistName)
            if attachedArtist == nil {
                logger.info("Creating artist name \(artistName, privacy: .public) for index based entry")
                attachedArtist = SBArtist.insertInManagedObjectContext(context: threadedContext)
                // XXX: Lack of ID seems like it'll be agony
                attachedArtist!.itemName = artistName
                attachedArtist!.isLocal = false
                attachedArtist!.server = server
                server.addToIndexes(attachedArtist!)
            }
            
            attachedAlbum.artist = attachedArtist!
            attachedArtist!.addToAlbums(attachedAlbum)
        }
    }
    
    private func updateTrack(_ track: SBTrack, attributes: [String: String]) {
        if let name = attributes["title"] {
            track.itemName = name
        }
        if let artist = attributes["artist"] {
            track.artistName = artist
        }
        if let album = attributes["album"] {
            track.albumName = album
        }
        if let trackString = attributes["track"], let trackNumber = Int(trackString) {
            track.trackNumber = NSNumber(value: trackNumber)
        }
        if let discString = attributes["discNumber"], let disc = Int(discString) {
            track.discNumber = NSNumber(value: disc)
        }
        if let yearString = attributes["year"], let year = Int(yearString) {
            track.year = NSNumber(value: year)
        }
        if let genre = attributes["genre"] {
            track.genre = genre
        }
        if let sizeString = attributes["size"], let size = Int(sizeString) {
            track.size = NSNumber(value: size)
        }
        if let contentType = attributes["contentType"] {
            track.contentType = contentType
        }
        if let contentSuffix = attributes["contentSuffix"] {
            track.contentSuffix = contentSuffix
        }
        if let transcodedContentType = attributes["transcodedContentType"] {
            track.transcodedType = transcodedContentType
        }
        if let transcodedSuffix = attributes["transcodedSuffix"] {
            track.transcodeSuffix = transcodedSuffix
        }
        if let durationString = attributes["duration"], let duration = Int(durationString) {
            track.duration = NSNumber(value: duration)
        }
        if let bitRateString = attributes["bitRate"], let bitRate = Int(bitRateString) {
            track.bitRate = NSNumber(value: bitRate)
        }
        if let path = attributes["path"] {
            track.path = path
        }
    }
    
    private func createTrack(attributes: [String: String]) -> SBTrack {
        let track = SBTrack.insertInManagedObjectContext(context: threadedContext)
        
        if let id = attributes["id"] {
            track.itemId = id
        }
        
        track.isLocal = false
        track.server = server
        server.addToTracks(track)
        
        updateTrack(track, attributes: attributes)
        
        return track
    }
    
    private func createCover(attributes: [String: String]) -> SBCover {
        let cover = SBCover.insertInManagedObjectContext(context: threadedContext)
        
        if let id = attributes["coverArt"] {
            cover.itemId = id
        }
        
        return cover
    }
    
    private func updatePlaylist(_ playlist: SBPlaylist, attributes: [String: String]) {
        if let id = attributes["id"] {
            playlist.itemId = id
        }
        if let name = attributes["name"] {
            playlist.resourceName = name
        }
    }
    
    private func createPlaylist(attributes: [String: String]) -> SBPlaylist {
        let playlist = SBPlaylist.insertInManagedObjectContext(context: threadedContext)
        
        updatePlaylist(playlist, attributes: attributes)
        
        playlist.server = server
        server.addToPlaylists(playlist)
        
        return playlist
    }
    
    private func createNowPlaying(attributes: [String: String]) -> SBNowPlaying  {
        let nowPlaying = SBNowPlaying.insertInManagedObjectContext(context: threadedContext)
        
        if let minutesAgoString = attributes["minutesAgo"], let minutesAgo = Int(minutesAgoString) {
            nowPlaying.minutesAgo = NSNumber(value: minutesAgo)
        }
        if let username = attributes["username"] {
            nowPlaying.username = username
        }
        
        // the attached objects like track and its descendents may not exist yet, done in caller
        
        return nowPlaying
    }
    
    private func createPodcast(attributes: [String: String]) -> SBPodcast {
        let podcast = SBPodcast.insertInManagedObjectContext(context: threadedContext)
        
        if let id = attributes["id"] {
            podcast.itemId = id
        }
        if let title = attributes["title"] {
            podcast.itemName = title
        }
        if let description = attributes["description"] {
            podcast.channelDescription = description
        }
        if let status = attributes["status"] {
            podcast.channelStatus = status
        }
        if let url = attributes["url"] {
            podcast.channelURL = url
        }
        if let errorMessage = attributes["errorMessage"] {
            podcast.errorMessage = errorMessage
        }
        if let path = attributes["path"] {
            podcast.path = path
        }
        
        podcast.isLocal = false
        podcast.server = server
        server.addToPodcasts(podcast)
        
        return podcast
    }
    
    private func createEpisode(attributes: [String: String]) -> SBEpisode {
        let episode = SBEpisode.insertInManagedObjectContext(context: threadedContext)
        
        if let id = attributes["id"] {
            episode.itemId = id
        }
        if let streamId = attributes["streamId"] {
            episode.streamID = streamId
        }
        if let description = attributes["description"] {
            episode.episodeDescription = description
        }
        if let status = attributes["status"] {
            episode.episodeStatus = status
        }
        if let publishDate = attributes["publishDate"]?.dateTimeFromRFC3339() {
            episode.publishDate = publishDate
        }
        // same as SBTrack from this point on i believe
        if let yearString = attributes["year"], let year = Int(yearString) {
            episode.year = NSNumber(value: year)
        }
        if let genre = attributes["genre"] {
            episode.genre = genre
        }
        if let sizeString = attributes["size"], let size = Int(sizeString) {
            episode.size = NSNumber(value: size)
        }
        if let contentType = attributes["contentType"] {
            episode.contentType = contentType
        }
        if let contentSuffix = attributes["contentSuffix"] {
            episode.contentSuffix = contentSuffix
        }
        if let transcodedContentType = attributes["transcodedContentType"] {
            episode.transcodedType = transcodedContentType
        }
        if let transcodedSuffix = attributes["transcodedSuffix"] {
            episode.transcodeSuffix = transcodedSuffix
        }
        if let durationString = attributes["duration"], let duration = Int(durationString) {
            episode.duration = NSNumber(value: duration)
        }
        if let bitRateString = attributes["bitRate"], let bitRate = Int(bitRateString) {
            episode.bitRate = NSNumber(value: bitRate)
        }
        if let path = attributes["path"] {
            episode.path = path
        }
        
        episode.isLocal = false
        episode.server = server
        // XXX: Do we call addToTracks?
        
        return episode
    }
}
