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

@objc class SBServerHomeNavigationItem: SBServerNavigationItem {
    override var identifier: NSString { "ServerHome" }
}

@objc class SBServerLibraryNavigationItem: SBServerNavigationItem {
    override var identifier: NSString { "ServerLibrary" }
}

@objc class SBServerSearchNavigationItem: SBServerNavigationItem {
    override var identifier: NSString { "ServerSearch" }
    
    @objc var query: NSString
    
    @objc init(server: SBServer, query: NSString) {
        self.query = query
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

@objc class SBLocalMusicNavigationItem: SBNavigationItem {
    override var identifier: NSString { "Music" }
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
