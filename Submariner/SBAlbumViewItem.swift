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

@objc(SBAlbumViewItem) class SBAlbumViewItem: NSCollectionViewItem, ObservableObject {
    private func regenerateView() {
        guard let album = self.album else {
            return
        }
        
        // use a padding of 4 on the root view as a margin, instead of inserts in collection view flow
        view = NSHostingView(rootView: AlbumItem(host: self, album: album)
            .padding(4))
        
        // I'd prefer to do .onTapGesture(2), but that makes SwiftUI eat the normal click events
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(SBAlbumViewItem.doubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        // Delays normal clicks otherwise
        doubleClickGesture.delaysPrimaryMouseButtonEvents = false
        view.addGestureRecognizer(doubleClickGesture)
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
    
    // #MARK: - SwiftUI property wrapper
    
    /// Wrapper for isSelected that can be published for SwiftUI.
    @Published private var drawSelection: Bool = false
    
    override var isSelected: Bool {
        didSet {
            drawSelection = isSelected
        }
    }
    
    // #MARK: - SwiftUI View
    
    struct AlbumItem: View {
        @ObservedObject var host: SBAlbumViewItem
        let album: SBAlbum
        
        var body: some View {
            VStack {
                Image(nsImage: album.imageRepresentation() as! NSImage)
                    .interpolation(.medium)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(1, contentMode: .fit)
                    .padding(6)
                Text(album.itemName ?? "")
                    .controlSize(.small)
                    // lineLimit 2 w/ space reservation is interesting, but requires newer target
                    .lineLimit(1)
                    .modify {
                        if false && host.drawSelection {
                            $0.foregroundStyle(Color(nsColor: .selectedTextColor))
                        } else {
                            $0
                        }
                    }
                    .padding([.leading, .bottom, .trailing], 6)
            }
            // control accent colour might have been more appropriate, but we have text too
            .background(host.drawSelection ? Color(nsColor: .selectedTextBackgroundColor) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
