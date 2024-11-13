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

@objc class SBServerSearchController: SBServerViewController, NSTableViewDataSource {
    @objc dynamic var searchResult: SBSearchResult? {
        didSet {
            switch self.searchResult?.query {
            case .search(let query):
                self.title = "Search Results for \(query)"
            case .topTracksFor(let artistName):
                self.title = "Top Tracks for \(artistName)"
            default:
                self.title = "Search Results"
            }
        }
    }
    
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
        
        selectionObserver = tracksController.observe(\.selectedObjects) { arrayController, change in
            NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: arrayController.selectedObjects)
        }
    }
    
    // #MARK: - Properties
    
    // should be empty if no results
    override var tracks: [SBTrack]! {
        tracksController.arrangedObjects as? [SBTrack]
    }
    
    override var selectedTracks: [SBTrack]! {
        tracksController.selectedObjects as? [SBTrack]
    }
    
    override var selectedTrackRow: Int {
        tracksTableView.selectedRow
    }
    
    // #MARK: - IBActions
    
    // #MARK: - NSTableView Delegate
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard tableView == tracksTableView else {
            return nil
        }
        
        return SBLibraryItemPasteboardWriter(item: tracks[row], index: row)
    }
}
