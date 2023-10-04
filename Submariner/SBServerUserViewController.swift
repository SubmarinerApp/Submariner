//
//  SBServerUserViewController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-27.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import SwiftUI

extension NSNotification.Name {
    // Actually defined in ParsingOperation for now
    static let SBSubsonicCoversUpdated = NSNotification.Name("SBSubsonicCoversUpdatedNotification")
}

@objc class SBServerUserViewController: SBViewController, ObservableObject {
    @objc var databaseController: SBDatabaseController?
    
    @objc func refreshNowPlaying() {
        let fetchRequest = NSFetchRequest<SBNowPlaying>(entityName: "NowPlaying")
        fetchRequest.includesPropertyValues = false
        
        try? self.managedObjectContext.fetch(fetchRequest).forEach { nowPlaying in
            self.managedObjectContext.delete(nowPlaying)
        }
        self.managedObjectContext.processPendingChanges()
        
        server?.getNowPlaying()
    }
    
    func play(track: SBTrack) {
        SBPlayer.sharedInstance().add(track: track, replace: false)
        SBPlayer.sharedInstance().play(track: track)
    }
    
    func showInLibrary(track: SBTrack) {
        databaseController?.go(to: track)
    }
    
    // #MARK: - View Management
    
    override class func nibName() -> String! {
        nil
    }
    
    override func loadView() {
        title = "Server Users"
        
        // XXX: Can we set the view before loadView?
        let rootView = NowPlayingContentView(serverUsersController: self)
            .environment(\.managedObjectContext, self.managedObjectContext)
        view = NSHostingView(rootView: rootView)
        // don't refresh since we'll do it in didAppear
        
        autoRefreshObserver = UserDefaults.standard.observe(\.autoRefreshNowPlaying) { (defaults, change) in
            self.startTimer()
        }
        // we don't need SBSubsonicNowPlayingUpdatedNotification because SwiftUI pulls from the fetch request
        coverObserver = NotificationCenter.default.addObserver(forName: .SBSubsonicCoversUpdated,
                                               object: nil,
                                               queue: nil) { notification in
            // XXX: don't have a way to forcibly invalidate cover other than the big hammer
            // TODO: Disabled due to propensity for causing infinite loops, figure out a better way for real
            //self.refreshNowPlaying()
        }
        startTimer()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // update it if we become visible
        refreshNowPlaying()
    }
    
    // #MARK: - Server Getter/Setter
    
    @objc @Published var server: SBServer?
    
    // #MARK: - Observers and Timers
    
    var coverObserver: Any?
    var autoRefreshObserver: NSKeyValueObservation?
    var autoRefreshTimer: Timer?
    
    deinit {
        if let coverObserver = coverObserver {
            NotificationCenter.default.removeObserver(coverObserver)
        }
        autoRefreshObserver?.invalidate()
        autoRefreshTimer?.invalidate()
    }
    
    func startTimer() {
        if UserDefaults.standard.autoRefreshNowPlaying {
            let interval = TimeInterval(30)
            autoRefreshTimer?.invalidate()
            autoRefreshTimer = Timer(timeInterval: interval, repeats: true) { timer in
                self.refreshNowPlaying()
            }
        } else {
            autoRefreshTimer?.invalidate()
        }
    }
    
    // #MARK: - SwiftUI Views

    struct NowPlayingItemView: View {
        let item: SBNowPlaying
        
        let serverUsersController: SBServerUserViewController
        
        static let relativeFormatter: RelativeDateTimeFormatter = {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .abbreviated
            return relativeFormatter
        }()
        
        func infoString(_ nowPlaying: SBNowPlaying) -> String {
            var string = nowPlaying.username ?? "Unknown User"
            if let minutesNumber = nowPlaying.minutesAgo {
                let interval = -TimeInterval(minutesNumber.intValue * 60)
                let relativeDate = NowPlayingItemView.relativeFormatter.localizedString(fromTimeInterval: interval)
                string += " "
                string += relativeDate
            }
            return string
        }
        
        var body: some View {
            HStack {
                Image(nsImage: item.track?.coverImage ?? SBAlbum.nullCover!)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(1, contentMode: .fit)
                    // XXX: I don't like hardcoding this
                    .frame(width: 50, height: 50, alignment: .center)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.track?.itemName ?? "Unknown Track")
                    Text(item.track?.artistName ?? "Unknown Artist")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                    Text(infoString(item))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            .onTapGesture(count: 2) { // double-click
                if let track = item.track {
                    serverUsersController.play(track: track)
                }
            }
            .contextMenu {
                Button {
                    if let track = item.track {
                        serverUsersController.play(track: track)
                    }
                } label: {
                    Text("Play")
                }
                Divider()
                Button {
                    if let track = item.track {
                        serverUsersController.showInLibrary(track: track)
                    }
                } label: {
                    Text("Show in Library")
                }
            }
        }
    }

    struct NowPlayingContentView: View {
        @Environment(\.managedObjectContext) var moc
        
        @ObservedObject var serverUsersController: SBServerUserViewController
        
        @FetchRequest(
            // NSSortDescriptor because NSNumber
            sortDescriptors: [NSSortDescriptor.init(key: "minutesAgo", ascending: true)]
            // We build the predicate after when server is set
        ) var items: FetchedResults<SBNowPlaying>
        
        init(serverUsersController: SBServerUserViewController) {
            self.serverUsersController = serverUsersController
        }
        
        func updatePredicate(server: SBServer?) {
            var predicate = NSPredicate.init(format: "(server == nil) && (track != nil)")
            // HACK: Because we can't set this in FetchRequest...
            if let server = server {
                predicate = NSPredicate.init(format: "(server == %@) && (track != nil)", server)
            }
            items.nsPredicate = predicate
        }
        
        var body: some View {
            if let server = serverUsersController.server, server.supportsNowPlaying == true {
                List(items) {
                    NowPlayingItemView(item: $0, serverUsersController: serverUsersController)
                }
                .contextMenu {
                    Button {
                        serverUsersController.refreshNowPlaying()
                    } label: {
                        Text("Refresh")
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .onChange(of: serverUsersController.server) { newValue in
                    updatePredicate(server: newValue)
                    // if the sidebar is open and we switch servers, make sure we have the latest if it makes sense
                    if (self.serverUsersController.databaseController?.isServerUsersShown == true) {
                        // hopefully this doesn't trigger for unsupported servers...
                        serverUsersController.refreshNowPlaying()
                    }
                }
            } else if let server = serverUsersController.server {
                Text("\(server.resourceName ?? "This server") doesn't support now playing.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Text("There is no server selected.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
    }
}
