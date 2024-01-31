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

@objc class SBTracklistController: SBViewController, NSTableViewDelegate, NSTableViewDataSource, NSUserInterfaceValidations {
    @IBOutlet var playlistTableView: NSTableView!
    @IBOutlet var tracklistLengthView: NSTextField!
    
    @objc var databaseController: SBDatabaseController!
    
    private var notificationObserver: Any?
    
    override class func nibName() -> String! {
        "Tracklist"
    }
    
    override func loadView() {
        super.loadView()
        
        title = "Tracklist"
        
        playlistTableView.registerForDraggedTypes([.libraryType, .tracklistType])
        
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
    
    // #MARK: - IBActions
    
    @IBAction func playSelected(_ sender: Any) {
        if playlistTableView.selectedRow != -1 {
            SBPlayer.sharedInstance().play(index: playlistTableView.selectedRow)
        }
    }
    
    @IBAction func delete(_ sender: Any) {
        if playlistTableView.selectedRow != -1 {
            SBPlayer.sharedInstance().remove(trackIndexSet: playlistTableView.selectedRowIndexes)
        }
    }
    
    @IBAction func cleanTracklist(_ sender: Any) {
        SBPlayer.sharedInstance().clear()
    }
    
    @IBAction func showSelectedInFinder(_ sender: Any) {
        if playlistTableView.selectedRow != -1 {
            self.showTracksInFinder(SBPlayer.sharedInstance().playlist, selectedIndices: playlistTableView.selectedRowIndexes)
        }
    }
    
    @IBAction func showSelectedInLibrary(_ sender: Any) {
        if playlistTableView.selectedRow != -1 {
            // only makes sense with a single track
            let track = SBPlayer.sharedInstance().playlist[playlistTableView.selectedRow]
            databaseController.go(to: track)
        }
    }
    
    @IBAction func downloadSelected(_ sender: Any) {
        if playlistTableView.selectedRow != -1 {
            self.downloadTracks(SBPlayer.sharedInstance().playlist, selectedIndices: playlistTableView.selectedRowIndexes, databaseController: databaseController)
        }
    }
    
    @IBAction func createNewLocalPlaylistWithSelectedTracks(_ sender: Any) {
        if playlistTableView.selectedRow != -1 {
            self.createLocalPlaylist(withSelected: SBPlayer.sharedInstance().playlist, selectedIndices: playlistTableView.selectedRowIndexes, databaseController: databaseController)
        }
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
    
    // FIXME: Replace with tableView:pasteboardWriterForRow:?
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: rowIndexes, requiringSecureCoding: true)
            
            pboard.declareTypes([.tracklistType], owner: self)
            pboard.setData(data, forType: .tracklistType)
            
            return true
        } catch {
            return false
        }
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard row != -1 && dropOperation == .above else {
            return []
        }
        
        if let types = info.draggingPasteboard.types {
            if types.contains(.tracklistType) {
                return [.move]
            } else if types.contains(.libraryType) { // for cursor
                return [.copy]
            }
        }
        
        return []
    }
    
    static let allowedClasses = [NSIndexSet.self, NSArray.self, NSURL.self]
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let data = info.draggingPasteboard.data(forType: .tracklistType),
           let rowIndexes = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: SBTracklistController.allowedClasses,
                                                                    from: data) as? IndexSet {
            SBPlayer.sharedInstance().move(trackIndexSet: rowIndexes, index: row)
            
            // change selection to match new indices, since Array.move doesn't return them
            var newRow = row
            for index in rowIndexes {
                if index < newRow {
                    newRow -= 1
                }
            }
            let lastRow = newRow + rowIndexes.count - 1
            let newRange = newRow...lastRow
            let newIndexSet = IndexSet(integersIn: newRange)
            playlistTableView.selectRowIndexes(newIndexSet, byExtendingSelection: false)
        } else if let data = info.draggingPasteboard.data(forType: .libraryType),
                  let trackURLs = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: SBTracklistController.allowedClasses,
                                                                          from: data) as? [URL] {
            let tracks = trackURLs.map { url in
                // this should always be non-nil SBTrack since they should be dragged in from the library views
                let oid = self.managedObjectContext.persistentStoreCoordinator!.managedObjectID(forURIRepresentation: url)!
                return self.managedObjectContext.object(with: oid) as! SBTrack
            }
            
            SBPlayer.sharedInstance().add(tracks: tracks, index: row)
        }
        
        return true
    }
    
    // #MARK: - UI Validator
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        let selectedTrackRowStatus = self.selectedRowStatus(SBPlayer.sharedInstance().playlist,
                                                            selectedIndices: playlistTableView.selectedRowIndexes)
        let count = playlistTableView.numberOfSelectedRows
        
        switch (item.action) {
        case #selector(SBTracklistController.downloadSelected(_:)):
            return selectedTrackRowStatus.contains(.downloadable)
        case #selector(SBTracklistController.showSelectedInFinder(_:)):
            return selectedTrackRowStatus.contains(.showableInFinder)
        case #selector(SBTracklistController.playSelected(_:)),
            #selector(SBTracklistController.delete(_:)),
            #selector(SBTracklistController.createNewLocalPlaylistWithSelectedTracks(_:)):
            return count > 0
        case #selector(SBTracklistController.showSelectedInLibrary(_:)):
            return count == 1
        default:
            return true
        }
    }
}
