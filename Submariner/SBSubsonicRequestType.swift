//
//  SBSubsonicRequestType.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-12-11.
//
//  Copyright (c) 2023 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Foundation

enum SBSubsonicRequestType: Equatable {
    case ping
    case getOpenSubsonicExtensions
    case getLicense
    case getCoverArt(id: String, forAlbumId: String?)
    case getPlaylists
    case getAlbumList(type: SBAlbumListType)
    case getPlaylist(id: String)
    case deletePlaylist(id: String)
    case createPlaylist(name: String, tracks: [SBTrack])
    case getNowPlaying
    case search(query: String)
    case setRating(id: String, rating: Int)
    case getPodcasts
    case scrobble(id: String)
    case scanLibrary
    case getScanStatus
    case replacePlaylist(id: String, tracks: [SBTrack])
    case updatePlaylist(id: String, name: String?, comment: String?, isPublic: Bool?, appending: [SBTrack]?, removing: [Int]?)
    case getArtists
    case getArtist(id: String)
    case getAlbum(id: String)
    case getTrack(id: String)
    case getDirectories
    case getDirectory(id: String)
    case star(tracks: [SBTrack], albums: [SBAlbum], artists: [SBArtist], directories: [SBDirectory])
    case unstar(tracks: [SBTrack], albums: [SBAlbum], artists: [SBArtist], directories: [SBDirectory])
    case getTopTracks(artistName: String)
    case getSimilarTracks(artist: SBArtist)
}

@objc enum SBAlbumListType: Int {
    @objc(SBSubsonicRequestGetAlbumListRandom) case random
    @objc(SBSubsonicRequestGetAlbumListNewest) case newest
    @objc(SBSubsonicRequestGetAlbumListHighest) case highest
    @objc(SBSubsonicRequestGetAlbumListStarred) case starred
    @objc(SBSubsonicRequestGetAlbumListFrequent) case frequent
    @objc(SBSubsonicRequestGetAlbumListRecent) case recent
}
