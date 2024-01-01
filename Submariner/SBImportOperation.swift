//
//  SBImportOperation.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-19.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers

@objc class SBImportOperation: SBOperation {
    private let initialPaths: [URL]
    
    var copyFiles = false
    var removeSourceFiles = false
    
    var remoteTrack: SBTrack?
    
    @objc init!(managedObjectContext mainContext: NSManagedObjectContext!, files: [URL], copyFiles: Bool) {
        initialPaths = files
        remoteTrack = nil
        super.init(managedObjectContext: mainContext, name: "Importing Local Files")
        self.copyFiles = copyFiles
    }
    
    init!(managedObjectContext mainContext: NSManagedObjectContext!, file: URL, remoteTrackID: NSManagedObjectID) {
        initialPaths = [file]
        // XXX: can't make it title without making name a published var
        super.init(managedObjectContext: mainContext, name: "Importing Downloaded Track")
        // we assume we have a valid track here
        remoteTrack = threadedContext.object(with: remoteTrackID) as? SBTrack
        // importing a downloaded file, we remove it after
        self.removeSourceFiles = true
        self.copyFiles = true
    }
    
    private func recursiveFiles(paths: [URL]) -> [URL] {
        // kinda ugly
        var finalPathList: [URL] = []
        for path in paths {
            var isDir = ObjCBool(false)
            let exists = FileManager.default.fileExists(atPath: path.path, isDirectory: &isDir)
            guard exists else {
                continue
            }
            if isDir.boolValue {
                if let contents = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil) {
                    finalPathList.append(contentsOf: recursiveFiles(paths: contents))
                }
            } else {
                // check if it's an audio file
                if let type = UTType(filenameExtension: path.pathExtension),
                   // M4A gets counted as video instead?
                   (type.conforms(to: .audio) || type.identifier == "public.mpeg-4") {
                    finalPathList.append(path)
                }
            }
        }
        return finalPathList
    }
    
    // XXX: Factor this out into sep funcs and clean up the mess
    private func importFile(path: URL) throws {
        // #MARK: Step 1: Create Core Data objects
        var titleString, artistString, albumArtistString, albumString, genreString, contentType: String?
        var trackNumber, discNumber, durationNumber, bitrateNumber: NSNumber?
        var coverData: Data?
        if let remoteTrack = remoteTrack {
            titleString = remoteTrack.itemName as String?
            artistString = remoteTrack.artistName as String?
            // first case is so that it matches the album's artist on the server
            if let remoteAlbum = remoteTrack.album, let remoteAlbumArtist = remoteAlbum.artist {
                albumArtistString = remoteAlbumArtist.itemName
            } else if let albumArtistMaybe = remoteTrack.artistName as String?,
               albumArtistMaybe != "" {
                albumArtistString = albumArtistMaybe
            } else {
                albumArtistString = artistString
            }
            albumString = remoteTrack.albumString as String?
            genreString = remoteTrack.genre as String?
            trackNumber = remoteTrack.trackNumber
            discNumber = remoteTrack.discNumber
            durationNumber = remoteTrack.duration
            bitrateNumber = remoteTrack.bitRate
            contentType = remoteTrack.contentType
            coverData = nil
        } else if let metadata = try? SBAudioMetadata(URL: path as NSURL) {
            titleString = metadata.title as String?
            artistString = metadata.artist as String?
            if let albumArtistMaybe = metadata.albumArtist as String?,
               albumArtistMaybe != "" {
                albumArtistString = albumArtistMaybe
            } else {
                albumArtistString = artistString
            }
            albumString = metadata.albumTitle as String?
            genreString = metadata.genre as String?
            trackNumber = metadata.trackNumber
            discNumber = metadata.discNumber
            durationNumber = metadata.duration
            bitrateNumber = metadata.bitrate
            coverData = metadata.albumArt as Data?
            if let extensionType = UTType(filenameExtension: path.pathExtension),
               let mime = extensionType.preferredMIMEType {
                contentType = mime
            }
        }
        
        // set these if non-existent
        titleString = titleString ?? "Unknown Track"
        albumArtistString = albumArtistString ?? "Unknown Artist"
        artistString = artistString ?? "Unknown Artist"
        albumString = albumString ?? "Unknown Album"
        
        // create artist if needed
        let artistRequest: NSFetchRequest<SBArtist> = SBArtist.fetchRequest()
        artistRequest.predicate = NSPredicate(format: "(itemName == %@) && (server == nil)", albumArtistString!)
        var newArtist = try? threadedContext.fetch(artistRequest).first
        if newArtist == nil {
            newArtist = SBArtist.init(entity: SBArtist.entity(), insertInto: threadedContext)
            newArtist!.itemName = albumArtistString
        }
        
        // create album if needed
        let albumRequest: NSFetchRequest<SBAlbum> = SBAlbum.fetchRequest()
        albumRequest.predicate = NSPredicate(format: "(itemName == %@) && (artist == %@)", albumString!, newArtist!)
        var newAlbum = try? threadedContext.fetch(albumRequest).first
        if newAlbum == nil {
            newAlbum = SBAlbum.init(entity: SBAlbum.entity(), insertInto: threadedContext)
            newAlbum!.itemName = albumString
        }
        
        // create track if needed
        let trackRequest: NSFetchRequest<SBTrack> = SBTrack.fetchRequest()
        trackRequest.predicate = NSPredicate(format: "(itemName == %@) && (server == nil)", titleString!)
        var newTrack = try? threadedContext.fetch(trackRequest).first
        if newTrack == nil {
            newTrack = SBTrack.init(entity: SBTrack.entity(), insertInto: threadedContext)
            newTrack!.itemName = titleString
            
            newTrack!.bitRate = bitrateNumber
            newTrack!.duration = durationNumber
            newTrack!.trackNumber = trackNumber
            newTrack!.discNumber = discNumber
            newTrack!.genre = genreString
            newTrack!.contentType = contentType
            // not the album artist
            newTrack!.artistName = artistString
        }
        
        if !newAlbum!.tracks!.contains(newTrack!) {
            newAlbum!.addToTracks(newTrack!)
        }
        
        if !newArtist!.albums!.contains(newAlbum!) {
            newArtist?.addToAlbums(newAlbum!)
        }
        
        let libraryRequest = NSFetchRequest<SBLibrary>(entityName: "Library")
        let library = try! threadedContext.fetch(libraryRequest).first!
        if !library.artists!.contains(newArtist!) {
            library.addToArtists(newArtist!)
        }
        
        // #MARK: Step 2: Filesystem
        if copyFiles {
            let artistPath = albumArtistString!
            let albumPath = artistPath + "/" + albumString!
            // Before the refactor, temporaryFileURL provided us a random filename.
            // Let's try to keep the same semantics to avoid i.e. clobbering with
            // re-imports? (Is this needed?)
            let trackType = UTType(filenameExtension: path.pathExtension) ?? UTType.mp3
            let fileName = UUID().uuidString + "." + trackType.preferredFilenameExtension!
            let trackPath = albumPath + "/" + fileName
            
            let absoluteAlbumURL = SBAppDelegate.musicDirectory.appendingPathComponent(albumPath)
            let absoluteTrackURL = SBAppDelegate.musicDirectory.appendingPathComponent(trackPath)
            
            // create artist and album directory if needed
            try FileManager.default.createDirectory(at: absoluteAlbumURL, withIntermediateDirectories: true)
            
            // copy track to new destination...
            try FileManager.default.copyItem(at: path, to: absoluteTrackURL)
            
            // ...but use the relative path. remote paths are already relative
            newTrack!.path = trackPath
            newAlbum!.path = albumPath
            newArtist!.path = artistPath
        } else {
            // absolute path ok here
            newTrack!.path = path.path
        }
        
        // #MARK: Step 3: Cover
        let coverDir = SBAppDelegate.coverDirectory.appendingPathComponent("Local Library")
        if let coverData = coverData {
            var coverType = UTType.jpeg
            if let coverTypeGuess = coverData.guessImageType() {
                coverType = coverTypeGuess
            }
            let artistCoverDir = coverDir.appendingPathComponent(albumArtistString!)
            
            try? FileManager.default.createDirectory(at: artistCoverDir, withIntermediateDirectories: true)
            
            let finalPath = artistCoverDir
                .appendingPathComponent(albumString!)
                .appendingPathExtension(for: coverType)
            try coverData.write(to: finalPath, options: [.atomic])
            
            let relativePath = albumArtistString! + "/" + albumString! + "." + coverType.preferredFilenameExtension!
            // HACK: check if cover in album is nil; usually somehow track's isn't
            if newAlbum!.cover == nil {
                newAlbum!.cover = SBCover.init(entity: SBCover.entity(), insertInto: threadedContext)
            }
            newAlbum!.cover!.imagePath = relativePath as NSString?
            newAlbum!.cover!.isLocal = NSNumber(booleanLiteral: true)
        } else {
            // else if track parent directory contains cover file
            let originalAlbumFolder = path.deletingLastPathComponent()
            
            if let albumFiles = try? FileManager.default.contentsOfDirectory(atPath: originalAlbumFolder.path) {
                for fileName in albumFiles {
                    let fullPath = originalAlbumFolder
                        .appendingPathComponent(fileName)
                    if let type = UTType(filenameExtension: fullPath.pathExtension),
                       type.conforms(to: .image),
                       // XXX: Better heuristic for getting the right cover name
                       !fileName.contains("back") {
                        // Copy the artwork
                        let artistCoverDir = coverDir.appendingPathComponent(albumArtistString!)
                        try? FileManager.default.createDirectory(at: artistCoverDir, withIntermediateDirectories: true)
                        
                        let finalPath = artistCoverDir
                            .appendingPathComponent(fileName)
                            .appendingPathExtension(for: type)
                        try FileManager.default.copyItem(at: fullPath, to: finalPath)
                        
                        let relativePath = albumArtistString! + "/" + albumString! + type.preferredFilenameExtension!
                        
                        // same as above
                        if newAlbum!.cover == nil {
                            newAlbum!.cover = SBCover.init(entity: SBCover.entity(), insertInto: threadedContext)
                        }
                        newAlbum!.cover!.imagePath = relativePath as NSString?
                        newAlbum!.cover!.isLocal = NSNumber(booleanLiteral: true)
                        // Don't set the track cover, since it's not really used.
                    }
                }
            }
        }
        
        // #MARK: Step 4: Finishing up
        newTrack!.isLinked = NSNumber.init(booleanLiteral: !copyFiles)
        newAlbum!.isLinked = NSNumber.init(booleanLiteral: !copyFiles)
        newArtist!.isLinked = NSNumber.init(booleanLiteral: !copyFiles)
        newTrack!.isLocal = NSNumber.init(booleanLiteral: true)
        newAlbum!.isLocal = NSNumber.init(booleanLiteral: true)
        newArtist!.isLocal = NSNumber.init(booleanLiteral: true)
        
        if removeSourceFiles {
            try FileManager.default.removeItem(at: path)
        }
        
        // Does this come from a stream?
        if let remoteTrack = self.remoteTrack {
            remoteTrack.localTrack = newTrack
            newTrack!.remoteTrack = remoteTrack
            
            // XXX: Does this make sense? ObjC version did it
            if newAlbum!.cover == nil {
                newAlbum!.cover = SBCover.init(entity: SBCover.entity(), insertInto: threadedContext)
            }
            newAlbum!.cover!.imagePath = remoteTrack.album?.cover?.imagePath
        }
    }
    
    override func main() {
        DispatchQueue.main.async {
            self.operationInfo = "Finding files"
        }
        let paths = recursiveFiles(paths: initialPaths)
        // XXX: do we fail at first error or let the other files continue?
        do {
            var i = Float(0)
            let total = Float(paths.count)
            for path in paths {
                DispatchQueue.main.async {
                    self.operationInfo = "Importing \(path)"
                    self.progress = .determinate(n: i, outOf: total)
                }
                try importFile(path: path)
                i += 1
            }
        } catch {
            DispatchQueue.main.async {
                NSApp.presentError(error)
            }
        }
        // finally
        saveThreadedContext()
        finish()
    }
}
