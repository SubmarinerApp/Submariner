//
//  SBAudioMetadata.swift
//  Submariner
//
//  Created by Calvin Buckley on 2022-10-06.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

import Cocoa
import AudioToolbox
import AVFoundation

// this is an ugly class to tide us over til taglib
// (which is better thought out beyond our core data model)
@objc class SBAudioMetadata: NSObject {
    private var audioFileInfoDict: NSDictionary?
    private var albumArtDedicated: NSData?
    private var id3Dict: NSDictionary?
    private var audioToolboxBitrate: UInt32 = 0
    
    private var asset: AVAsset?
    
    private let nf = NumberFormatter()
    
    private func initializeAudioToolboxInfoDict(af: AudioFileID) throws {
        var err: OSStatus
        var proposedSize: UInt32 = 0
        err = AudioFileGetPropertyInfo(af, kAudioFilePropertyInfoDictionary, &proposedSize, nil)
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        var audioFileInfoCFDict: Unmanaged<CFDictionary>? = nil
        err = AudioFileGetProperty(af, kAudioFilePropertyInfoDictionary, &proposedSize, &audioFileInfoCFDict)
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        // because it makes us free
        audioFileInfoDict = audioFileInfoCFDict?.takeRetainedValue()
    }
    
    private func initializeAudioToolboxAlbumArt(af: AudioFileID) throws {
        var err: OSStatus
        var proposedSize: UInt32 = 0
        err = AudioFileGetPropertyInfo(af, kAudioFilePropertyAlbumArtwork, &proposedSize, nil);
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        var albumArtCFData: Unmanaged<CFData>? = nil
        err = AudioFileGetProperty(af, kAudioFilePropertyAlbumArtwork, &proposedSize, &albumArtCFData);
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        self.albumArtDedicated = albumArtCFData?.takeRetainedValue()
    }
    
