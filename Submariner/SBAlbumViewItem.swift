//
//  SBAlbumViewItem2.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-12.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa
import SwiftUI
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBAlbumViewItem")

@objc(SBAlbumViewItem) class SBAlbumViewItem: NSCollectionViewItem, ObservableObject {
    private func regenerateView() {
        guard let album = self.album else {
            // item being reused, remove existing view
            view.subviews.removeAll()
            return
        }
        
        // use a padding of 4 on the root view as a margin, instead of inserts in collection view flow
        let newView = AlbumItem(host: self, album: album)
            .accessibilityLabel(album.itemName ?? "Untitled Album")
            .padding(4)
        if let view = view.subviews.first as? NSHostingView<AlbumItem> {
            view.rootView = newView as! AlbumItem
        } else {
            // We can't have the hosting view directly be the NSCollectionViewItem's view.
            // Instead, we have to have it as a subview and add constraints,
            // so that it has the correct frame with proper item reuse.
            let hostingView = NSHostingView(rootView: newView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            hostingView.layer?.masksToBounds = true
            self.view.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: self.view.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            ])
        }
        
        // I'd prefer to do .onTapGesture(2), but that makes SwiftUI eat the normal click events
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(SBAlbumViewItem.doubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        // Delays normal clicks otherwise
        doubleClickGesture.delaysPrimaryMouseButtonEvents = false
        view.addGestureRecognizer(doubleClickGesture)
        
        if let collectionView = self.collectionView {
            firstResponderObserver = collectionView.observe(\.isFirstResponder, options: [.initial, .new]) { collectionView, change in
                self.isHostingViewFirstResponder = change.newValue ?? false
            }
        }
    }
    
    override func loadView() {
        // don't call super.loadView(), it's for nib based
        // but do set an empty view here; if not, then calling the view getter in regenerateView will infinite loop
        view = NSView()
        
        regenerateView()
    }
    
    override var representedObject: Any? {
        didSet {
            regenerateView()
        }
    }
    
    var album: SBAlbum? {
        return representedObject as? SBAlbum
    }
    
    // #MARK: - Double-Click
    
    private static let descriptors: [NSSortDescriptor] = [
        NSSortDescriptor(key: "discNumber", ascending: true),
        NSSortDescriptor(key: "trackNumber", ascending: true),
    ]
    
    @IBAction func doubleClick(_ sender: Any) {
        if let album = self.album, let tracks = album.tracks,
           let sorted = tracks.sortedArray(using: SBAlbumViewItem.descriptors) as? [SBTrack] {
            SBPlayer.sharedInstance().play(tracks: sorted, startingAt: 0)
        }
    }
    
    // #MARK: - First Responder wrapper
    // This exists so that the SwiftUI view inside can change the background colour for selections as the hosting collection view's responderiness changes.
    
    private var firstResponderObserver: NSKeyValueObservation?
    
    @Published private var isHostingViewFirstResponder = false
    
    // #MARK: - SwiftUI selection wrapper
    
    /// Wrapper for isSelected that can be published for SwiftUI.
    @Published private var drawSelection: Bool = false
    
    override var isSelected: Bool {
        didSet {
            drawSelection = isSelected
        }
    }
    
    // #MARK: - SwiftUI View
    
    struct AlbumItem: View {
        // used to detect if we're the key window
        @Environment(\.controlActiveState) var controlActiveState: ControlActiveState
        
        @ObservedObject var host: SBAlbumViewItem
        let album: SBAlbum
        
        @State var hovering = false
        
        var body: some View {
            // Convert to if-expr once CI is newer
            let backgroundColour = host.drawSelection ? (host.isHostingViewFirstResponder && controlActiveState == .key ? Color(nsColor: .selectedContentBackgroundColor) : Color(nsColor: .unemphasizedSelectedContentBackgroundColor)) : .clear
            VStack {
                Image(nsImage: album.imageRepresentation() as! NSImage)
                    .interpolation(.medium)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black, radius: 1, y: 1)
                    .padding(6)
                    .modify {
                        // This could perhaps use some polish in how it works
                        let helpText = album.starred != nil ? "Favourited" : "Not Favourited"
                        if hovering {
                            $0.overlay(alignment: .bottomTrailing) {
                                Image(systemName: "heart")
                                    .foregroundStyle(.pink)
                                    .shadow(color: .black, radius: 1)
                                    .onTapGesture {
                                        // hover could be for either state
                                        album.starredBool = !album.starredBool
                                    }
                                    .accessibilityAction {
                                        album.starredBool = !album.starredBool
                                    }
                                    .accessibilityLabel("Not Favourited")
                                    .accessibilityHint("Favourite Album")
                                    .help(helpText)
                            }
                        } else if album.starred != nil {
                            $0.overlay(alignment: .bottomTrailing) {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.pink)
                                    .shadow(color: .black, radius: 1)
                                    .onTapGesture {
                                        album.starredBool = false
                                    }
                                    .accessibilityAction {
                                        album.starredBool = !album.starredBool
                                    }
                                    .accessibilityLabel("Favourited")
                                    .accessibilityHint("Unfavourite Album")
                                    .help(helpText)
                            }
                        } else {
                            $0
                        }
                    }
                    // XXX: This might not be right, because we might want the overlay to be accessible.
                    .accessibilityHidden(true)
                Text(album.itemName ?? "")
                    .controlSize(.small)
                    // lineLimit 2 w/ space reservation is interesting, but requires newer target
                    .lineLimit(1)
                    .modify {
                        // match the background; there is no selected content text colour annoyingly
                        if host.drawSelection && host.isHostingViewFirstResponder && controlActiveState == .key {
                            // we have the selected content colour; menu item matches because those use the same colour
                            $0.foregroundStyle(Color(nsColor: .selectedMenuItemTextColor))
                        } else if host.drawSelection {
                            // match the unemphasized selected text colour; this should be same as text really
                            $0.foregroundStyle(Color(nsColor: .unemphasizedSelectedTextColor))
                        } else {
                            $0
                        }
                    }
                    .padding([.leading, .bottom, .trailing], 6)
            }
            .onHover { _ in
                // It's a little weird that the hover can appear when you're anywhere over the item,
                // but it's unusually CPU intensive if we i.e. only do it on the Image.
                self.hovering.toggle()
            }
            .background(backgroundColour)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
