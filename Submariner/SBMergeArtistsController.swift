//
//  SBMergeArtistsController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-04.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

@objc(SBMergeArtistsController) class SBMergeArtistsController: SBSheetController {
    @objc var artists: [SBArtist] = []
    
    @IBOutlet var artistPopUpButton: NSPopUpButton!
    
    func mergeArtists(into targetArtist: SBArtist) {
        let otherArtists = artists
            .filter { $0 != targetArtist }
        let otherArtistAlbums = otherArtists
            .compactMap { $0.albums as? Set<SBAlbum> }
            .reduce(Set()) { acc, next in acc.union(next) }
        
        for album in otherArtistAlbums {
            album.artist = targetArtist
            targetArtist.addToAlbums(album)
        }
        
        for artist in otherArtists {
            targetArtist.managedObjectContext?.delete(artist)
        }
        
        try? targetArtist.managedObjectContext?.save()
    }
    
    override func openSheet(_ sender: Any!) {
        artistPopUpButton.menu!.items = artists.map { artist in
            let menuItem = NSMenuItem()
            menuItem.title = artist.itemName ?? "(unknown artist)"
            menuItem.representedObject = artist
            return menuItem
        }
        
        super.openSheet(sender)
    }
    
    override func closeSheet(_ sender: Any!) {
        if let targetArtist = artistPopUpButton.selectedItem?.representedObject as? SBArtist {
            mergeArtists(into: targetArtist)
        }
        super.closeSheet(sender)
    }
}
