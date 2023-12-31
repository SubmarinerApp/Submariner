//
//  SBLibraryPurgeOperation.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-09-24.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBLibraryPurgeOperation")

class SBLibraryPurgeOperation: SBOperation {
    fileprivate static let sizeFormatter = ByteCountFormatter()
    
    var tracks: [SBTrack]?
    
    init(managedObjectContext: NSManagedObjectContext) {
        super.init(managedObjectContext: managedObjectContext, name: "Deleting Downloaded Tracks")
    }
    
    override func main() {
        DispatchQueue.main.async {
            self.operationInfo = "Counting tracks"
        }
        
        let fetchRequest: NSFetchRequest<SBTrack> = SBTrack.fetchRequest()
        // local library tracks that are associated with a remote track
        // this should exclude linked tracks as well as copied into library files directly imported
        fetchRequest.predicate = NSPredicate(format: "(server == nil) && (remoteTrack != nil) && (isPlaying == NO)")
        self.tracks = try? threadedContext.fetch(fetchRequest)
        
        if let tracks = self.tracks {
            let totalSize = totalSize()
            let totalSizeString = SBLibraryPurgeOperation.sizeFormatter.string(fromByteCount: Int64(totalSize))
            
            logger.info("Proposed purge saves \(totalSizeString, privacy: .public) deleting \(tracks.count) items")
            DispatchQueue.main.async {
                if (tracks.isEmpty) {
                    self.showNothingToDeleteAlert()
                } else {
                    self.showDeletePrompt(totalSizeString: totalSizeString)
                }
            }
        } else {
            // early failure, why?
            saveThreadedContext()
            finish()
        }
    }
    
    func totalSize() -> UInt64 {
        if let tracks = self.tracks {
            return tracks.reduce(0 as UInt64) { partialResult, track in
                // size exists on track attrib but let's check real fs size
                if let path = track.path, let fileAttributes = try? FileManager.default.attributesOfItem(atPath: path) {
                    return partialResult + (fileAttributes[FileAttributeKey.size] as! UInt64)
                } else if let size = track.size {
                    logger.warning("Couldn't get the path or size for track ID \(track.objectID, privacy: .public)")
                    return partialResult + size.uint64Value
                }
                return partialResult
            }
        }
        return 0
    }
    
    func showNothingToDeleteAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "No Downloaded Items"
        alert.informativeText = "There are no downloaded items that can be deleted."
        alert.addButton(withTitle: "OK")
        alert.runModal()
        self.saveThreadedContext()
        self.finish()
    }
    
    func showDeletePrompt(totalSizeString: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Do you want to delete \(tracks!.count) downloaded items?"
        alert.informativeText = "Tracks downloaded to the library take up \(totalSizeString) of space on disk. Items that were imported to the library outside of a server won't be affected. You can redownload tracks from a server at any time."
        alert.addButton(withTitle: "Delete Items")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            self.deleteItems()
        } else {
            // user cancelled
            self.saveThreadedContext()
            self.finish()
        }
    }
    
    func deleteItems() {
        var failedTracks: [SBTrack] = []
        // we had to get here because it is non-null
        var i = Float(0)
        let total = Float(tracks!.count)
        for track in tracks! {
            DispatchQueue.main.async {
                self.operationInfo = "Deleting \(track.itemName ?? "untitled track")"
                self.progress = .determinate(n: i, outOf: total)
            }
            if let path = track.path {
                do {
                    // if the file doesn't exist, definitely get rid of it
                    // we do care about an error removing an existant file though
                    if FileManager.default.fileExists(atPath: path) {
                        try FileManager.default.removeItem(atPath: path)
                    }
                    track.album?.removeFromTracks(track)
                    // not strictly needed
                    track.album = nil
                    track.remoteTrack?.localTrack = nil
                    threadedContext.delete(track)
                } catch {
                    logger.warning("Failed to delete track at path \(path, privacy: .public), because of \(error, privacy: .public)")
                    failedTracks.append(track)
                }
            } else {
                logger.warning("Couldn't get the path or size for track ID \(track.objectID, privacy: .public)")
            }
            i += 1
        }
        // clean out albums and artists locally that are now empty
        DispatchQueue.main.async {
            self.operationInfo = "Removing empty local albums and artists"
            self.progress = .indeterminate(n: 0)
        }
        let artistRequest: NSFetchRequest<SBArtist> = SBArtist.fetchRequest()
        artistRequest.predicate = NSPredicate(format: "(server == nil)")
        if let localArtists = try? threadedContext.fetch(artistRequest) {
            for artist in localArtists {
                // remove albums that are empty first
                if let albums = artist.albums as! Set<SBAlbum>? {
                    for album in albums {
                        if album.tracks?.count == 0 {
                            artist.removeFromAlbums(album)
                            album.artist = nil
                            threadedContext.delete(album)
                        }
                    }
                }
                
                // then see if it's empty so we can delete
                if let albums = artist.albums as! Set<SBAlbum>?, albums.count == 0 {
                    threadedContext.delete(artist)
                }
            }
        }
        // TODO: Delete covers that are only used locally or unreferenced too
        
        // inform user
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Tracks Deleted"
            if failedTracks.count > 0 {
                alert.informativeText = "Not all tracks could be deleted. \(failedTracks.count) remain."
            } else {
                alert.informativeText = "All cached tracks were deleted."
            }
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        saveThreadedContext()
        finish()
    }
}
