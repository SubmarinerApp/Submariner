//
//  SBPlaylistPasteboardWriter.swift
//  Submariner
//
//  Created by Calvin Buckley on 2025-03-11.
//
//  Copyright (c) 2025 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

@objc class SBPlaylistPasteboardWriter: NSObject, NSPasteboardWriting {
    var playlist: SBPlaylist
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.libraryItems, .playlist]
    }
    
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .libraryItems:
            guard let items = playlist.tracks else {
                return nil
            }
            let uris = items.map { $0.objectID.uriRepresentation() }
            // We can't put NSURLs into what can be represented in a plist, so just send data,
            // as the other end will unarchive like always
            return try? NSKeyedArchiver.archivedData(withRootObject: uris, requiringSecureCoding: true)
        case .playlist:
            return (playlist.objectID.uriRepresentation() as NSURL).pasteboardPropertyList(forType: .URL)
        default:
            return nil
        }
    }
    
    @objc init(playlist: SBPlaylist) {
        self.playlist = playlist
    }
}
