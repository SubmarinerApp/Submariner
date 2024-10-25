//
//  SBServerDirectoryController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-05.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa
import SwiftUI
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBServerDirectoryController")

@objc class SBServerDirectoryController: SBViewController, ObservableObject {
    @objc static override func nibName() -> String! {
        nil
    }
    
    @objc override func loadView() {
        let rootView = RootDirectoriesView(serverDirectoryController: self)
            .environment(\.managedObjectContext, self.managedObjectContext)
        view = NSHostingView(rootView: rootView)
        // because the SwiftUI view doesn't take the whole space up,
        // we need this for window/sidebar adjustments to keep that view centred
        view.autoresizingMask = [.maxXMargin, .maxYMargin, .minXMargin, .minYMargin]
        
        title = "Directories"
    }
    
    @objc @Published var server: SBServer? {
        didSet {
            if let server = self.server, let name = server.resourceName {
                title = "Directories for \(name)"
            }
        }
    }
    
    var _selectedDirectories: [SBDirectory] = []
    override var selectedDirectories: [SBDirectory]! {
        self._selectedDirectories
    }
    
    var _selectedTracks: [SBTrack] = []
    override var selectedTracks: [SBTrack]! {
        self._selectedTracks
    }
    
    override var selectedMusicItems: [any SBStarrable]! {
        self.selectedDirectories + self.selectedTracks
    }
    
    // #MARK: - Actions
    
    // FIXME: duplicated in server user view controller
    
    func play(_ tracks: [SBTrack], startingAt index: Int = 0) {
        SBPlayer.sharedInstance().play(tracks: tracks, startingAt: index)
    }
    
    func addToTracklist(_ tracks: [SBTrack]) {
        SBPlayer.sharedInstance().add(tracks: tracks, replace: false)
    }
    
    func addToNewLocalPlaylist(_ tracks: [SBTrack]) {
        self.createLocalPlaylist(withSelected: tracks, databaseController: databaseController)
    }
    
    func addToNewServerPlaylist(_ tracks: [SBTrack]) {
        databaseController?.addServerPlaylistController.server = server
        databaseController?.addServerPlaylistController.tracks = tracks
        databaseController?.addServerPlaylistController.openSheet(self)
    }
    
    func download(_ tracks: [SBTrack]) {
        self.downloadTracks(tracks, databaseController: databaseController)
    }
    
    func showInLibrary(track: SBTrack) {
        databaseController?.go(to: track)
    }
    
    // #MARK: - SwiftUI
    
    struct FavouriteToggle: View {
        @ObservedObject var starrable: SBMusicItem
        
        @Binding var hovering: Bool
        
        var body: some View {
            // TODO: This should have some kind of empty space when not hovering,
            // so text doesn't shift about
            if hovering, let starrable = starrable as? any SBStarrable {
                let helpText = starrable.starredBool ? "Favourited" : "Not Favourited"
                if starrable.starredBool {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                        .shadow(color: .black, radius: 1)
                        .onTapGesture {
                            starrable.starredBool = false
                        }
                        .help(helpText)
                } else {
                    Image(systemName: "heart")
                        .foregroundStyle(.pink)
                        .shadow(color: .black, radius: 1)
                        .onTapGesture {
                            starrable.starredBool = true
                        }
                        .help(helpText)
                }
            }
        }
    }
    
    struct DirectoryItem: View {
        let directory: SBDirectory
        
        @State var hovering = false
        
        var body: some View {
            HStack {
                Image(systemName: "folder")
                Text(directory.itemName ?? "")
                Spacer()
                FavouriteToggle(starrable: directory, hovering: $hovering)
            }
            .onHover { _ in
                self.hovering.toggle()
            }
        }
    }
    
    struct TrackItem: View {
        let track: SBTrack
        
        @State var hovering = false
        
        var body: some View {
            HStack {
                Image(systemName: "music.note")
                if let path = track.path as? NSString {
                    Text(path.lastPathComponent)
                }
                Spacer()
                FavouriteToggle(starrable: track, hovering: $hovering)
            }
            .onHover { _ in
                self.hovering.toggle()
            }
        }
    }
    
    struct MusicItem: View {
        let item: SBMusicItem
        
        var body: some View {
            if let directory = item as? SBDirectory {
                DirectoryItem(directory: directory)
            } else if let track = item as? SBTrack {
                TrackItem(track: track)
            }
        }
    }
    
    struct BottomText: View {
        let count: Int
        
        var body: some View {
            // XXX: ugly for localization
            Text("\(count) item\(count == 1 ? "" : "s")")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            // keep same font/baseline as the nibs w/ System 13pt
                .font(.system(size: 13))
                .padding(.bottom, 4)
                .frame(height: 41)
        }
    }
    
    struct DirectoryContextMenu: View {
        let serverDirectoryController: SBServerDirectoryController
        
