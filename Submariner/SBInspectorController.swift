//
//  SBInspectorController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-10-04.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import SwiftUI
import QuickLook

extension NSNotification.Name {
    // Actually defined in ParsingOperation for now
    static let SBTrackSelectionChanged = NSNotification.Name("SBTrackSelectionChanged")
}

@objc class SBInspectorController: SBViewController, ObservableObject {
    @objc var databaseController: SBDatabaseController?
    var rootView: InspectorView?
    
    override func loadView() {
        title = "Inspector"
        rootView = InspectorView(inspectorController: self)
        view = NSHostingView(rootView: rootView)
        
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(SBInspectorController.trackSelectionChange(notification:)),
                                               name: .SBTrackSelectionChanged,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .SBTrackSelectionChanged, object: nil)
    }
    
    @objc private func trackSelectionChange(notification: Notification) {
        if let selectedTracks = notification.object as? [SBTrack] {
            self.selectedTracks = selectedTracks
        }
    }
    
    @Published var selectedTracks: [SBTrack] = []
    
    struct AlbumArtView: View {
        // used for quick look preview
        @State var coverUrl: URL?
        
        let album: SBAlbum?
        
        var body: some View {
            if let path = album?.cover?.imagePath, let image = NSImage(contentsOfFile: path as String) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        coverUrl = URL(fileURLWithPath: path as String)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: 6)
                    )
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .quickLookPreview($coverUrl)
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                    .foregroundColor(.secondary)
            }
        }
    }
    
    struct TrackInfoView: SBMusicItemInfoView {
        static var byteFormatter = ByteCountFormatter()
        
        typealias MI = SBTrack
        var items: [SBTrack] {
            return tracks
        }
        
        let tracks: [SBTrack]
        let isFromSelection: Bool
        
        var body: some View {
            VStack(spacing: 0) {
                AlbumArtView(album: valueIfSame(property: \.album)!)
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
                        // Special behaviour to sum up duration and file size,
                        // size differences are expected, but totals are useful
                        if tracks.count > 1 {
                            let length = TimeInterval(tracks.map({ track in track.duration?.doubleValue ?? 0 }).reduce(0, +))
                            field(label: "Duration", string: String(timeInterval: length))
                        } else {
                            stringField(label: "Duration", for: \.durationString)
                        }
                        stringField(label: "Type", for: \.contentType)
                        stringField(label: "Transcoded As", for: \.transcodedType)
                        if tracks.count > 1 {
                            let total = tracks.map({ track in track.size?.int64Value ?? 0 }).reduce(0, +)
                            field(label: "Size", string: TrackInfoView.byteFormatter.string(fromByteCount: total))
                        } else {
                            numberField(label: "Size", for: \.size, formatter: TrackInfoView.byteFormatter)
                        }
                        numberField(label: "Bitrate (KB/s)", for: \.bitRate)
                    }
                    // Maybe some buttons here?
                }
                .modify {
                    if #available(macOS 13, *) {
                        $0.formStyle(.grouped)
                    } else {
                        $0.frame(maxHeight: .infinity)
                    }
                }
            }
        }
    }
    
    struct EmptyCollectionText: View {
        let message: String
        
        var body: some View {
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxHeight: .infinity)
        }
    }
    
    struct InspectorView: View {
        @ObservedObject var inspectorController: SBInspectorController
        @ObservedObject var player = SBPlayer.sharedInstance()
        
        @State var selectedType: InspectorTab = .trackNowPlaying
        
        enum InspectorTab {
            // TODO: selected artist or artist if those ever has interesting properties in the future
            // TODO: selected playlist is also important and has values not currently exposed in UI
            case selectedTracks
            case trackNowPlaying
        }
        
        func updateSelection() {
            if selectedType == .selectedTracks,
               inspectorController.selectedTracks.count == 0,
               player.isPlaying {
                selectedType = .trackNowPlaying
            } else if selectedType == .trackNowPlaying,
                inspectorController.selectedTracks.count > 0 {
                 selectedType = .selectedTracks
            }
        }
        
        var body: some View {
            VStack(spacing: 0) {
                if (selectedType == .trackNowPlaying) {
                    if let currentTrack = player.currentTrack {
                        TrackInfoView(tracks: [currentTrack], isFromSelection: false)
                    } else {
                        EmptyCollectionText(message: "There is no playing track.")
                    }
                } else if selectedType == .selectedTracks {
                    if inspectorController.selectedTracks.count > 0 {
                        TrackInfoView(tracks: inspectorController.selectedTracks, isFromSelection: true)
                    } else {
                        EmptyCollectionText(message: "There are no selected tracks.")
                    }
                }
                HStack {
                    Picker("Selected Item Type", selection: $selectedType) {
                        if inspectorController.selectedTracks.count > 0 {
                            // We're using text here for now since we can't combine it with the selection count very well.
                            Text("\(inspectorController.selectedTracks.count) Selected")
                                .tag(InspectorTab.selectedTracks)
                        }
                        if player.isPlaying {
                            Text("Now Playing")
                                .tag(InspectorTab.trackNowPlaying)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                .frame(height: 41)
                .padding([.leading, .trailing], 8)
            }
            .onChange(of: inspectorController.selectedTracks) { _ in
                updateSelection()
            }
            .onChange(of: player.isPlaying) { _ in
                updateSelection()
            }
            .onAppear {
                updateSelection()
            }
        }
    }
}

// This must be top-level
protocol SBMusicItemInfoView: View {
    associatedtype MI: SBMusicItem
    
    var items: [MI] { get }
}

extension SBMusicItemInfoView {
    func valueIfSame<T: Hashable>(property: KeyPath<MI, T>) -> T? {
        // one or none
        if items.count == 1 {
            return items[0][keyPath: property]
        } else if items.count == 0 {
            return nil
        }
        // if multiple
        let values = Set(items.map { $0[keyPath: property] })
        if values.count > 1 {
            return nil // too many
        } else {
            return items[0][keyPath: property]
        }
    }
    
    @ViewBuilder func field(label: String, string: String) -> some View {
        if #available(macOS 13, *) {
            LabeledContent {
                Text(string)
                    .textSelection(.enabled)
            } label: {
                Text(label)
            }
        } else {
            TextField(label, text: .constant(string))
        }
    }
    
    @ViewBuilder func stringField(label: String, for property: KeyPath<MI, String?>) -> some View {
        if let stringMaybeSingular = valueIfSame(property: property) {
            if let string = stringMaybeSingular {
                field(label: label, string: string)
            }
            // no thing -> nothing
        } else {
            field(label: label, string: "...")
        }
    }
    
    @ViewBuilder func numberField(label: String, for property: KeyPath<MI, NSNumber?>, formatter: Formatter? = nil) -> some View {
        if let numberMaybeSingular = valueIfSame(property: property) {
            if let number = numberMaybeSingular, number != 0 {
                if let formatter = formatter, let string = formatter.string(for: number) {
                    field(label: label, string: string)
                } else {
                    field(label: label, string: number.stringValue)
                }
            }
            // no thing -> nothing
        } else {
            field(label: label, string: "...")
        }
    }
}
