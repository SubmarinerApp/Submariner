//
//  SBTracklistController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-01-31.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

@objc class SBTracklistController: SBViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet var playlistTableView: NSTableView!
    @IBOutlet var tracklistLengthView: NSTextField!
    
    private var notificationObserver: Any?
    
    override class func nibName() -> String! {
        "Tracklist"
    }
    
    override func loadView() {
        super.loadView()
        
        title = "Tracklist"
        
        playlistTableView.registerForDraggedTypes([.libraryItems, .libraryItem])
        
        notificationObserver = NotificationCenter.default.addObserver(forName: .SBPlayerPlaylistUpdated,
                                                                      object: nil,
                                                                      queue: nil,
                                                                      using: { notification in
            self.playlistTableView.reloadData()
        })
        
        tracklistLengthView.bind(.value,
                                 to: SBPlayer.sharedInstance(),
                                 withKeyPath: "playlist",
                                 options: [.valueTransformerName: "SBTrackListLengthTransformer"])
    }
    
    // #MARK: - Properties
    
    override var tracks: [SBTrack]! {
        return SBPlayer.sharedInstance().playlist
    }
    
    override var selectedTracks: [SBTrack]! {
        return SBPlayer.sharedInstance().playlist[playlistTableView.selectedRowIndexes]
    }
    
    override var selectedTrackRow: Int {
        playlistTableView.selectedRow
    }
    
    // #MARK: - IBActions
    
    override func trackDoubleClick(_ sender: Any!) {
        // We have to override this because if the replace tracklist option is enabled,
        // it duplicates the tracklist
        SBPlayer.sharedInstance().play(index: self.selectedTrackRow)
    }
    
    @IBAction func delete(_ sender: Any) {
        if playlistTableView.selectedRow != -1 {
            SBPlayer.sharedInstance().remove(trackIndexSet: playlistTableView.selectedRowIndexes)
        }
    }
    
    @IBAction func cleanTracklist(_ sender: Any) {
        SBPlayer.sharedInstance().clear()
    }
    
    // #MARK: - NSTableView DataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return SBPlayer.sharedInstance().playlist.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        // XXX: less ugly switch
        switch (tableColumn?.identifier.rawValue) {
        case "isPlaying" where row == SBPlayer.sharedInstance().currentIndex:
            return NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: "Playing")
        case "title":
            return SBPlayer.sharedInstance().playlist[row].itemName
        case "artist":
            let track = SBPlayer.sharedInstance().playlist[row]
            if let artistName = track.artistName, artistName != "" {
                return artistName
            } else {
                return track.album?.artist?.itemName
            }
        case "duration":
            return SBPlayer.sharedInstance().playlist[row].durationString
        case "online":
            let track = SBPlayer.sharedInstance().playlist[row]
            if track.localTrack != nil || track.isLocal == true {
                return NSImage(systemSymbolName: "bolt.horizontal.fill", accessibilityDescription: "Cached")
            } else {
                return NSImage(systemSymbolName: "bolt.horizontal", accessibilityDescription: "Online")
            }
        default:
            return nil
        }
    }
    
    // #MARK: - NSTableView Delegate
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        if tableView == playlistTableView {
            let track = SBPlayer.sharedInstance().playlist[row]
            return SBLibraryItemPasteboardWriter(item: track, index: row)
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard row != -1 && dropOperation == .above else {
            return []
        }
        
        if let sourceTable = info.draggingSource as? SBTableView, sourceTable == playlistTableView {
            return .move
        } else if info.draggingPasteboard.libraryItems() != nil {
            return .copy
        }
        return []
    }
    
    static let allowedClasses = [NSIndexSet.self, NSArray.self, NSURL.self]
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        // XXX: For some reason, draggingSourceOperationMask has all bits set?
        if let sourceTable = info.draggingSource as? SBTableView, sourceTable == playlistTableView {
            let rowIndexes = info.draggingPasteboard.rowIndices()
            let newIndexSet = SBPlayer.sharedInstance().move(trackIndexSet: rowIndexes, index: row)
            playlistTableView.selectRowIndexes(newIndexSet, byExtendingSelection: false)
        } else if let tracks = info.draggingPasteboard.libraryItems(managedObjectContext: self.managedObjectContext) {
            // handles both kinds of library track
            SBPlayer.sharedInstance().add(tracks: tracks, index: row)
        }
        
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: selectedTracks)
    }
    
    // #MARK: - UI Validator
    
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        let count = playlistTableView.numberOfSelectedRows
        
        switch (item.action) {
        case #selector(SBTracklistController.delete(_:)):
            return count > 0
        default:
            return super.validateUserInterfaceItem(item)
        }
    }
}
