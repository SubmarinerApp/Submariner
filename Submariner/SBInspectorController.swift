//
//  SBInspectorController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-10-04.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import SwiftUI

@objc class SBInspectorController: SBViewController {
    @objc var databaseController: SBDatabaseController?
    var rootView: InspectorView?
    
    override func loadView() {
        title = "Downloads"
        rootView = InspectorView()
        view = NSHostingView(rootView: rootView)
    }
    
    @objc dynamic var selectedTracks: [SBTrack] {
        get {
            return rootView?.selectedTracks ?? []
        } set {
            rootView?.selectedTracks = newValue
        }
    }
    
    struct TrackInfoView: View {
        static let multipleDiffer = "..."
        static var byteFormatter = ByteCountFormatter()
        
        let tracks: [SBTrack]

        func valueIfSame<T: Hashable>(property: KeyPath<SBTrack, T>) -> T? {
            // one or none
            if tracks.count == 1 {
                return tracks[0][keyPath: property]
            } else if tracks.count == 0 {
                return nil
            }
            // if multiple
            let values = Set(tracks.map { $0[keyPath: property] })
            if values.count > 1 {
                return nil // too many
            } else {
                return tracks[0][keyPath: property]
            }
        }
        
        @ViewBuilder func stringField(label: String, for property: KeyPath<SBTrack, String?>) -> some View {
            if let stringMaybeSingular = valueIfSame(property: property) {
                if let string = stringMaybeSingular {
                    TextField(label, text: .constant(string))
                }
                // no thing -> nothing
            } else {
                TextField(label, text: .constant(TrackInfoView.multipleDiffer))
            }
        }
        
        @ViewBuilder func numberField(label: String, for property: KeyPath<SBTrack, NSNumber?>, formatter: Formatter? = nil) -> some View {
            if let numberMaybeSingular = valueIfSame(property: property) {
                if let number = numberMaybeSingular, number != 0 {
                    if let formatter = formatter, let string = formatter.string(for: number) {
                        TextField(label, text: .constant(string))
                    } else {
                        TextField(label, text: .constant(number.stringValue))
                    }
                }
                // no thing -> nothing
            } else {
                TextField(label, text: .constant(TrackInfoView.multipleDiffer))
            }
        }
        
        var body: some View {
            // We should move the album art out of the nib with the sidebar, and get rid of a lot of constraints.
            /*
            if let albumMaybeSingular = valueIfSame(property: \.album),
               let album = albumMaybeSingular, let cover = album.cover,
               let path = cover.imagePath, let image = NSImage(contentsOfFile: path as String) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    
            }
             */
            Form {
                // Try to generalize, if multiple are selected then show something that indicates they differ
                Section {
                    stringField(label: "Title", for: \.itemName)
                    stringField(label: "Album", for: \.albumString)
                    stringField(label: "Artist", for: \.artistString)
                    stringField(label: "Genre", for: \.genre)
                    numberField(label: "Year", for: \.year)
                }
                Section {
                    // TODO: Make this an interactive control. NSTableView has something like it
                    numberField(label: "Rating", for: \.rating)
                }
                Section {
                    numberField(label: "Track #", for: \.trackNumber)
                    numberField(label: "Disc #", for: \.discNumber)
                }
                Section {
                    stringField(label: "Duration", for: \.durationString)
                    stringField(label: "Type", for: \.contentType)
                    stringField(label: "Transcoded As", for: \.transcodedType)
                    numberField(label: "Size", for: \.size, formatter: TrackInfoView.byteFormatter)
                    numberField(label: "Bitrate (KB/s)", for: \.bitRate)
                }
                // Maybe some buttons here?
            }
            .modify {
                if #available(macOS 13, *) {
                    $0.formStyle(.grouped)
                } else {
                    $0
                }
            }
        }
    }
    
    struct InspectorView: View {
        @State var selectedTracks: [SBTrack] = []
        
        @ObservedObject var player = SBPlayer.sharedInstance()
        
        var body: some View {
            if selectedTracks.count > 0 {
                TrackInfoView(tracks: selectedTracks)
            } else if let currentIndex = player.currentIndex, let currentTrack = player.currentTrack {
                TrackInfoView(tracks: [currentTrack])
            } else {
                Text("There are no tracks playing or selected.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
    }
}
