//
//  SBServerSearchController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-01-01.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

@objc class SBServerSearchController: SBServerViewController, NSTableViewDataSource, NSUserInterfaceValidations {
    @objc dynamic var searchResult: SBSearchResult?
    
    @objc var databaseController: SBDatabaseController!
    
    @IBOutlet var tracksTableView: NSTableView!
    @IBOutlet var tracksController: NSArrayController!
    
    var selectionObserver: NSKeyValueObservation?
    var resultObserver: NSObjectProtocol?
    
    override class func nibName() -> String! {
        "ServerSearch"
    }
    
    override func loadView() {
        super.loadView()
        
        resultObserver = NotificationCenter.default.addObserver(forName: .SBSubsonicSearchResultUpdated, object: nil, queue: nil) { notification in
            DispatchQueue.main.async {
                if let results = notification.object as! SBSearchResult? {
                    results.fetchTracks(managedObjectContext: self.managedObjectContext)
                    self.searchResult = results
                }
            }
        }
        
        tracksTableView.registerForDraggedTypes([SBTracklistButton.libraryType])
        
        selectionObserver = tracksController.observe(\.selectedObjects) { arrayController, change in
            NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: arrayController.selectedObjects)
        }
    }
    
    // this may be better
    override var title: String? {
        get {
            if let searchResult = self.searchResult {
                return "Search Results for \(searchResult.query)"
            } else {
                return "Search Results"
            }
        }
        set {}
    }
    
    // #MARK: - Typed Wrappers
    
    // should be empty if no results
    var tracks: [SBTrack]! {
        tracksController.arrangedObjects as? [SBTrack]
    }
    
    var selectedTracks: [SBTrack]! {
        tracksController.selectedObjects as? [SBTrack]
    }
    
    // #MARK: - IBActions
    
    @IBAction func playSelected(_ sender: Any) {
        if tracksTableView.selectedRow != -1 {
            SBPlayer.sharedInstance().play(tracks: tracks, startingAt: tracksTableView.selectedRow)
        }
    }
    
    @IBAction func addSelectedToTracklist(_ sender: Any) {
        SBPlayer.sharedInstance().add(tracks: selectedTracks, replace: false)
    }
    
    @IBAction func downloadSelected(_ sender: Any) {
        if tracksTableView.selectedRow != -1 {
            self.downloadTracks(selectedTracks, databaseController: databaseController)
        }
    }
    
    @IBAction func showSelectedInFinder(_ sender: Any) {
        if tracksTableView.selectedRow != -1 {
            self.showTracksInFinder(selectedTracks)
        }
    }
    
    @IBAction func showSelectedInLibrary(_ sender: Any) {
        if let selectedTrack = selectedTracks.first {
            databaseController.go(to: selectedTrack)
        }
    }
    
    @IBAction func createNewLocalPlaylistWithSelectedTracks(_ sender: Any) {
        self.createLocalPlaylist(withSelected: selectedTracks, databaseController: databaseController)
    }
    
    // #MARK: - NSTableView Delegate
    
    // FIXME: Replace with tableView:pasteboardWriterForRow:?
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        guard tableView == tracksTableView else {
            return false
        }
        
        let desiredTracks = tracks[rowIndexes].map { $0.objectID.uriRepresentation() }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: desiredTracks, requiringSecureCoding: true)
            
            pboard.declareTypes([SBTracklistButton.libraryType], owner: self)
            pboard.setData(data, forType: SBTracklistButton.libraryType)
            
            return true
        } catch {
            return false
        }
    }
    
    // #MARK: - UI Validator
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        let selectedTrackRowStatus = self.selectedRowStatus(selectedTracks)
        
        switch (item.action) {
        case #selector(SBServerSearchController.downloadSelected(_:)):
            return selectedTrackRowStatus.contains(.downloadable)
        case #selector(SBServerSearchController.showSelectedInFinder(_:)):
            return selectedTrackRowStatus.contains(.showableInFinder)
        case #selector(SBServerSearchController.addSelectedToTracklist(_:)),
            #selector(SBServerSearchController.playSelected(_:)),
            #selector(SBServerSearchController.createNewLocalPlaylistWithSelectedTracks(_:)):
            return selectedTracks.count > 0
        case #selector(SBServerSearchController.showSelectedInLibrary(_:)):
            return selectedTracks.count == 1
        default:
            return true
        }
    }
}
