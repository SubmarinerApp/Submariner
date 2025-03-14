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
    static let SBPlaylistSelectionChanged = NSNotification.Name("SBPlaylistSelectionChanged")
}

// does not inherit from SBViewController
@objc class SBInspectorController: NSViewController, ObservableObject {
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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(SBInspectorController.playlistSelectionChange(notification:)),
                                               name: .SBPlaylistSelectionChanged,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .SBTrackSelectionChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .SBPlaylistSelectionChanged, object: nil)
    }
    
    @objc private func trackSelectionChange(notification: Notification) {
        if let selectedTracks = notification.object as? [SBTrack] {
            self.selectedTracks = selectedTracks
        }
    }
    
    @objc private func playlistSelectionChange(notification: Notification) {
        self.selectedPlaylist = notification.object as? SBPlaylist
    }
    
    @Published var selectedTracks: [SBTrack] = []
    @Published var selectedPlaylist: SBPlaylist?
    
    struct AlbumArtView: View {
        // used for quick look preview
        @State var coverUrl: URL?
        
        // horrific, but basically SBAlbum?? == nil -> difference in album between selection (i.e. in a playlist)
        // SBAlbum? == nil -> nil album in tracks
        let album: SBAlbum??
        
        var body: some View {
            if let singularAlbum = self.album,
               let path = singularAlbum?.cover?.imagePath, let image = NSImage(contentsOfFile: path as String) {
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
    
    struct TrackInfoView: SBPropertyFieldView {
        static var byteFormatter = ByteCountFormatter()
        static var relativeDateFormatter = RelativeDateTimeFormatter()
        
        typealias MI = SBTrack
        var items: [SBTrack] {
            return tracks
        }
        
        let tracks: [SBTrack]
        let isFromSelection: Bool
        
        private func setRating(track: SBTrack, rating: Int) {
            track.rating = NSNumber(value: rating)
            if let server = track.server, let itemId = track.itemId {
                server.setRating(rating, id: itemId)
            }
        }
        
        var body: some View {
            VStack(spacing: 0) {
                AlbumArtView(album: valueIfSame(property: \.album))
                Form {
                    // Try to generalize, if multiple are selected then show something that indicates they differ
                    Section {
                        stringField(label: "Title", for: \.itemName)
                        stringField(label: "Album", for: \.albumString)
                        stringField(label: "Artist", for: \.artistString)
                        stringField(label: "Genre", for: \.genre)
                        numberField(label: "Year", for: \.year)
                        stringField(label: "Comment", for: \.comment)
                        stringField(label: "Explicit", for: \.explicit)
                    }
                    Section {
                        numberField(label: "Track #", for: \.trackNumber)
                        numberField(label: "Disc #", for: \.discNumber)
                    }
                    Section {
                        // TODO: Make this an interactive control. NSTableView has something like it
                        ratingField(label: "Rating", for: \.rating) { rating in
                            for track in tracks {
                                setRating(track: track, rating: rating)
                            }
                        }
                        numberField(label: "Play Count", for: \.playCount)
                        dateField(label: "Played", for: \.played, formatter: TrackInfoView.relativeDateFormatter)
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
                    }
                    Section {
                        numberField(label: "Bitrate (KB/s)", for: \.bitRate)
                        numberField(label: "Channels", for: \.channelCount)
                        numberField(label: "Sample Rate", for: \.samplingRate)
                        numberField(label: "Bit Depth", for: \.bitDepth)
                        numberField(label: "Beats Per Minute", for: \.bpm)
                    }
                    if let musicBrainzId = valueIfSame(property: \.musicBrainzId),
                       let musicBrainzId = musicBrainzId, !musicBrainzId.isEmpty,
                       let url = URL(string: "http://musicbrainz.org/track/\(musicBrainzId)") {
                        Link(destination: url) {
                            Text("View in MusicBrainz")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
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
    
    struct PlaylistInspectorView: View, SBPropertyFieldView {
        @ObservedObject var playlist: SBPlaylist
        
        // We don't yet use the protocol methods for the read-only stuff,
        // but likely will with i.e. author field
        typealias MI = SBPlaylist
        var items: [SBPlaylist] {
            return [playlist]
        }
        
        var body: some View {
            VStack(spacing: 0) {
                Form {
                    Section {
                        TextField("Name", text: Binding($playlist.resourceName, replacingNilWith: ""))
                            .onSubmit {
                                if let server = playlist.server, let id = playlist.itemId {
                                    server.updatePlaylist(ID: id, name: playlist.resourceName)
                                }
                            }
                        if playlist.server != nil {
                            Toggle(isOn: $playlist.isPublic) {
                                Text("Public?")
                            }
                            .onSubmit {
                                if let server = playlist.server, let id = playlist.itemId {
                                    server.updatePlaylist(ID: id, isPublic: playlist.isPublic)
                                }
                            }
                        }
                        TextField("Comment", text: Binding($playlist.comment, replacingNilWith: ""))
                            .onSubmit {
                                if let server = playlist.server, let id = playlist.itemId {
                                    server.updatePlaylist(ID: id, comment: playlist.comment)
                                }
                            }
                    }
                    // count and duration are already displayed in status bar
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
    
    struct InspectorView: View {
        @ObservedObject var inspectorController: SBInspectorController
        @ObservedObject var player = SBPlayer.sharedInstance()
        
        @State var selectedType: InspectorTab = .trackNowPlaying
        
        enum InspectorTab {
            // TODO: selected artist or artist if those ever has interesting properties in the future
            case selectedPlaylist
            case selectedTracks
            case trackNowPlaying
        }
        
        func updateSelection() {
            if selectedType == .selectedTracks,
               inspectorController.selectedTracks.count == 0,
               player.isPlaying {
                selectedType = .trackNowPlaying
            } else if (selectedType == .trackNowPlaying || selectedType == .selectedPlaylist),
                inspectorController.selectedTracks.count > 0 {
                selectedType = .selectedTracks
            } else if inspectorController.selectedPlaylist != nil,
                      inspectorController.selectedTracks.count == 0 {
                selectedType = .selectedPlaylist
            }
        }
        
        var body: some View {
            VStack(spacing: 0) {
                switch selectedType {
                case .selectedPlaylist:
                    if let currentPlaylist = inspectorController.selectedPlaylist {
                        PlaylistInspectorView(playlist: currentPlaylist)
                    } else {
                        SBMessageTextView(message: "There is no selected playlist.")
                    }
                case .trackNowPlaying:
                    if let currentTrack = player.currentTrack {
                        TrackInfoView(tracks: [currentTrack], isFromSelection: false)
                    } else {
                        SBMessageTextView(message: "There is no playing track.")
                    }
                case .selectedTracks:
                    if inspectorController.selectedTracks.count > 0 {
                        TrackInfoView(tracks: inspectorController.selectedTracks, isFromSelection: true)
                    } else {
                        SBMessageTextView(message: "There are no selected tracks.")
                    }
                }
                HStack {
                    Picker("Selected Item Type", selection: $selectedType) {
                        // We can't disable picker items, so hide what we can't use.
                        if inspectorController.selectedPlaylist != nil {
                            Text("Playlist")
                                .tag(InspectorTab.selectedPlaylist)
                        }
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