        let tracks: [SBTrack]
        let status: SBSelectedRowStatus
        
        static func gather(_ items: [SBMusicItem]) -> [SBTrack] {
            // XXX: would like to use
            var tracks: [SBTrack] = []
            for item in items {
                if let directory = item as? SBDirectory {
                    tracks.append(contentsOf: gather(directory.children))
                } else if let track = item as? SBTrack {
                    tracks.append(track)
                }
            }
            return tracks
        }
        
        init(selected: Set<SBMusicItem>, serverDirectoryController: SBServerDirectoryController) {
            self.serverDirectoryController = serverDirectoryController
            
            self.tracks = DirectoryContextMenu.gather(Array(selected))
            self.status = serverDirectoryController.selectedRowStatus(self.tracks)
        }
        
        var body: some View {
            Button {
                serverDirectoryController.play(tracks)
            } label: {
                Text("Play Selection")
            }
            .disabled(tracks.count == 0)
            Button {
                serverDirectoryController.addToTracklist(tracks)
            } label: {
                Text("Add Selection to Tracklist")
            }
            .disabled(tracks.count == 0)
            Divider()
            Button {
                serverDirectoryController.addToNewLocalPlaylist(tracks)
            } label: {
                Text("Create Playlist with Selected")
            }
            .disabled(tracks.count == 0)
            Button {
                serverDirectoryController.addToNewServerPlaylist(tracks)
            } label: {
                Text("Create Server Playlist with Selected")
            }
            .disabled(tracks.count == 0)
            Divider()
            Button {
                serverDirectoryController.download(tracks)
            } label: {
                Text("Download")
            }
            .disabled(!status.contains(.downloadable))
            Button {
                // will always succeedd since tracks must be 1
                serverDirectoryController.showInLibrary(track: tracks.first!)
            } label: {
                Text("Show in Library")
            }
            .disabled(tracks.count != 1)
            Button {
                serverDirectoryController.showTracksInFinder(tracks)
            } label: {
                Text("Show in Finder")
            }
            .disabled(!status.contains(.showableInFinder))
        }
    }
    
    struct DragPreview: View {
        let items: [SBMusicItem]
        
        var body: some View {
            VStack(alignment: .leading) {
                ForEach(items) {
                    MusicItem(item: $0)
                        .padding(1)
                }
            }
            .padding(1)
            .background(.selection)
            .cornerRadius(5.0)
            //.frame(maxWidth: 500, maxHeight: 500)
        }
    }
    
    struct ChildDirectoriesView: View {
        let serverDirectoryController: SBServerDirectoryController
        
        let directory: SBDirectory
        
        let directories: [SBMusicItem]
        @State var selected: Set<SBMusicItem> = Set()
        
        // HORRIFIC HACK: SwiftUI won't update a computed property.
        // Since we want to have an updated list when fetching the directory,
        // we have to get a new list when it updates.
        // Annoyingly, posting from end-of-XML parsing like other things didn't work.
        // The easiest way is to just wait for MOC saves,
        // since the new items should be there by the time it saves.
        // This could be made more specific notification or object wise.
        @State var children: [SBMusicItem] = []
        
        var publisher = NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: RunLoop.main)
        
