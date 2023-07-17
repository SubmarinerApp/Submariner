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

@objc class SBServerUserViewController: SBViewController {
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
    
    private var _viewShown = false
    func recreateView() {
        let rootView = NowPlayingContentView(serverUsersController: self, server: server)
            .environment(\.managedObjectContext, self.managedObjectContext)
        view = NSHostingView(rootView: rootView)
    }
    
    override class func nibName() -> String! {
        nil
    }
    
    override func loadView() {
        title = "Server Users"
        
        // XXX: Can we set the view before loadView?
        _viewShown = true
        recreateView()
        refreshNowPlaying()
        
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
    
    // #MARK: - Server Getter/Setter
    
    // HACK: Because Big Sur doesn't support changing FetchRequest's NSPredicate at runtime,
    // we'll just recreate the entire hosting view instead. If we drop Big Sur support, it's
    // just a matter of making this Observable, server Published, make the this controller
    // in the SwiftUI view Observed, and onReceive $server, setting request's nsPredicate.
    private var _server: SBServer?
    @objc var server: SBServer? {
        get {
            return _server
        }
        set {
            _server = newValue
            
            if _viewShown {
                recreateView()
                refreshNowPlaying()
            }
        }
    }
    
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
        
        let serverUsersController: SBServerUserViewController
        
        @FetchRequest var items: FetchedResults<SBNowPlaying>
        
        init(serverUsersController: SBServerUserViewController, server: SBServer?) {
            self.serverUsersController = serverUsersController
            var predicate = NSPredicate.init(format: "(server == nil) && (track != nil)")
            // HACK: Because we can't set this in FetchRequest...
            if let server = server {
                predicate = NSPredicate.init(format: "(server == %@) && (track != nil)", server)
            }
            // NSSortDescriptor because NSNumber
            let minutesAgoSD = NSSortDescriptor.init(key: "minutesAgo", ascending: true)
            _items = FetchRequest<SBNowPlaying>(sortDescriptors: [minutesAgoSD],
                                                predicate: predicate)
        }
        
        var body: some View {
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
            .modify {
                if #available(macOS 12, *) {
                    $0.listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
        }
    }
}
