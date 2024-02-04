//
//  SBAddServerPlaylistController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-04.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

@objc(SBAddServerPlaylistController) class SBAddServerPlaylistController: SBSheetController {
    @objc var server: SBServer?
    @objc var tracks: [SBTrack] = []
    
    @IBOutlet var playlistNameField: NSTextField!
    
    override func closeSheet(_ sender: Any!) {
        let name = playlistNameField.stringValue
        
        guard let server = self.server, name != "" else {
            return
        }
        
        server.createPlaylist(name: name, tracks: tracks)
        
        super.closeSheet(sender)
    }
}
