//
//  SBLibraryCleanupOrphansOperation.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-06-11.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBLibraryCleanupOrphansOperation")

class SBLibraryCleanupOrphansOperation: SBOperation {
    init(managedObjectContext: NSManagedObjectContext) {
        super.init(managedObjectContext: managedObjectContext, name: "Deleting Orphaned Objects")
    }
    
    override func main() {
        defer {
            saveThreadedContext()
            finish()
        }
        logger.info("Deleting orphan playlists")
        cleanupOrphanPlaylists()
        logger.info("Deleting orphan covers")
        cleanupOrphanCovers()
        // XXX: Do tracks/albums/artists have similar issues?
    }
    
    private func cleanupOrphanPlaylists() {
        // look for orphaned playlists as part of a delete
        let fetchRequest: NSFetchRequest<SBPlaylist> = SBPlaylist.fetchRequest()
        // Server playlists have a server relation, local playlists are in the playlist SBSection
        fetchRequest.predicate = NSPredicate(format: "(server == nil) && (section == nil)")
        if let playlists = try? threadedContext.fetch(fetchRequest) {
            for playlist in playlists {
                let name = playlist.resourceName ?? "<nil>"
                logger.info("Deleting orphan playlist \"\(name, privacy: .public)\"")
                self.threadedContext.delete(playlist)
            }
        }
    }
    
    private func otherCoversUsingFile(_ cover: SBCover) -> Bool {
        // imagePath returns absolute paths, but play it safe. perhaps we can clean up file orphans not in the DB later
        guard let imageFile = cover.imagePath?.lastPathComponent else {
            return false
        }
        
        let fetchRequest: NSFetchRequest<SBCover> = SBCover.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "(imagePath ENDSWITH %@)", imageFile)
        if let covers = try? threadedContext.fetch(fetchRequest) {
            logger.debug("\(covers.count) covers with the filename \(imageFile) found")
            return covers.count > 1
        }
        
        return false
    }
    
    private func cleanupOrphanCovers() {
        let fetchRequest: NSFetchRequest<SBCover> = SBCover.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "(track == nil) && (album == nil)")
        if let covers = try? threadedContext.fetch(fetchRequest) {
            for cover in covers {
                let name = cover.itemId ?? "<nil>"
                logger.info("Deleting orphan cover \"\(name, privacy: .public)\"")
                if let path = cover.imagePath as? String, FileManager.default.fileExists(atPath: path),
                   !otherCoversUsingFile(cover) {
                    logger.warning("Should delete orphan cover file at \(path)")
                    // safe to delete - we avoid deleting if any duplicate filename could possibly exist.
                    // won't get it all, but avoids damage
                    try? FileManager.default.removeItem(atPath: path)
                }
                self.threadedContext.delete(cover)
            }
        }
    }
}
