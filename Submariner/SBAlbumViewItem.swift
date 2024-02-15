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
            return
        }
        
        // use a padding of 4 on the root view as a margin, instead of inserts in collection view flow
        let newView = AlbumItem(host: self, album: album)
            .padding(4)
        if let view = view as? NSHostingView<AlbumItem> {
            view.rootView = newView as! AlbumItem
        } else {
            view = NSHostingView(rootView: newView)
        }
        
        // I'd prefer to do .onTapGesture(2), but that makes SwiftUI eat the normal click events
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(SBAlbumViewItem.doubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        // Delays normal clicks otherwise
        doubleClickGesture.delaysPrimaryMouseButtonEvents = false
        view.addGestureRecognizer(doubleClickGesture)
        
        if let collectionView = unowningCollectionView ?? collectionView {
            firstResponderObserver = collectionView.observe(\.isFirstResponder, options: [.initial, .new]) { collectionView, change in
                self.isHostingViewFirstResponder = change.newValue ?? false
            }
        }
    }
    
    override func loadView() {
        super.loadView()
        
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
    
    // HACK: We can't use collectionView, because it requires you to use makeItemWithIdentifier:forIndexPath:,
    // which doesn't work for some reason (mangled frame/size for the view, or bizarre exceptions),
    // forcing us to make an unowned view item (This also presumably affects caching too.).
    // However, we want to know if the parent view is first responder for drawing reasons,
    // so we make this variable that has to be manually assigned instead.
    // If this can be fixed, get rid of this and just observe collectionView.
    @objc weak var unowningCollectionView: NSCollectionView?
    
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
            .background(backgroundColour)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
