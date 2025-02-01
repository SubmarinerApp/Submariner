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
    let requestType: SBSubsonicRequestType
    var server: SBServer!
    let xmlData: Data?
    let mimeType: String?
    
    // state
    var errored: Bool = false
    
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
    
    // state for deleting elements not in this list
    var playlistsReturned: [SBPlaylist] = []
    var artistsReturned: [SBArtist] = []
    var albumsReturned: [SBAlbum] = []
    
    init!(managedObjectContext mainContext: NSManagedObjectContext!,
          requestType: SBSubsonicRequestType,
          server: NSManagedObjectID,
          xml: Data?,
          mimeType: String?) {
        self.requestType = requestType
        self.xmlData = xml
        self.mimeType = mimeType
        
        super.init(managedObjectContext: mainContext, name: "Parsing Subsonic Request")
        self.server = threadedContext.object(with: server) as? SBServer
    }
    
    // #MARK: - NSOperation
    
    override func main() {
        synchronized(server) {
            defer {
                self.finish()
                self.saveThreadedContext()
            }
            do {
                if let mimeType = self.mimeType, mimeType.hasPrefix("image/") {
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
            logger.info("Wrote cover file \(fileName, privacy: .public)")
            
            if let cover = fetchCover(coverID: currentCoverID) {
                // reset album in weird circumstance where it's not associated
                if let currentAlbumID = self.currentAlbumID, let album = fetchAlbum(id: currentAlbumID) {
                    cover.album = album
                    album.cover = cover
                }
                cover.imagePath = fileName.path as NSString
                logger.info("Set cover \(currentCoverID, privacy: .public) to file \(fileName, privacy: .public)")
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
            
            if let currentPlaylistID = self.currentPlaylistID {
                logger.info("Didn't find playlist on server w/ ID of \(currentPlaylistID, privacy: .public)")
                if let playlistToDelete = fetchPlaylist(id: currentPlaylistID) {
                    logger.info("Removing playlist that wasn't found on server w/ ID of \(currentPlaylistID, privacy: .public)")
                    threadedContext.delete(playlistToDelete)
                }
                return
            } else if let currentArtistID = self.currentArtistID {
                logger.info("Didn't find artist on server w/ ID of \(currentArtistID, privacy: .public)")
                if let artistToDelete = fetchArtist(id: currentArtistID) {
                    logger.info("Removing artist that wasn't found on server w/ ID of \(currentArtistID, privacy: .public)")
                    threadedContext.delete(artistToDelete)
                }
                return
            } else if let currentAlbumID = self.currentAlbumID {
                logger.info("Didn't find album on server w/ ID of \(currentAlbumID, privacy: .public)")
                if let albumToDelete = fetchAlbum(id: currentAlbumID) {
                    logger.info("Removing album that wasn't found on server w/ ID of \(currentAlbumID, privacy: .public)")
                    threadedContext.delete(albumToDelete)
                }
                return
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
    
    private func parseElementDirectory(attributeDict: [String: String]) {
        if let directoryId = attributeDict["id"] {
            if let directory = fetchDirectory(id: directoryId) {
                updateDirectory(directory, attributes: attributeDict, inContextOf: .directoryElement)
                return
            }
            logger.info("Creating new directory with ID \(directoryId, privacy: .public)")
            let _ = createDirectory(attributes: attributeDict, inContextOf: .directoryElement)
            
            // Directory is not a type of index to avoid confusing the artist view (which looks at server.indexes)
        }
    }
    
    private func parseElementChild(attributeDict: [String: String]) {
        if attributeDict["isDir"] == "true", let directoryId = attributeDict["id"] {
            if let directory = fetchDirectory(id: directoryId) {
                updateDirectory(directory, attributes: attributeDict, inContextOf: .childDirectory)
                return
            }
            let _ = createDirectory(attributes: attributeDict, inContextOf: .childDirectory)
        } else if let id = attributeDict["id"], let parent = attributeDict["id"] {
            if let type = attributeDict["type"], type != "music" {
                logger.info("Ignoring directory entry for non-music")
                return
            }
            // track instead of dir
            if let track = fetchTrack(id: id) {
                logger.info("Updating track with ID: \(id, privacy: .public) for directory ID \(parent, privacy: .public)")
                
                // this should update and associate directory et al
                updateTrackDependenciesForTag(track, attributeDict: attributeDict, shouldFetchAlbumArt: false)
            } else {
                // if the track doesn't exist yet, it'll be born without context. provide that context (artist/album/cover)
                // FIXME: Should we update *existing* tracks regardless? For previous cases they were pulled anew...
                logger.info("Creating track with ID: \(id, privacy: .public) for directory ID \(parent, privacy: .public)")
                let track = createTrack(attributes: attributeDict)
                updateTrackDependenciesForTag(track, attributeDict: attributeDict, shouldFetchAlbumArt: false)
            }
        }
    }
    
    private func parseElementArtist(attributeDict: [String: String]) {
        if let id = attributeDict["id"], let name = attributeDict["name"] {
            if let existingArtist = fetchArtist(id: id) {
                artistsReturned.append(existingArtist)
                // doing this in ID3 migration, but may be useful if servers keep ID if artist renames
                // i.e. "British Sea Power" -> "Sea Power" (and avoid deadnames, etc.)
                existingArtist.itemName = name
                // star status
                existingArtist.starred = attributeDict["starred"]?.dateTimeFromISO()
                // as we don't do it in updateTrackDependencies
                server.addToIndexes(existingArtist)
            } else if let existingArtist = fetchArtist(name: name) {
                artistsReturned.append(existingArtist)
                // legacy for cases where we have artists without IDs from i.e. getNowPlaying/search2
                existingArtist.itemId = id
                // update star status
                existingArtist.starred = attributeDict["starred"]?.dateTimeFromISO()
                // as we don't do it in updateTrackDependencies
                server.addToIndexes(existingArtist)
            } else {
                logger.info("Creating new artist with ID: \(id, privacy: .public) and name \(name, privacy: .public)")
                let artist = createArtist(attributes: attributeDict)
                artistsReturned.append(artist)
            }
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
            
            var album = fetchAlbum(id: id, artist: artist)
            if let album = album {
                updateAlbum(album, attributes: attributeDict)
            } else {
                logger.info("Creating new album with ID: \(id, privacy: .public) for artist ID \(artistId, privacy: .public)")
                album = createAlbum(attributes: attributeDict)
            }
            
            // for future song elements under this one
            switch requestType {
            case .getArtist(id: _):
                currentArtist = artist // prob better in artist element
            case .getAlbum(_):
                currentAlbum = album
            default:
                break
            }
            
            // always reassociate due to possible transitions
            if artist != nil {
                album!.artist = artist
                artist?.addToAlbums(album!)
            }
            server.home?.addToAlbums(album!)
            album!.home = server.home
            
            if let coverArt = attributeDict["coverArt"] {
                if let cover = album?.cover, cover.itemId != coverArt {
                    logger.info("Cover ID \(cover.itemId ?? "<nil>", privacy: .public) mismatch for returned ID \(coverArt, privacy: .public), resetting")
                    cover.itemId = coverArt
                    // let's reset it, since it might be stale
                    cover.imagePath = nil
                } else if album?.cover == nil {
                    logger.info("Creating new cover with ID: \(coverArt, privacy: .public) for album ID \(id, privacy: .public)")
                    let cover = createCover(attributes: attributeDict)
                    cover.album = album
                    album!.cover = cover
                }
                
                let imagePath = album?.cover?.imagePath
                if imagePath == nil || !FileManager.default.fileExists(atPath: imagePath! as String) {
                    server.getCover(id: coverArt, for: album!.itemId)
                }
            }
            
            albumsReturned.append(album!)
        }
    }
    
    private func parseElementPlaylist(attributeDict: [String: String]) {
        switch requestType {
        case .getPlaylists:
            if let id = attributeDict["id"], let name = attributeDict["name"] {
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
                playlistsReturned.append(playlist!)
            }
        case .getPlaylist(_):
            if let id = attributeDict["id"] {
                currentPlaylist = fetchPlaylist(id: id)
            }
            
            // empty it out so we can update from server
            currentPlaylist?.trackIDs = []
        default:
            logger.warning("Invalid request type \(String(describing: self.requestType)) for playlist element")
        }
    }
    
    private func parseElementEntryForPlaylist(attributeDict: [String: String]) {
        if let currentPlaylist = self.currentPlaylist, let id = attributeDict["id"] {
            if let track = fetchTrack(id: id) {
                logger.info("Adding track (and updating) with ID: \(id, privacy: .public) to playlist \(currentPlaylist.itemId ?? "(no ID?)", privacy: .public)")
                
                updateTrackDependenciesForTag(track, attributeDict: attributeDict, shouldFetchAlbumArt: false)
                
                currentPlaylist.add(track: track)
            } else {
                // if the track doesn't exist yet, it'll be born without context. provide that context (artist/album/cover)
                // FIXME: Should we update *existing* tracks regardless? For previous cases they were pulled anew...
                logger.info("Creating new track with ID: \(id, privacy: .public) for playlist \(currentPlaylist.itemId ?? "(no ID?)", privacy: .public)")
                let track = createTrack(attributes: attributeDict)
                updateTrackDependenciesForTag(track, attributeDict: attributeDict, shouldFetchAlbumArt: false)
                
                currentPlaylist.add(track: track)
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
        switch requestType {
        case .getPlaylist(_):
            parseElementEntryForPlaylist(attributeDict: attributeDict)
        case .getNowPlaying:
            parseElementEntryForNowPlaying(attributeDict: attributeDict)
        default:
            logger.warning("Invalid request type \(String(describing: self.requestType)) for entry element")
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
            if episode == nil {
                logger.info("Creating episode ID \(id, privacy: .public)")
                episode = createEpisode(attributes: attributeDict)
            }
            
            if currentPodcast.episodes?.contains(episode!) == true && attributeDict["status"] == episode?.episodeStatus {
                updateEpisode(episode!, attributes: attributeDict)
            } else {
                currentPodcast.addToEpisodes(episode!)
            }
            
            if let streamID = attributeDict["streamId"] {
                let track = fetchTrack(id: streamID)
                if track == nil {
                    // XXX: does it associate? is it used?
                    server.getTrack(trackID: streamID)
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
        } else if elementName == "directory" { // for looking at directories - we don't use index/section yet for these?
            parseElementDirectory(attributeDict: attributeDict)
        } else if elementName == "child" { // directory member
            parseElementChild(attributeDict: attributeDict)
        } else if elementName == "artist" { // build artist index
            // artist in context of getIndexes -> directories; artist in context of getArtist(s) -> artistId
            switch (requestType) {
            case .getArtists, .getArtist(id: _):
                parseElementArtist(attributeDict: attributeDict)
            case .getDirectories:
                parseElementDirectory(attributeDict: attributeDict)
            default:
                break
            }
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
        } else if elementName == "openSubsonicExtensions" {
            guard let name = attributeDict["name"] else {
                return
            }
            
            logger.debug("Server supports feature \(name)")
            if name == "formPost" {
                server.supportsFormPost = true
            }
        } else if elementName == "versions" {
            // nop
        } else {
            logger.error("Unknown XML element \(elementName, privacy: .public), attributes \(attributeDict, privacy: .public)")
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "podcast" {
            currentPodcast = nil
        }
    }
    
    private func postServerNotification(_ notificationName: NSNotification.Name) {
        NotificationCenter.default.post(name: notificationName, object: server.objectID)
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        logger.info("Finished XML processing")
        
        switch requestType {
        case .ping where !errored:
            postServerNotification(.SBSubsonicConnectionSucceeded)
        case .getPlaylists:
            let playlistRequest: NSFetchRequest<SBPlaylist> = SBPlaylist.fetchRequest()
            playlistRequest.predicate = NSPredicate(format: "(server == %@) && (NOT (self IN %@))", server, playlistsReturned)
            if let playlists = try? threadedContext.fetch(playlistRequest) {
                for playlist in playlists {
                    logger.info("Removing artist not in list \(playlist.itemId ?? "<nil>", privacy: .public) name \(playlist.resourceName ?? "<nil>")")
                    threadedContext.delete(playlist)
                }
            }
            postServerNotification(.SBSubsonicPlaylistsUpdated)
        case .getPlaylist(_):
            currentPlaylist = nil
        case .createPlaylist(_, _):
            postServerNotification(.SBSubsonicPlaylistsCreated)
        case .getNowPlaying:
            postServerNotification(.SBSubsonicNowPlayingUpdated)
        case .search(_), .getTopTracks(artistName: _), .getSimilarTracks(artist: _):
            NotificationCenter.default.post(name: .SBSubsonicSearchResultUpdated, object: currentSearch)
        case .getPodcasts:
            postServerNotification(.SBSubsonicPodcastsUpdated)
        case .replacePlaylist(_, _):
            postServerNotification(.SBSubsonicPlaylistUpdated)
        case .updatePlaylist(_, _, _, _, _, _):
            postServerNotification(.SBSubsonicPlaylistUpdated)
        case .getArtists:
            // purge artists not returned, since unlike getIndexes, getArtists returns the full list
            let artistRequest: NSFetchRequest<SBArtist> = SBArtist.fetchRequest()
            artistRequest.predicate = NSPredicate(format: "(server == %@) && (NOT (self IN %@))", server, artistsReturned)
            if let artists = try? threadedContext.fetch(artistRequest) {
                for artist in artists {
                    logger.info("Removing artist not in list \(artist.itemId ?? "<nil>", privacy: .public) name \(artist.itemName ?? "<nil>")")
                    threadedContext.delete(artist)
                }
            }
            postServerNotification(.SBSubsonicIndexesUpdated)
        case .getArtist(_):
            // purge albums not returned to deal with ID transition
            if let currentArtist = self.currentArtist, let albums = currentArtist.albums as? Set<SBAlbum> {
                let union = Set(albumsReturned).union(albums) as? NSSet
                currentArtist.albums = union
            }
            postServerNotification(.SBSubsonicAlbumsUpdated)
        case .getAlbumList(type: _):
            postServerNotification(.SBSubsonicAlbumsUpdated)
        case .getAlbum(_):
            postServerNotification(.SBSubsonicTracksUpdated)
        default:
            break
        }
        
        // since we can run DB ops here now, save this for last
        threadedContext.processPendingChanges()
        saveThreadedContext()
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        logger.error("XML parsing error \(parseError, privacy: .public)")
        DispatchQueue.main.async {
            NSApp.presentError(parseError)
        }
    }
    
    // #MARK: - Fetch Core Data objects
    // TODO: These might make more sense on their Core Data classes.
    
    private func fetchDirectory(id: String) -> SBDirectory? {
        let fetchRequest = NSFetchRequest<SBDirectory>(entityName: "Directory")
        fetchRequest.predicate = NSPredicate(format: "(itemId == %@) && (server == %@)", id, server)
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
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
            // Be careful to keep it with the same server; two Navidrome instances
            // can have the same album ID for the same album.
            // The second condition should be written as "ALL tracks.server == %@",
            // but Core Data doesn't like that. See https://stackoverflow.com/a/47762233
            // for the workaround used.
            fetchRequest.predicate = NSPredicate(format: "(itemId == %@) && SUBQUERY(tracks, $X, $X.server == %@).@count == tracks.@count", id, server)
        }
        let results = try? threadedContext.fetch(fetchRequest)
        
        return results?.first
    }
    
    private func fetchAlbum(name: String, artist: SBArtist? = nil) -> SBAlbum? {
        let fetchRequest = NSFetchRequest<SBAlbum>(entityName: "Album")
        if let artist = artist {
            fetchRequest.predicate = NSPredicate(format: "(itemName == %@) && (artist == %@)", name, artist)
        } else {
            fetchRequest.predicate = NSPredicate(format: "(itemName == %@) && SUBQUERY(tracks, $X, $X.server == %@).@count == tracks.@count", name, server)
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
    
    private func updateAlbum(_ album: SBAlbum, attributes: [String: String]) {
        // ID3 based routes use name instead of title
        if let name = attributes["name"] {
            album.itemName = name
        }
        if let yearString = attributes["year"], let year = Int(yearString) {
            album.year = NSNumber(value: year)
        }
        // if starriness is missing, it's no longer started
        album.starred = attributes["starred"]?.dateTimeFromISO()
    }
    
    private func createAlbum(attributes: [String: String]) -> SBAlbum {
        let album = SBAlbum.insertInManagedObjectContext(context: threadedContext)
        
        if let id = attributes["id"] {
            album.itemId = id
        }
        
        updateAlbum(album, attributes: attributes)
        
        // don't assume cover yet
        
        album.isLocal = false
        
        return album
    }
    
    enum DirectoryCreation: Equatable {
        case directoryElement
        case childDirectory
        case parentReferenceOnly
    }
    
    private func updateDirectory(_ directory: SBDirectory, attributes: [String: String], inContextOf directoryCreation: DirectoryCreation) {
        // <directory> uses "name", <child> dirs use "title", and we can't get the name from i.e. a track
        switch (directoryCreation) {
        case .directoryElement:
            if let name = attributes["name"] {
                directory.itemName = name
            }
        case .childDirectory:
            if let name = attributes["title"] {
                directory.itemName = name
            }
        case .parentReferenceOnly:
            break
        }
        
        if directoryCreation != .parentReferenceOnly {
            directory.starred = attributes["starred"]?.dateTimeFromISO()
        }
        
        // if we're fetching a directory, it might have a parent we may or may not know about.
        // almost certainly we know it (or we wouldn't have requested the directory, but just make sure integrity is kept
        if let parentDirectoryId = attributes["parent"] {
            var parentDirectory = fetchDirectory(id: parentDirectoryId)
            if parentDirectory == nil {
                parentDirectory = createDirectory(attributes: attributes, inContextOf: .parentReferenceOnly)
            }
            
            directory.parentDirectory = parentDirectory
            parentDirectory?.addToSubdirectories(directory)
        }
    }
    
    private func createDirectory(attributes: [String: String], inContextOf directoryCreation: DirectoryCreation) -> SBDirectory {
        let directory = SBDirectory.insertInManagedObjectContext(context: threadedContext)
        
        // is this for a <directory> element with metadata, or any other object with a parent, including another directory? (we can fetch it later if otherwise)
        switch (directoryCreation) {
        case .directoryElement, .childDirectory:
            if let id = attributes["id"] {
                directory.itemId = id
            }
            updateDirectory(directory, attributes: attributes, inContextOf: directoryCreation)
        case .parentReferenceOnly:
            // only information we have is the parent
            if let id = attributes["parent"] {
                directory.itemId = id
            }
        }
        
        if directoryCreation != .parentReferenceOnly {
            directory.starred = attributes["starred"]?.dateTimeFromISO()
        }
        
        directory.server = self.server
        // would this mess up hierarchy? just filter on if parentDirectory == nil
        server.addToDirectories(directory)
        directory.isLocal = false
        
        return directory
    }
    
    private func updateTrackDependenciesForTag(_ track: SBTrack, attributeDict: [String: String], shouldFetchAlbumArt: Bool = true) {
        var attachedArtist: SBArtist?
        // Note that the artist ID isn't infallible; it can be a different artist from the album
        // (for diff performers, i.e. "OutKast" vs. "OutKast feat. Killer Mike", each w/ diff artistID).
        // Unfortunately, this can cause those droppings to appear confusingly to users from i.e.
        // a directory listing (as well as playlists, now playing, or search).
        // However, a reload of that should clean up the detritus artists that appear -
        // problem is where it should go.
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
        if shouldFetchAlbumArt, let attachedAlbum = attachedAlbum, let coverArt = attributeDict["coverArt"] {
            // don't have the codepath that resets the cover since if getNowPlaying is called,
            // subsonic returns the directory cover ID instead of the tag cover ID.
            // if we set it first here, NBD, it can get reset later.
            if attachedAlbum.cover == nil {
                logger.info("Creating new cover with ID: \(coverArt, privacy: .public) for album ID \(attachedAlbum.itemId ?? "<nil>", privacy: .public)")
                let cover = createCover(attributes: attributeDict)
                cover.album = attachedAlbum
                attachedAlbum.cover = cover
            }
            
            let imagePath = attachedAlbum.cover?.imagePath
            if imagePath == nil || !FileManager.default.fileExists(atPath: imagePath! as String) {
                server.getCover(id: coverArt, for: attributeDict["albumId"])
            }
        }
        
        if let attachedAlbum = attachedAlbum {
            attachedAlbum.addToTracks(track)
            track.album = attachedAlbum
        }
        
        var attachedDirectory: SBDirectory?
        if let directoryId = attributeDict["parent"] {
            attachedDirectory = fetchDirectory(id: directoryId)
            if attachedDirectory == nil {
                logger.info("Creating new directory with ID \(directoryId, privacy: .public) in track context")
                attachedDirectory = createDirectory(attributes: attributeDict, inContextOf: .parentReferenceOnly)
            }
        }
        
        if let attachedDirectory = attachedDirectory {
            track.parentDirectory = attachedDirectory
            attachedDirectory.addToTracks(track)
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
        
        // special case: if starriness is missing, it's no longer started
        track.starred = attributes["starred"]?.dateTimeFromISO()
        // same with rating, tho a bit more complex because parsing here
        if let ratingString = attributes["rating"], let rating = Int(ratingString) {
            track.rating = NSNumber(value: rating)
        } else {
            track.rating = 0 // or nil?
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
    
    private func updateEpisode(_ episode: SBEpisode, attributes: [String: String]) {
        if let id = attributes["id"] {
            episode.itemId = id
        }
        if let title = attributes["title"] {
            episode.itemName = title
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
    }
    
    private func createEpisode(attributes: [String: String]) -> SBEpisode {
        let episode = SBEpisode.insertInManagedObjectContext(context: threadedContext)
        
        updateEpisode(episode, attributes: attributes)
        
        return episode
    }
}
