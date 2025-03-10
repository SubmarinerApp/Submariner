//
//  SBLibraryCleanupCoverPathsOperation.swift
//  Submariner
//
//  Created by Calvin Buckley on 2025-02-27.
//
//  Copyright (c) 2025 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//

import Cocoa
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBLibraryCleanupCoverPathsOperation")

class SBLibraryCleanupCoverPathsOperation: SBOperation {
    init(managedObjectContext: NSManagedObjectContext) {
        super.init(managedObjectContext: managedObjectContext, name: "Updating Cover Paths")
    }
    
    override func main() {
        defer {
            saveThreadedContext()
            finish()
        }
        DispatchQueue.main.async {
            self.operationInfo = "Cleaning cover paths"
        }
        cleanupCoverPaths()
        // XXX: Do tracks/albums/artists have similar issues?
    }
    
    private func replaceCoverPath(cover: SBCover, currentPath: NSString, newPath: String, fileName: String) {
        do {
            logger.info("Moving absolute cover path \"\(currentPath)\" to \"\(newPath)\", changing filename to \"\(fileName)\"")
            // If this exists already, then it might be fine? (XXX: Delete old if new exists?)
            if !FileManager.default.fileExists(atPath: newPath),
                let lastSlashOfNewPath = newPath.lastIndex(of: "/") {
                let directory = String(newPath[...lastSlashOfNewPath])
                try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                try FileManager.default.copyItem(atPath: currentPath as String, toPath: newPath)
            }
            cover.imagePath = fileName as NSString?
        } catch {
            // XXX: Surface alert?
            logger.error("Error moving file for cover: \(error, privacy: .public)")
        }
    }
    
    private func cleanupCoverPath(_ cover: SBCover) {
        let baseCoverDir = SBAppDelegate.coverDirectory
        let currentPath = cover.primitiveValue(forKey: "imagePath") as! NSString?
        // XXX: SBImportOperation was setting this, but SBSubsonicParsingOperation was not
        let fallbackPath = cover.primitiveValue(forKey: "path") as! NSString?
        if let currentPath = currentPath ?? fallbackPath, let coversDir = cover.coversDir() {
            // If the path matches the prefix, do it, otherwise move the file
            let fileName = currentPath.lastPathComponent
            if currentPath.hasPrefix(coversDir as String) {
                // Prefix matches, just update the DB entry
                logger.info("Changing absolute cover path \"\(currentPath)\" to \"\(fileName)\"")
                cover.imagePath = fileName as NSString?
            } else if currentPath.hasPrefix(baseCoverDir.path) {
                // This might be for a different server than ours (or none)
                // Common case was importing a remote track; we used to just
                // refer to the path of the cover on remote but now we don't
                logger.warning("Absolute cover path but for wrong server?: \(currentPath)")
                // Try to reset a cross-linked path
                // Remove the prefix (and the / after the prefix), but keep directory structure in case
                let pathWithoutPrefix = currentPath.substring(from: baseCoverDir.path.count + 1)
                let newPath = coversDir.appendingPathComponent(pathWithoutPrefix)
                replaceCoverPath(cover: cover, currentPath: currentPath, newPath: newPath, fileName: pathWithoutPrefix)
            } else {
                // Prefix doesn't match, move instead
                let newPath = coversDir.appendingPathComponent(fileName)
                replaceCoverPath(cover: cover, currentPath: currentPath, newPath: newPath, fileName: fileName)
            }
        }
    }
    
    private func cleanupCoverPaths() {
        let fetchRequest: NSFetchRequest<SBCover> = SBCover.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "imagePath BEGINSWITH %@", "/")
        if let covers = try? threadedContext.fetch(fetchRequest) {
            for cover in covers {
                cleanupCoverPath(cover)
            }
        }
    }
}
