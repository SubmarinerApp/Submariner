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
    /// Tracks from the library views.
    static let libraryType = NSPasteboard.PasteboardType(rawValue: "com.submarinerapp.item-url-list")
    /// Tracks from the tracklist.
    static let tracklistType = NSPasteboard.PasteboardType(rawValue: "com.submariner.tracklist-indices")
}
