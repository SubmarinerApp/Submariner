//
//  SBPlayer.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-06-04.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Foundation
import AVFoundation
import UserNotifications
import MediaPlayer
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBPlayer")

@objc class SBPlayer: NSObject, UNUserNotificationCenterDelegate {
    @objc(SBPlayerRepeatMode) enum RepeatMode: Int {
        @objc(SBPlayerRepeatNo) case no = 0
        @objc(SBPlayerRepeatOne) case one = 1
        @objc(SBPlayerRepeatAll) case all = 2
    }
    
    // #MARK: - Notification Names
    
    static let playlistUpdatedNotification = NSNotification.Name("SBPlayerPlaylistUpdatedNotification")
    static let playStateNotification = NSNotification.Name("SBPlayerPlayStateNotification")
    
    // #MARK: - Initialization
    
    // This is only public for AVRoutePickerViews.
    @objc let remotePlayer = AVPlayer()
    
    var playerStatusObserver: NSKeyValueObservation?
    var playerItemObserver: NSKeyValueObservation?
    
    private override init() {
        super.init()
        
        initializeMediaControls()
        
        // This is counter-intuitive, but this has to be *off* for AirPlay from the app to work
        // per https://stackoverflow.com/a/29324777 - seems to cause problem for video, but
        // we don't care about video
        remotePlayer.allowsExternalPlayback = false;
        
        // observers
        playerStatusObserver = remotePlayer.observe(\.status) { player, change in
            switch (change.newValue) {
            case .readyToPlay:
                player.play()
            case .unknown:
                self.stop()
            case .failed:
                // XXX: Surface?
                logger.error("AVPlayer status is failed, error \(player.error, privacy: .public)")
                self.stop()
            default:
                return
            }
        }
        playerItemObserver = remotePlayer.observe(\.currentItem) { player, change in
            if UserDefaults.standard.enableCacheStreaming {
                if let currentTrack = self.currentTrack {
                    // Check if we've already downloaded this track.
                    if currentTrack.isLocal == true || currentTrack.localTrack != nil {
                        return
                    }
                    
                    if let op = SBSubsonicDownloadOperation(managedObjectContext: currentTrack.managedObjectContext, trackID: currentTrack.objectID) {
                        OperationQueue.sharedDownloadQueue.addOperation(op)
                    }
                }
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(SBPlayer.itemDidFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    // #MARK: - Singleton
    
    private static var _sharedInstance = SBPlayer()
    
    // FIXME: Make var
    @objc static func sharedInstance() -> SBPlayer {
        return _sharedInstance
    }
    
    // #MARK: - Media Controls
    
    private func initializeMediaControls() {
        let remoteCommandCenter = MPRemoteCommandCenter.shared()
        
        let interval = NSNumber(value: UserDefaults.standard.skipIncrement)
        
        remoteCommandCenter.playCommand.isEnabled = true
        remoteCommandCenter.playCommand.addTarget { event in
            // This is a toggle because the system media key always sends play.
            self.playPause()
            return .success
        }
        
        remoteCommandCenter.pauseCommand.isEnabled = true
        remoteCommandCenter.pauseCommand.addTarget { event in
            self.pause()
            return .success
        }
        
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
        remoteCommandCenter.togglePlayPauseCommand.addTarget { event in
            self.playPause()
            return .success
        }
        
        remoteCommandCenter.stopCommand.isEnabled = true
        remoteCommandCenter.stopCommand.addTarget { event in
            self.stop()
            return .success
        }
        
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
        remoteCommandCenter.changePlaybackPositionCommand.addTarget { event in
            let seekEvent = event as! MPChangePlaybackPositionCommandEvent
            if self.isPlaying {
                self.seek(to: seekEvent.positionTime)
                return .success
            }
            return .noActionableNowPlayingItem
        }
        
        remoteCommandCenter.nextTrackCommand.isEnabled = true
        remoteCommandCenter.nextTrackCommand.addTarget { event in
            self.next()
            return .success
        }
        
        remoteCommandCenter.previousTrackCommand.isEnabled = true
        remoteCommandCenter.previousTrackCommand.addTarget { event in
            self.previous()
            return .success
        }
        
        // Disable these because they get used instead of prev/next track on macOS, at least in 12.
        // XXX: Does it make more sense to bind seekForward/Backward? For podcasts?
        remoteCommandCenter.skipForwardCommand.isEnabled = false
        remoteCommandCenter.skipForwardCommand.addTarget { event in
            self.fastForward()
            return .success
        }
        remoteCommandCenter.skipBackwardCommand.isEnabled = false
        remoteCommandCenter.skipBackwardCommand.addTarget { event in
            self.rewind()
            return .success
        }
        remoteCommandCenter.skipForwardCommand.preferredIntervals = [interval]
        remoteCommandCenter.skipBackwardCommand.preferredIntervals = [interval]
        
        remoteCommandCenter.ratingCommand.isEnabled = true
        remoteCommandCenter.ratingCommand.minimumRating = 0.0
        remoteCommandCenter.ratingCommand.maximumRating = 5.0
        remoteCommandCenter.ratingCommand.addTarget { event in
            let ratingEvent = event as! MPRatingCommandEvent
            if let currentTrack = self.currentTrack, currentTrack.server != nil {
                currentTrack.rating = NSNumber(value: ratingEvent.rating)
                return .success
            }
            return .noActionableNowPlayingItem
        }
        
        // Shuffle and repeat aren't exposed in macOS's now playing controls,
        // but is in watchOS now playing for a device... which only supports iPhone for now.
        // XXX: preservesXMode?
        remoteCommandCenter.changeShuffleModeCommand.isEnabled = true
        remoteCommandCenter.changeShuffleModeCommand.addTarget { event in
            let shuffleEvent = event as! MPChangeShuffleModeCommandEvent
            switch shuffleEvent.shuffleType {
            case .off:
                self.isShuffle = false
            case .items:
                self.isShuffle = true
            default:
                // XXX: Semantically correct for .collections et al?
                return .commandFailed
            }
            return .success
        }
        remoteCommandCenter.changeRepeatModeCommand.isEnabled = true
        remoteCommandCenter.changeRepeatModeCommand.addTarget { event in
            let repeatEvent = event as! MPChangeRepeatModeCommandEvent
            switch repeatEvent.repeatType {
            case .off:
                self.repeatMode = .no
            case .one:
                self.repeatMode = .one
            case .all:
                self.repeatMode = .all
            default:
                return .commandFailed
            }
            return .success
        }
        
        // XXX: maybe bookmark
    }
    
    // #MARK: - Now Playing
    
    private var songInfo: [String: Any] = [:]
    
    // These two are separate because updating metadata is more expensive than i.e. seek position
    
    private func updateSystemNowPlayingStatus() {
        let centre = MPNowPlayingInfoCenter.default()
        
        if let currentTrack = self.currentTrack {
            // times are in sec; trust the SBTrack if the player isn't ready
            // as passing NaNs here will crash the menu bar (!)
            let duration = durationTime
            if duration.isNaN || duration == 0 {
                songInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: 0)
                songInfo[MPMediaItemPropertyPlaybackDuration] = currentTrack.duration
            } else {
                songInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: currentTime)
                songInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration)
            }
        } else {
            songInfo.removeValue(forKey: MPNowPlayingInfoPropertyElapsedPlaybackTime)
            songInfo.removeValue(forKey: MPMediaItemPropertyPlaybackDuration)
        }
        
        if !isPaused && isPlaying {
            centre.playbackState = .playing
        } else if isPaused && isPlaying {
            centre.playbackState = .paused
        } else if !isPlaying {
            centre.playbackState = .stopped
        }
        
        centre.nowPlayingInfo = songInfo
    }
    
    private func updateSystemNowPlayingMetadataMusic() {
        if let currentTrack = self.currentTrack {
            songInfo[MPMediaItemPropertyAlbumTitle] = currentTrack.albumString
            songInfo[MPMediaItemPropertyArtist] = currentTrack.artistName ?? currentTrack.artistString
            songInfo[MPMediaItemPropertyGenre] = currentTrack.genre
            songInfo[MPMediaItemPropertyDiscNumber] = currentTrack.discNumber
            
            if let year = currentTrack.year {
                let calendar = Calendar.current
                let releaseYear = calendar.date(from: DateComponents(year: year.intValue)) as NSDate?
                songInfo[MPMediaItemPropertyReleaseDate] = releaseYear
            }
        }
    }
    
    private func updateSystemNowPlayingMetadataPodcast() {
        // XXX: It seems there's the raw metadata Subsonic doesn't give us (i.e.
        // "BBC World Service" as underlying artist)
        if let currentTrack = self.currentTrack as? SBEpisode {
            songInfo[MPMediaItemPropertyPodcastTitle] = currentTrack.podcast?.itemName
            songInfo[MPMediaItemPropertyArtist] = currentTrack.artistName ?? currentTrack.artistString
            
            if let publishDate = currentTrack.publishDate {
                songInfo[MPMediaItemPropertyReleaseDate] = publishDate
            } else if let year = currentTrack.year {
                let calendar = Calendar.current
                let releaseYear = calendar.date(from: DateComponents(year: year.intValue)) as NSDate?
                songInfo[MPMediaItemPropertyReleaseDate] = releaseYear
            }
        }
    }
    
    private func updateSystemNowPlayingMetadata() {
        if let currentTrack = self.currentTrack {
            // i guess if we ever support video again...
            songInfo[MPNowPlayingInfoPropertyMediaType] = NSNumber(value: MPNowPlayingInfoMediaType.audio.rawValue)
            // XXX: podcasts will have different properties on SBTrack
            songInfo[MPMediaItemPropertyTitle] = currentTrack.itemName
            songInfo[MPMediaItemPropertyRating] = currentTrack.rating
            // seems the OS can use this to generate waveforms? should it be the download URL?
            // avoid using streamURL to avoid possible console noise
            if let asset = remotePlayer.currentItem?.asset as? AVURLAsset {
                songInfo[MPMediaItemPropertyAssetURL] = asset.url
            }
            
            if currentTrack is SBEpisode {
                updateSystemNowPlayingMetadataPodcast()
            } else {
                updateSystemNowPlayingMetadataMusic()
            }
            
            let artwork = currentTrack.coverImage
            let mpArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { size in
                return artwork
            }
            songInfo[MPMediaItemPropertyArtwork] = mpArtwork
        } else {
            // should be safe if update status is called *after*
            songInfo.removeAll()
        }
    }
    
    private func updateSystemNowPlaying() {
        updateSystemNowPlayingMetadata()
        updateSystemNowPlayingStatus()
    }
    
    // #MARK: - User Notifications
    
    private func initNotifications() {
        let centre = UNUserNotificationCenter.current()
        centre.delegate = self
        
        let skipAction = UNNotificationAction.init(identifier: "SubmarinerSkipAction", title: "Skip")
        
        let nowPlayingCategory = UNNotificationCategory(identifier: "SubmarinerNowPlayingNotification", actions: [skipAction], intentIdentifiers: [])
        centre.setNotificationCategories([nowPlayingCategory])
        
        // XXX: Make it so we store if we can post a notification instead of blindly firing.
        centre.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                self.requestNotificationPermissions()
                // if it's not notDetermined, we're good or the user decided we're not good
            }
        }
    }
    
    private func requestNotificationPermissions() {
        let centre = UNUserNotificationCenter.current()
        // Requesting sound is unwanted when we're playing music.
        // Badge permissions might be useful, but we use badges for other things.
        centre.requestAuthorization(options: [UNAuthorizationOptions.alert]) { granted, error in
            if !granted {
                logger.warning("User denied permission for notifications")
            }
        }
    }
    
    private func postNowPlayingNotification() {
        if let currentTrack = self.currentTrack {
            let centre = UNUserNotificationCenter.current()
            
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = "SubmarinerNowPlayingNotification"
            content.title = currentTrack.itemName ?? ""
            content.body = subtitle
            
            // Add a cover image, fetch from our local cache since this API won't take an NSImage
            // XXX: Fetch from SBAlbum. The cover in SBTrack is seemingly only used for requests.
            // This means there's also a bunch of empty dupe cover objects in the DB...
            if let newCover = currentTrack.album?.cover, let coverPath = newCover.imagePath {
                let coverURL = URL(fileURLWithPath: coverPath as String)
                if let attachment = try? UNNotificationAttachment(identifier: "", url: coverURL) {
                    content.attachments = [attachment]
                }
            }
            
            // an interval of 0 faults
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(identifier: "SubmarinerNowPlayingNotification", content: content, trigger: trigger)
            centre.add(request)
        }
    }
    
    private func removeNowPlayingNotification() {
        let centre = UNUserNotificationCenter.current()
        let nowPlayingIdentifiers = ["SubmarinerNowPlayingNotification"]
        centre.removePendingNotificationRequests(withIdentifiers: nowPlayingIdentifiers)
        centre.removeDeliveredNotifications(withIdentifiers: nowPlayingIdentifiers)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // We have to do this if we implement the delegate.
        // If we didn't assign a delegate, we basically get this behaviour,
        // but if we did assign the delegate and didn't implement this method,
        // it would always supress the notification (UNNotificationPresentationOptionNone).
        let opts = NSApplication.shared.isActive ? UNNotificationPresentationOptions.list : UNNotificationPresentationOptions.banner
        completionHandler(opts)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Select the currently playing track if it's a SubmarinerNowPlayingNotification.
        // We don't need to know the track, because the coalescing means we only current is relevant.
        if response.notification.request.identifier == "SubmarinerNowPlayingNotification" {
            // Default, so not one of the buttons (if we have them or not)
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                DispatchQueue.main.async {
                    SBAppDelegate.sharedInstance().zoomDatabaseWindow(self)
                    SBAppDelegate.sharedInstance().goToCurrentTrack(self)
                }
            } else if response.actionIdentifier == "SubmarinerSkipAction" {
                self.next()
            }
        }
        completionHandler()
    }
    
    // #MARK: - Playlist Management
    
    // This shouldn't really be mutable outside of the player context...
    @objc var playlist: [SBTrack] = []
    
    @objc(addTrack:replace:) func add(track: SBTrack, replace: Bool) {
        if replace {
            playlist.removeAll()
        }
        
        playlist.append(track)
        NotificationCenter.default.post(name: SBPlayer.playlistUpdatedNotification, object: self)
    }
    
    @objc(addTrackArray:replace:) func add(tracks: [SBTrack], replace: Bool) {
        if replace {
            playlist.removeAll()
        }
        
        playlist.append(contentsOf: tracks)
        NotificationCenter.default.post(name: SBPlayer.playlistUpdatedNotification, object: self)
    }
    
    @objc(addTrack:atIndex:) func add(track: SBTrack, index: Int) {
        playlist.insert(track, at: index)
        NotificationCenter.default.post(name: SBPlayer.playlistUpdatedNotification, object: self)
    }
    
    @objc(removeTrack:) func remove(track: SBTrack) {
        if track == currentTrack {
            stop()
        }
        
        playlist.removeAll { candidateTrack in track == candidateTrack }
        NotificationCenter.default.post(name: SBPlayer.playlistUpdatedNotification, object: self)
    }
    
    @objc(removeTrackArray:) func remove(tracks: [SBTrack]) {
        if let currentTrack = self.currentTrack, tracks.contains(currentTrack) {
            stop()
        }
        
        playlist.removeAll { candidateTrack in tracks.contains(candidateTrack) }
        NotificationCenter.default.post(name: SBPlayer.playlistUpdatedNotification, object: self)
    }
    
    @objc(removeTrackIndexSet:) func remove(trackIndexSet: IndexSet) {
        if let currentTrack = self.currentTrack {
            trackIndexSet.forEach { i in
                if playlist[i] == currentTrack {
                    stop()
                }
            }
        }
        
        playlist.remove(atOffsets: trackIndexSet)
        NotificationCenter.default.post(name: SBPlayer.playlistUpdatedNotification, object: self)
    }
    
    @objc(moveTrackIndexSet:toIndex:) func move(trackIndexSet: IndexSet, index: Int) {
        playlist.move(fromOffsets: trackIndexSet, toOffset: index)
        NotificationCenter.default.post(name: SBPlayer.playlistUpdatedNotification, object: self)
    }
    
    // #MARK: - Player Control
    
    @objc dynamic var currentTrack: SBTrack?
    
    @objc dynamic var isPlaying = false
    @objc dynamic var isPaused = false
    
    @objc(playTrack:) func play(track: SBTrack) {
        if let currentTrack = self.currentTrack {
            unplayAllTracks()
            self.currentTrack = nil
        }
        
        if track.isVideo() {
            showVideoAlert()
            return
        }
        
        self.currentTrack = track
        self.playRemote(track: track)
        
        track.isPlaying = true
        NotificationCenter.default.post(name: SBPlayer.playlistUpdatedNotification, object: self)
        isPlaying = true
        isPaused = false
        NotificationCenter.default.post(name: SBPlayer.playStateNotification, object: self)
        
        // update npic
        updateSystemNowPlaying()
        postNowPlayingNotification()
        
        // scrobble if doing that
        if let server = track.server, track.localTrack?.streamURL() != nil,
           UserDefaults.standard.scrobbleToServer {
            server.clientController.scrobble(id: track.id!)
        }
    }
    
    private func playRemote(track: SBTrack) {
        remotePlayer.replaceCurrentItem(with: nil)
        
        let url = track.localTrack?.streamURL() ?? track.streamURL()!
        // XXX: Debug?
        if url.isFileURL {
            logger.info("Playing local track at file: \(url, privacy: .public)")
        } else {
            logger.info("Playing remote track via \(url.path, privacy: .public) at URL: \(url)")
        }
        
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetOutOfBandMIMETypeKey": track.macOSCompatibleContentType()!,
            AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(value: true)
        ])
        let newItem = AVPlayerItem(asset: asset)
        
        remotePlayer.replaceCurrentItem(with: newItem)
        remotePlayer.volume = volume
        remotePlayer.play()
    }
    
    @objc func playTracklistAtBeginning() {
        if let first = playlist.first {
            play(track: first)
        }
    }
    
    @objc func playOrResume() {
        remotePlayer.play()
        isPaused = false
        
        updateSystemNowPlaying()
        NotificationCenter.default.post(name: SBPlayer.playStateNotification, object: self)
    }
    
    @objc func pause() {
        remotePlayer.pause()
        isPaused = true
        
        updateSystemNowPlaying()
        NotificationCenter.default.post(name: SBPlayer.playStateNotification, object: self)
    }
    
    @objc func playPause() {
        let wasPlaying = isPlaying
        if remotePlayer.rate != 0 {
            remotePlayer.pause()
            isPaused = true
        } else {
            remotePlayer.play()
            isPaused = false
        }
        // if we weren't playing, we need to update the metadata
        if wasPlaying {
            updateSystemNowPlayingStatus()
        } else {
            updateSystemNowPlaying()
        }
        NotificationCenter.default.post(name: SBPlayer.playStateNotification, object: self)
    }
    
    private func maybeDeleteCurrentTrack() {
        if !UserDefaults.standard.deleteAfterPlay {
            return
        }
        if let currentTrack = self.currentTrack {
            remove(track: currentTrack)
        }
    }
    
    @objc func next() {
        maybeDeleteCurrentTrack()
        if let next = nextTrack() {
            synchronized(self) {
                play(track: next)
            }
        } else {
            stop()
        }
    }
    
    @objc func previous() {
        maybeDeleteCurrentTrack()
        if let prev = prevTrack() {
            synchronized(self) {
                play(track: prev)
            }
        } else {
            stop()
        }
    }
    
    @objc var volume: Float {
        get {
            return UserDefaults.standard.playerVolume
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "playerVolume")
            remotePlayer.volume = newValue
        }
    }
    
    @objc(seekToTime:) func seek(to: TimeInterval) {
        let timeCM = CMTimeMakeWithSeconds(to, preferredTimescale: Int32(NSEC_PER_SEC))
        remotePlayer.seek(to: timeCM)
        
        // seeks will desync the NPIC
        updateSystemNowPlayingStatus()
    }
    
    @objc(seek:) func seek(percentage: Double) {
        if let currentItem = remotePlayer.currentItem {
            let durationCM = currentItem.duration
            let newTimeCM = CMTimeMultiplyByFloat64(durationCM, multiplier: percentage / 100.0)
            remotePlayer.seek(to: newTimeCM)
        }
        
        // seeks will desync the NPIC
        updateSystemNowPlayingStatus()
    }
    
    @objc(relativeSeekBy:) func relativeSeekBy(increment: Float) {
        let maxTime = self.durationTime
        let newTime = min(maxTime, max(self.currentTime + Double(increment), 0))
        seek(to: newTime)
    }
    
    @objc func rewind() {
        let increment = -UserDefaults.standard.skipIncrement
        relativeSeekBy(increment: increment)
    }
    
    @objc func fastForward() {
        let increment = UserDefaults.standard.skipIncrement
        relativeSeekBy(increment: increment)
    }
    
    @objc func stop() {
        synchronized(self) {
            remotePlayer.replaceCurrentItem(with: nil)
            
            unplayAllTracks()
            currentTrack = nil
            
            isPlaying = false
            isPaused = true
            
            updateSystemNowPlaying()
            removeNowPlayingNotification()
            NotificationCenter.default.post(name: SBPlayer.playlistUpdatedNotification, object: self)
            NotificationCenter.default.post(name: SBPlayer.playStateNotification, object: self)
        }
    }
    
    @objc func clear() {
        playlist.removeAll()
        currentTrack = nil
    }
    
    // #MARK: - Accessors (Player Properties)
    
    @objc var subtitle: String {
        var ret: String? = ""
        if let currentEpisode = self.currentTrack as? SBEpisode? {
            ret = currentEpisode?.podcast?.itemName ?? (currentEpisode?.artistName ?? currentEpisode?.artistString!)
        } else if let currentTrack = self.currentTrack {
            let sep = " - "
            ret = (currentTrack.artistName ?? currentTrack.artistString!)
                + sep
                + currentTrack.albumString!
        }
        return ret ?? ""
    }
    
    @objc var currentTime: TimeInterval {
        let currentTimeCM = remotePlayer.currentTime()
        let currentTime = CMTimeGetSeconds(currentTimeCM)
        return currentTime
    }
    
    @objc var currentTimeString: String {
        return String(time: currentTime)
    }
    
    @objc var durationTime: TimeInterval {
        if let currentItem = remotePlayer.currentItem {
            let durationCM = currentItem.duration
            let duration = CMTimeGetSeconds(durationCM)
            return duration
        }
        return 0
    }
    
    @objc var remainingTime: TimeInterval {
        if let currentItem = remotePlayer.currentItem {
            let currentTimeCM = currentItem.currentTime()
            let currentTime = CMTimeGetSeconds(currentTimeCM)
            let durationCM = currentItem.duration
            let duration = CMTimeGetSeconds(durationCM)
            return duration - currentTime
        }
        return 0
    }
    
    @objc var remainingTimeString: String {
        return String(time: remainingTime)
    }
    
    @objc var progress: Double {
        if let currentItem = remotePlayer.currentItem {
            let currentTimeCM = currentItem.currentTime()
            let currentTime = CMTimeGetSeconds(currentTimeCM)
            let durationCM = currentItem.duration
            let duration = CMTimeGetSeconds(durationCM)
            if duration > 0 {
                let progress = currentTime / duration * 100 // percentage
                //if(progress == 100) { // movie is at end
                //    // let item finished playing handle this guy
                //    //[self next];
                //}
                return progress
            }
        }
        return 0
    }
    
    // @objc var percentLoaded: Double
    
    @objc dynamic var repeatMode: RepeatMode {
        get {
            return RepeatMode(rawValue: UserDefaults.standard.repeatMode) ?? .no
        } set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "repeatMode")
            // XXX: do we set this at init?
            var mprcRepeatType = MPRepeatType.off
            switch (newValue) {
            case .no:
                mprcRepeatType = .off
            case .one:
                mprcRepeatType = .one
            case .all:
                mprcRepeatType = .all
            }
            MPRemoteCommandCenter.shared().changeRepeatModeCommand.currentRepeatType = mprcRepeatType
        }
    }
    
    @objc dynamic var isShuffle: Bool {
        get {
            return UserDefaults.standard.shuffle
        } set {
            UserDefaults.standard.set(newValue, forKey: "shuffle")
            let mprcShuffleType = newValue ? MPShuffleType.items : MPShuffleType.off
            MPRemoteCommandCenter.shared().changeShuffleModeCommand.currentShuffleType = mprcShuffleType
        }
    }
    
    // #MARK: - Notifications
    
    @objc private func itemDidFinishPlaying(_ notification: Notification) {
        next()
    }
    
    // #MARK: - Private
    
    private func getRandomTrackExcept(track: SBTrack) -> SBTrack? {
        var randomTrack = track
        
        if playlist.count > 1 {
            while randomTrack == track {
                let randomIndex = Int.random(in: 0...playlist.count)
                randomTrack = playlist[randomIndex]
            }
            return randomTrack
        }
        
        return nil
    }
    
    private func nextTrack() -> SBTrack? {
        if repeatMode == .one {
            return currentTrack
        }
        
        if !isShuffle, let currentTrack = self.currentTrack,
           let index = playlist.firstIndex(of: currentTrack) {
            switch (repeatMode) {
            case .no:
                if index >= 0 && (playlist.count - 1) >= (index + 1) {
                    return playlist[index + 1]
                }
            case .all:
                if playlist.last == currentTrack && index > 0 {
                    return playlist.first
                } else if index >= 0 && (playlist.count - 1) >= (index + 1) {
                    return playlist[index + 1]
                }
            default:
                return nil
            }
            
            return nil
        } else if isShuffle, let currentTrack = self.currentTrack {
            return getRandomTrackExcept(track: currentTrack)
        }
        
        return nil
    }
    
    private func prevTrack() -> SBTrack? {
        if repeatMode == .one {
            return currentTrack
        }
        
        if !isShuffle, let currentTrack = self.currentTrack,
           let index = playlist.firstIndex(of: currentTrack) {
            
            if index == 0 {
                if repeatMode == .all {
                    return playlist.last
                } else {
                    // objectAtIndex for 0 - 1 is gonna throw, so don't
                    return nil
                }
            } else if index != -1 {
                return playlist[index - 1]
            }
            
            return nil
        } else if isShuffle, let currentTrack = self.currentTrack {
            return getRandomTrackExcept(track: currentTrack)
        }
        
        return nil
    }
    
    private func unplayAllTracks() {
        if let moc = self.currentTrack?.managedObjectContext {
            let predicate = NSPredicate(format: "(isPlaying == YES)")
            let fetchRequest = NSFetchRequest<SBTrack>(entityName: "Track")
            fetchRequest.predicate = predicate
            if let tracks = try? moc.fetch(fetchRequest) {
                for track in tracks {
                    track.isPlaying = false
                }
            }
        }
    }
    
    private func showVideoAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.informativeText = "Submariner doesn't support video."
        alert.messageText = "No Video"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
