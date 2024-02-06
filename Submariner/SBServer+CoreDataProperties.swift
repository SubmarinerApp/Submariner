//
//  SBServer+CoreDataProperties.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData


extension SBServer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SBServer> {
        return NSFetchRequest<SBServer>(entityName: "Server")
    }

    @NSManaged public var apiVersion: String?
    @NSManaged public var licenseEmail: String?
    @NSManaged public var useTokenAuth: NSNumber?
    @NSManaged public var lastIndexesDate: Date?
    @NSManaged public var licenseDate: Date?
    @NSManaged public var url: String?
    //@NSManaged public var password: String?
    @NSManaged public var username: String?
    @NSManaged public var isValidLicense: NSNumber?
    //@NSManaged public var playlists: NSSet?
    @NSManaged public var tracks: NSSet?
    @NSManaged public var podcasts: NSSet?
    @NSManaged public var nowPlayings: NSSet?
    @NSManaged public var home: SBHome?
    @NSManaged public var indexes: NSSet?
    @NSManaged public var directories: NSSet?

}

// MARK: Generated accessors for directories
extension SBServer {

    @objc(addDirectoriesObject:)
    @NSManaged public func addToDirectories(_ value: SBDirectory)

    @objc(removeDirectoriesObject:)
    @NSManaged public func removeFromDirectories(_ value: SBDirectory)

    @objc(addDirectories:)
    @NSManaged public func addToDirectories(_ values: NSSet)

    @objc(removeDirectories:)
    @NSManaged public func removeFromDirectories(_ values: NSSet)

}

// MARK: Generated accessors for playlists
extension SBServer {

    @objc(addPlaylistsObject:)
    @NSManaged public func addToPlaylists(_ value: SBPlaylist)

    @objc(removePlaylistsObject:)
    @NSManaged public func removeFromPlaylists(_ value: SBPlaylist)

    @objc(addPlaylists:)
    @NSManaged public func addToPlaylists(_ values: NSSet)

    @objc(removePlaylists:)
    @NSManaged public func removeFromPlaylists(_ values: NSSet)

}

// MARK: Generated accessors for tracks
extension SBServer {

    @objc(addTracksObject:)
    @NSManaged public func addToTracks(_ value: SBTrack)

    @objc(removeTracksObject:)
    @NSManaged public func removeFromTracks(_ value: SBTrack)

    @objc(addTracks:)
    @NSManaged public func addToTracks(_ values: NSSet)

    @objc(removeTracks:)
    @NSManaged public func removeFromTracks(_ values: NSSet)

}

// MARK: Generated accessors for podcasts
extension SBServer {

    @objc(addPodcastsObject:)
    @NSManaged public func addToPodcasts(_ value: SBPodcast)

    @objc(removePodcastsObject:)
    @NSManaged public func removeFromPodcasts(_ value: SBPodcast)

    @objc(addPodcasts:)
    @NSManaged public func addToPodcasts(_ values: NSSet)

    @objc(removePodcasts:)
    @NSManaged public func removeFromPodcasts(_ values: NSSet)

}

// MARK: Generated accessors for nowPlayings
extension SBServer {

    @objc(addNowPlayingsObject:)
    @NSManaged public func addToNowPlayings(_ value: SBNowPlaying)

    @objc(removeNowPlayingsObject:)
    @NSManaged public func removeFromNowPlayings(_ value: SBNowPlaying)

    @objc(addNowPlayings:)
    @NSManaged public func addToNowPlayings(_ values: NSSet)

    @objc(removeNowPlayings:)
    @NSManaged public func removeFromNowPlayings(_ values: NSSet)

}

// MARK: Generated accessors for indexes
extension SBServer {

    @objc(addIndexesObject:)
    @NSManaged public func addToIndexes(_ value: SBIndex)

    @objc(removeIndexesObject:)
    @NSManaged public func removeFromIndexes(_ value: SBIndex)

    @objc(addIndexes:)
    @NSManaged public func addToIndexes(_ values: NSSet)

    @objc(removeIndexes:)
    @NSManaged public func removeFromIndexes(_ values: NSSet)

}
