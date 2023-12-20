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
    
    struct TrackInfoView: View {
        static let multipleDiffer = "..."
        static var byteFormatter = ByteCountFormatter()
        
        let tracks: [SBTrack]
        let isFromSelection: Bool
        // used for quick look preview
        @State var coverUrl: URL?

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
        
        @ViewBuilder func stringField(label: String, for property: KeyPath<SBTrack, String?>) -> some View {
            if let stringMaybeSingular = valueIfSame(property: property) {
                if let string = stringMaybeSingular {
                    field(label: label, string: string)
                }
                // no thing -> nothing
            } else {
                field(label: label, string: TrackInfoView.multipleDiffer)
            }
        }
        
        @ViewBuilder func numberField(label: String, for property: KeyPath<SBTrack, NSNumber?>, formatter: Formatter? = nil) -> some View {
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
                field(label: label, string: TrackInfoView.multipleDiffer)
            }
        }
        
        var body: some View {
            VStack(spacing: 0) {
                if let albumMaybeSingular = valueIfSame(property: \.album),
                   let album = albumMaybeSingular, let cover = album.cover,
                   let path = cover.imagePath, let image = NSImage(contentsOfFile: path as String) {
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
                        $0
                    }
                }
                HStack {
                    if isFromSelection {
                        // XXX: ugly for localization
                        Text("\(tracks.count) selected track\(tracks.count == 1 ? "" : "s")")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            // keep same font/baseline as the nibs w/ System 13pt
                            .font(.system(size: 13))
                            .padding(.bottom, 4)
                    }
                }
                .frame(height: 41)
            }
        }
    }
    
    struct InspectorView: View {
        @ObservedObject var inspectorController: SBInspectorController
        @ObservedObject var player = SBPlayer.sharedInstance()
        
        var body: some View {
            if inspectorController.selectedTracks.count > 0 {
                TrackInfoView(tracks: inspectorController.selectedTracks, isFromSelection: true)
            } else if let currentTrack = player.currentTrack {
                TrackInfoView(tracks: [currentTrack], isFromSelection: false)
            } else {
                Text("There are no tracks playing or selected.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
    }
}