        func updateSelection(newValue: Set<SBMusicItem>) {
            // In the future, it would be nice to show directory info in the inspector.
            if let directory = newValue.first as? SBDirectory, let id = directory.itemId {
                serverDirectoryController._selectedTracks = []
                serverDirectoryController._selectedDirectories = [directory]
                directory.server?.getServerDirectory(id: id)
                children = directory.children
                NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: [])
            } else if newValue.isEmpty {
                // use ourselves for current selection, so favourites menu works
                serverDirectoryController._selectedTracks = []
                serverDirectoryController._selectedDirectories = [directory]
                NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: [])
            } else if let tracks = newValue as? Set<SBTrack> {
                let tracksArray = Array(tracks)
                serverDirectoryController._selectedTracks = tracksArray
                serverDirectoryController._selectedDirectories = []
                NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: tracksArray)
            }
        }
        
        func selectedArray() -> [SBMusicItem] {
            return Array(selected)
                .sorted {
                    let lhs = $0.path ?? ""
                    let rhs = $1.path ?? ""
                    return lhs.localizedCompare(rhs) == .orderedAscending
                }
        }
        
        var body: some View {
            HStack(spacing: 1) {
                VStack(spacing: 0) {
                    List(directories, id: \.self, selection: $selected) { item in
                        MusicItem(item: item)
                        .onTapGesture(count: 2) {
                            if !selected.isEmpty {
                                let tracks = DirectoryContextMenu.gather(selectedArray())
                                var index = 0
                                if let actingTrack = item as? SBTrack {
                                    index = tracks.firstIndex(of: actingTrack) ?? 0
                                }
                                serverDirectoryController.play(tracks, startingAt: index)
                            }
                        }
                        .onDrag {
                            let items = selected.contains(item) ? selectedArray() : [item]
                            let urls = DirectoryContextMenu.gather(items)
                                .map { $0.objectID.uriRepresentation() }
                            let type = NSPasteboard.PasteboardType.libraryItems.rawValue
                            return NSItemProvider(item: urls as NSArray,
                                                  typeIdentifier: type)
                        } preview: {
                            if selected.contains(item) {
                                DragPreview(items: selectedArray())
                            } else {
                                DragPreview(items: [item])
                            }
                        }
                    }
                    .contextMenu {
                        DirectoryContextMenu(selected: selected, serverDirectoryController: serverDirectoryController)
                    }
                    .onChange(of: directories) { _ in
                        // Invalidate to avoid changes to the left of us from keeping new columns around.
                        selected = Set()
                    }
                    .onChange(of: selected) { newValue in
                        updateSelection(newValue: newValue)
                    }
                    .onAppear {
                        updateSelection(newValue: selected)
                    }
                    .frame(width: 250)
                    BottomText(count: directories.count)
                }
                if selected.count == 1, let directory = selected.first as? SBDirectory {
                    ChildDirectoriesView(serverDirectoryController: serverDirectoryController,
                                         directory: directory,
                                         directories: children)
                    .onReceive(publisher) { notification in
                        children = directory.children
                    }
                }
            }
        }
    }
    
    struct RootDirectoriesView: View {
        @Environment(\.managedObjectContext) var moc
        
        let serverDirectoryController: SBServerDirectoryController
        
        // unfortunate limitations: see ServerUserViewController
        @FetchRequest(
            sortDescriptors: [NSSortDescriptor.init(key: "itemName", ascending: true)],
            predicate: NSPredicate.init(format: "(parentDirectory != nil)")
        ) var rootDirectories: FetchedResults<SBDirectory>
        @State var selected: SBDirectory?
        
        func updatePredicate(server: SBServer?) {
            // we can only do this when we're in view hierarchy (i.e. not even on init, def not before)
            if let server = server {
                let predicate = NSPredicate.init(format: "(server == %@) && (parentDirectory == nil)", server)
                rootDirectories.nsPredicate = predicate
            }
        }
        
        var body: some View {
            if serverDirectoryController.server != nil {
                // Rely on scrolling to the right whenever we need to scroll;
                // avoid having to fix visual glitch w/ scrollbar
                // (harder to hardcode a size)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 1) {
                        VStack(spacing: 0) {
                            // XXX: unlike the child dirs this will always be directories for now
                            // (we could support top-level items in the future)
                            List(rootDirectories, id: \.self, selection: $selected) { item in
                                MusicItem(item: item)
                                .onTapGesture(count: 2) {
                                    let tracks = DirectoryContextMenu.gather([item])
                                    serverDirectoryController.play(tracks)
                                }
                                .onDrag {
                                    let urls = DirectoryContextMenu.gather([item])
                                        .map { $0.objectID.uriRepresentation() }
                                    let type = NSPasteboard.PasteboardType.libraryItems.rawValue
                                    return NSItemProvider(item: urls as NSArray,
                                                          typeIdentifier: type)
                                } preview: {
                                    DragPreview(items: [item])
                                }
                            }
                            .contextMenu {
                                if let selected = selected {
                                    DirectoryContextMenu(selected: [selected], serverDirectoryController: serverDirectoryController)
                                }
                            }
                            // XXX: We should make this resizable (split view with synchronized sizes?)
                            .frame(width: 250)
                            .onChange(of: serverDirectoryController.server) { newValue in
                                selected = nil
                                updatePredicate(server: newValue)
                            }
                            .onAppear {
                                // the selection views to the right should handle it
                                if selected == nil {
                                    NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: [])
                                }
                                updatePredicate(server: serverDirectoryController.server)
                                
                                serverDirectoryController.server?.getServerDirectories()
                            }
                            .onChange(of: selected) { newValue in
                                // We're not doing anything with this in leftmost
                                self.serverDirectoryController._selectedTracks = []
                                self.serverDirectoryController._selectedDirectories = selected != nil ? [selected!] : []
                                NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: [])
                                if let directory = newValue, let id = directory.itemId {
                                    directory.server?.getServerDirectory(id: id)
                                }
                            }
                            BottomText(count: rootDirectories.count)
                        }
                        if let selected = selected {
                            ChildDirectoriesView(serverDirectoryController: serverDirectoryController,
                                                 directory: selected,
                                                 directories: selected.children)
                        }
                    }
                }
                .modify {
                    if #available(macOS 14, *) {
                        $0.defaultScrollAnchor(.trailing)
                    } else {
                        $0
                    }
                }
            } else {
                SBMessageTextView(message: "There is no server selected.")
            }
        }
    }
}
