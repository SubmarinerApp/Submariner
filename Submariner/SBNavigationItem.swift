//
//  SBNavigationItem.swift
//  Submariner
//
//  Created by Calvin Buckley on 2022-11-02.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc class SBServerPodcastsNavigationItem: SBServerNavigationItem {
    override var identifier: NSString { "ServerPodcasts" }
}

@objc class SBServerDirectoriesNavigationItem: SBServerNavigationItem {
    override var identifier: NSString { "ServerDirectories" }
}

@objc class SBServerHomeNavigationItem: SBServerNavigationItem {
    override var identifier: NSString { "ServerHome" }
}

@objc class SBServerLibraryNavigationItem: SBServerNavigationItem {
    override var identifier: NSString { "ServerLibrary" }
    
    @objc var selectedMusicItem: SBMusicItem?
}

@objc class SBServerSearchNavigationItem: SBServerNavigationItem {
    override var identifier: NSString { "ServerSearch" }
    
    var query: SBSearchResult.QueryType
    
    // HACK: Workaround for ObjC not having sum types (remove when we can just expose query to DatabaseController)
    @objc var searchQuery: NSString? {
        if case let .search(query) = self.query {
            return query as NSString
        }
        return nil
    }
    
    @objc var topTracksForArtist: NSString? {
        if case let .topTracksFor(artistName) = self.query {
            return artistName as NSString
        }
        return nil
    }
    
    @objc init(server: SBServer, query: String) {
        self.query = .search(query: query)
        super.init(server: server)
    }
    
    @objc init(server: SBServer, topTracksFor artistName: String) {
        self.query = .topTracksFor(artistName: artistName)
        super.init(server: server)
    }
}

@objc class SBPlaylistNavigationItem: SBNavigationItem {
    override var identifier: NSString { "Playlist" }
    
    @objc var playlist: SBPlaylist
    
    @objc init(playlist: SBPlaylist) {
        self.playlist = playlist
    }
}

@objc class SBLocalSearchNavigationItem: SBNavigationItem {
    override var identifier: NSString { "MusicSearch" }
    
    @objc var query: NSString
    
    @objc init(query: NSString) {
        self.query = query
    }
}

@objc class SBDownloadsNavigationItem: SBNavigationItem {
    override var identifier: NSString { "Downloads" }
}

@objc class SBOnboardingNavigationItem: SBNavigationItem {
    override var identifier: NSString { "Onboarding" }
}

@objc class SBLocalMusicNavigationItem: SBNavigationItem {
    override var identifier: NSString { "Music" }
    
    @objc var selectedMusicItem: SBMusicItem?
}

@objc class SBServerNavigationItem: SBNavigationItem {
    @objc var server: SBServer
    
    @objc init(server: SBServer) {
        self.server = server
    }
}

@objc class SBNavigationItem: NSObject {
    @objc var identifier: NSString { "" }
}
