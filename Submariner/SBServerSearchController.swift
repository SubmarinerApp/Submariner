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
        willSet {
            self.willChangeValue(for: \.isStarred)
            self.willChangeValue(for: \.isAllTracks)
        }
        didSet {
            self.didChangeValue(for: \.isStarred)
            self.didChangeValue(for: \.isAllTracks)
            
            queryTypeButton.isHidden = true
            queryTypeButton.isEnabled = false
            switch self.searchResult?.query {
            case .search(query: let query) where query.isEmpty:
                self.title = "All Tracks"
                queryTypeButton.isHidden = false
                queryTypeButton.isEnabled = true
            case .search(let query):
                self.title = "Search Results for \(query)"
            case .similarTo(let artist):
                self.title = "Similar Tracks to \(artist.itemName ?? "(unknown artist)")"
            case .topTracksFor(let artistName):
                self.title = "Top Tracks for \(artistName)"
            case .starred:
                self.title = "Starred Tracks"
                queryTypeButton.isHidden = false
                queryTypeButton.isEnabled = true
            default:
                self.title = "Search Results"
            }
        }
    }
    
    var shouldInfiniteScroll: Bool = false
    
    @IBOutlet var tracksTableView: NSTableView!
    @IBOutlet var tracksController: NSArrayController!
    
    @IBOutlet var queryTypeButton: NSButton!
    @IBOutlet var queryTypePopover: NSPopover!
    
    var selectionObserver: NSKeyValueObservation?
    var boundsObserver: NSObjectProtocol?
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
                    self.shouldInfiniteScroll = results.paginatable && results.returnedTracks > 0;
                    // Load more tracks if we still haven't filled the visible table
                    self.loadWhenAtBottom()
                }
            }
        }
        
        selectionObserver = tracksController.observe(\.selectedObjects) { arrayController, change in
            NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: arrayController.selectedObjects)
        }
        
        // this is the NSClipView
        let observedBoundsView = tracksTableView.enclosingScrollView!.contentView
        boundsObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: observedBoundsView, queue: nil) { notification in
            self.loadWhenAtBottom()
        }
    }
    
    func loadWhenAtBottom() {
        guard shouldInfiniteScroll else {
            return
        }
        
        let scrollView = self.tracksTableView.enclosingScrollView!
        let documentView = scrollView.documentView!
        let clipView = scrollView.contentView
        
        // The coordinate space of the clip/scroll/document view isn't obvious,
        // and NSScrollView doesn't make it easy. See https://stackoverflow.com/a/56080733
        let verticalPosition = clipView.bounds.origin.y + clipView.bounds.height
        if verticalPosition == documentView.bounds.height {
            shouldInfiniteScroll = false
            server.updateSearch(existingResult: self.searchResult!)
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
    
    @IBAction func showQueryTypePopover(_ sender: Any) {
        guard !queryTypePopover.isShown else {
            queryTypePopover.close()
            return
        }
        guard let button = sender as? NSButton else {
            return
        }
        queryTypePopover.show(relativeTo: button.visibleRect, of: button, preferredEdge: .minY)
    }
    
    // #MARK: - NSTableView Delegate
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard tableView == tracksTableView else {
            return nil
        }
        
        return SBLibraryItemPasteboardWriter(item: tracks[row], index: row)
    }
    
    // #MARK: - Popover Radio Buttons
    // XXX: Does bindings + variables make sense over an IBAction? Would mean making some IBOutlets instead...
    
    @objc dynamic var isAllTracks: Bool {
        get {
            if let query = self.searchResult?.query, case let .search(query: queryContents) = query, queryContents.isEmpty {
                return true
            }
            return false
        }
        set {
            guard newValue else {
                return
            }
            let navItem = SBServerSearchNavigationItem(server: self.server, queryType: .search(query: ""))
            databaseController.navigate(to: navItem)
        }
    }
    
    @objc dynamic var isStarred: Bool {
        get {
            return self.searchResult?.query == .starred
        }
        set {
            guard newValue else {
                return
            }
            let navItem = SBServerSearchNavigationItem(server: self.server, queryType: .starred)
            databaseController.navigate(to: navItem)
        }
    }
}
