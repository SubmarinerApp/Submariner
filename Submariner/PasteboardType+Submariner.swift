//
//  PasteboardType+Submariner.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-01-01.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

extension NSPasteboard.PasteboardType {
    /// Tracks from the library views, represented as an array of track object IDs as a URL.
    ///
    /// This was used for i.e. `tableView:writeRowsWithIndexes:toPasteboard`, which worked with every row at once and made a single pasteboard item.
    /// It's still used for dragging albums, but things using `tableView:pasteboardWriterForRow:` should be using `.libraryItemType` instead.
    static let libraryItems = NSPasteboard.PasteboardType(rawValue: "com.submarinerapp.item-url-list")
    /// A track from the library views, represented as a track object ID as a string.
    ///
    /// Usually multiple of these will exist on a pasteboard.
    static let libraryItem = NSPasteboard.PasteboardType(rawValue: "com.submarinerapp.item-url-string")
    /// The index of a row, as a raw integer in a Data wrapper.
    static let rowIndex = NSPasteboard.PasteboardType(rawValue: "com.submarinerapp.row-index")
    /// A playlist. Mostly used to check if a playlist is being dropped on itself or another playlist.
    static let playlist = NSPasteboard.PasteboardType(rawValue: "com.submarinerapp.playlist")
}
