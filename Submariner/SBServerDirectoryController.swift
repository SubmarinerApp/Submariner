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
    @objc weak var databaseController: SBDatabaseController!
    
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
    
    @objc @Published var server: SBServer?
    
    struct DirectoryItem: View {
        let directory: SBDirectory
        
        var body: some View {
            HStack {
                Image(systemName: "folder")
                Text(directory.itemName ?? "")
            }
        }
    }
    
    struct TrackItem: View {
        let track: SBTrack
        
        var body: some View {
            HStack {
                Image(systemName: "music.note")
                if let path = track.path as? NSString {
                    Text(path.lastPathComponent)
                }
            }
            /*
            .onDrag {
                // FIXME: Set the right Pasteboard type
                let url = track.objectID.uriRepresentation()
                return NSItemProvider(object: url as NSURL)
            }
             */
        }
    }
    
    struct ChildDirectoriesView: View {
        let directories: [SBMusicItem]
        @State var selected: Set<SBMusicItem> = Set()
        
        func updateSelection(newValue: Set<SBMusicItem>) {
            if let directory = newValue.first as? SBDirectory, let id = directory.itemId {
                directory.server?.getServerDirectory(id: id)
            } else if let tracks = newValue as? Set<SBTrack> {
                NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: Array(tracks))
            } else if newValue.isEmpty {
                NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: [])
            }
        }
        
        var body: some View {
            HStack(spacing: 1) {
                VStack(spacing: 0) {
                    List(directories, id: \.self, selection: $selected) {
                        if let directory = $0 as? SBDirectory {
                            DirectoryItem(directory: directory)
                        } else if let track = $0 as? SBTrack {
                            TrackItem(track: track)
                        }
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
                    // XXX: ugly for localization
                    Text("\(directories.count) item\(directories.count == 1 ? "" : "s")")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    // keep same font/baseline as the nibs w/ System 13pt
                        .font(.system(size: 13))
                        .padding(.bottom, 4)
                        .frame(height: 41)
                }
                if selected.count == 1, let directory = selected.first as? SBDirectory {
                    ChildDirectoriesView(directories: directory.children)
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
                ScrollView(.horizontal) {
                    HStack(spacing: 1) {
                        VStack(spacing: 0) {
                            // XXX: unlike the child dirs this will always be directories for now
                            // (we could support top-level items in the future)
                            List(rootDirectories, id: \.self, selection: $selected) {
                                DirectoryItem(directory: $0)
                            }
                            // XXX: We should make this resizable (split view with synchronized sizes?)
                            .frame(width: 250)
                            .onChange(of: serverDirectoryController.server) { newValue in
                                selected = nil
                                updatePredicate(server: newValue)
                                // FIXME: Check if we're visible and reload directories if so
                            }
                            .onAppear {
                                // the selection views to the right should handle it
                                if selected == nil {
                                    NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: [])
                                }
                                updatePredicate(server: serverDirectoryController.server)
                            }
                            .onChange(of: selected) { newValue in
                                // We're not doing anything with this in leftmost
                                NotificationCenter.default.post(name: .SBTrackSelectionChanged, object: [])
                                if let directory = newValue, let id = directory.itemId {
                                    directory.server?.getServerDirectory(id: id)
                                }
                            }
                            // XXX: ugly for localization
                            Text("\(rootDirectories.count) item\(rootDirectories.count == 1 ? "" : "s")")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            // keep same font/baseline as the nibs w/ System 13pt
                                .font(.system(size: 13))
                                .padding(.bottom, 4)
                                .frame(height: 41)
                        }
                        if let selected = selected {
                            ChildDirectoriesView(directories: selected.children)
                        }
                    }
                }
            } else {
                Text("There is no server selected.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
    }
}