    // XXX: Might be useless if we check AVAsset.metadata too
    private func initializeAudioToolboxID3(af: AudioFileID) throws {
        var err: OSStatus
        var proposedSize: UInt32 = 0
        err = AudioFileGetPropertyInfo(af, kAudioFilePropertyID3Tag, &proposedSize, nil);
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        // we have to get the raw id3, then turn into a dict
        let id3buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(proposedSize), alignment: MemoryLayout<Int8>.alignment)
        defer {
            id3buffer.deallocate()
        }
        err = AudioFileGetProperty(af, kAudioFilePropertyID3Tag, &proposedSize, id3buffer);
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        // get the size of the dict...
        var id3Size: UInt32 = 0
        var id3SizeLength: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        err = AudioFormatGetProperty(kAudioFormatProperty_ID3TagSize, proposedSize, id3buffer, &id3SizeLength, &id3Size);
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        var id3CFDict: Unmanaged<CFDictionary>? = nil
        err = AudioFormatGetProperty(kAudioFormatProperty_ID3TagToDictionary, proposedSize, id3buffer, &id3Size, &id3CFDict);
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        self.id3Dict = id3CFDict?.takeRetainedValue()
    }
    
    private func initializeAudioToolboxInfoBitrate(af: AudioFileID) throws {
        var err: OSStatus
        var proposedSize: UInt32 = 0
        err = AudioFileGetPropertyInfo(af, kAudioFilePropertyBitRate, &proposedSize, nil)
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        err = AudioFileGetProperty(af, kAudioFilePropertyBitRate, &proposedSize, &self.audioToolboxBitrate)
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
    }
    
    // XXX: It'd be cute to have a managed Audio Toolbox wrapper...
    private func initializeAudioToolbox(URL: NSURL) throws {
        var err: OSStatus
        var af: AudioFileID!
        err = AudioFileOpenURL(URL, .readPermission, 0, &af)
        if (err != noErr) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err))
        }
        defer {
            AudioFileClose(af)
        }
        // These strategies are all non-fatal if they fail. Try in order:
        // 1. info dict
        // 2. album art
        // 3. id3
        // And close when we're done.
        do {
            try self.initializeAudioToolboxInfoDict(af: af)
        } catch {}
        do {
            try self.initializeAudioToolboxAlbumArt(af: af)
        } catch {}
        // XXX: May be better to let AVAsset handle ID3
        do {
            try self.initializeAudioToolboxID3(af: af)
        } catch {}
        do {
            try self.initializeAudioToolboxInfoBitrate(af: af)
        } catch {}
    }
    
    private func initializeAVFoundation(URL: NSURL) throws {
        self.asset = AVAsset(url: URL as URL)
    }
    
    @objc init(URL: NSURL) throws {
        super.init()
        nf.locale = .current
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = true
        // try Audio Toolbox first (handles everything, but weak on Vorbis-based/M4A),
        // then AVAsset (handles M4A, but not Vorbis)
        var avfError: Error? = nil
        var atError: Error? = nil
        do {
            try initializeAudioToolbox(URL: URL)
        } catch {
            atError = error
        }
        do {
            try initializeAVFoundation(URL: URL)
        } catch {
            avfError = error
        }
        // only throw if both failed
        if avfError != nil && atError == nil {
            throw avfError!
        } else if atError != nil && avfError == nil {
            throw atError!
        } else if atError != nil && avfError != nil {
            // either sucks
            throw atError!
        }
    }
    
    // now for the getters
    // Submariner needs...
    /*
     titleString       = [metadata title];
     artistString      = [metadata artist];
     albumArtistString = [metadata albumArtist];
     if (albumArtistString == nil || [albumArtistString isEqualToString: @""]) {
         albumArtistString = artistString;
     }
     albumString       = [metadata albumTitle];
     genreString       = [metadata genre];
     trackNumber       = [metadata trackNumber];
     discNumber        = [metadata discNumber];
     durationNumber    = [properties duration];
     bitRateNumber     = [properties bitrate];
     coverData         = [[[metadata attachedPictures] anyObject] imageData];
     */
    @objc var albumArt: NSData? {
        get {
            if albumArtDedicated != nil {
                return albumArtDedicated!
            }
            // else scan in ID3
            if let id3Dict = id3Dict, let covers: NSDictionary = id3Dict["APIC"] as? NSDictionary {
                var toReturn: NSData?
                for (k, _) in covers {
                    let cover: NSDictionary = covers[k] as! NSDictionary
                    let type: NSString = cover["picturetype"] as! NSString
                    if (type == "Cover (front)") {
                        toReturn = cover["data"] as? NSData
                        break
                    }
                }
                if toReturn == nil && id3Dict.count > 0 {
                    let cover: NSDictionary = covers.allValues.first as! NSDictionary
                    toReturn = cover["data"] as? NSData
                }
                return toReturn
            }
            return nil
        }
    }
    
    // a lot of these are basic enough the audio toolbox dict is the only thing we need to consult
    @objc var title: NSString? {
        get {
            if let audioFileInfoDict = audioFileInfoDict, let title: NSString = audioFileInfoDict["title"] as? NSString {
                return title
            }
            return nil
        }
    }
    
    @objc var albumTitle: NSString? {
        get {
            if let audioFileInfoDict = audioFileInfoDict, let album: NSString = audioFileInfoDict["album"] as? NSString {
                return album
            }
            return nil
        }
    }
    
    @objc var artist: NSString? {
        get {
            if let audioFileInfoDict = audioFileInfoDict, let artist: NSString = audioFileInfoDict["artist"] as? NSString {
                return artist
            }
            return nil
        }
    }
    
    @objc var genre: NSString? {
        get {
            if let audioFileInfoDict = audioFileInfoDict, let genre: NSString = audioFileInfoDict["genre"] as? NSString {
                return genre
            }
            return nil
        }
    }
    
    @objc var trackNumber: NSNumber? {
        get {
            if let audioFileInfoDict = audioFileInfoDict, let track: NSString = audioFileInfoDict["track number"] as? NSString {
                // It could be in "m/n" format, so split
                let parts = track.components(separatedBy: "/")
                if let trackNumber = Int(parts[0]) {
                    return NSNumber.init(value:  trackNumber)
                }
            }
            return nil
        }
    }
    
    @objc var duration: NSNumber? { // in seconds
        get {
            if let asset = asset {
                return NSNumber.init(value: asset.duration.seconds)
            }
            if let audioFileInfoDict = audioFileInfoDict, let durationString: NSString = audioFileInfoDict["approximate duration in seconds"] as? NSString {
                // durationString can have , and . - use NumberFormatter
                let durationString2 = durationString as String
                return nf.number(from: durationString2)
            }
            return nil
        }
    }
    
    // in kilobytes/s
    @objc var bitrate: NSNumber? {
        get {
            if audioToolboxBitrate > 0 {
                return NSNumber.init(value: audioToolboxBitrate / 1000) // not 1024, weirdly
            }
            if let asset = asset {
                // Uses the first one it can find, which should be the only one
                for track in asset.tracks(withMediaType: .audio) {
                    let bitrate: Float = track.estimatedDataRate
                    return NSNumber.init(value: bitrate / 1000)
                }
            }
            return nil
        }
    }
    
    // more complex... Audio Toolbox doesn't fetch these. have to check ID3 or M4A metadata
    @objc var discNumber: NSNumber? {
        get {
            if let id3Dict = id3Dict, let tpos: NSString = id3Dict["TPOS"] as? NSString {
                // like disc number
                let parts = tpos.components(separatedBy: "/")
                if let discNumber = Int(parts[0]) {
                    return NSNumber.init(value:  discNumber)
                }
            }
            if let asset = asset {
                for metadata in asset.metadata {
                    if (metadata.identifier == .iTunesMetadataDiscNumber) {
                        return metadata.numberValue
                    }
                }
            }
            return nil
        }
    }
    
    @objc var albumArtist: NSString? {
        get {
            if let id3Dict = id3Dict, let tpe2: NSString = id3Dict["TPE2"] as? NSString {
                return tpe2
            }
            if let asset = asset {
                for metadata in asset.metadata {
                    if (metadata.identifier == .iTunesMetadataAlbumArtist) {
                        return metadata.stringValue as NSString?
                    }
                }
            }
            return nil
        }
    }
}
