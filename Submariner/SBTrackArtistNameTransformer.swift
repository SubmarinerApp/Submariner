//
//  SBTrackArtistNameTransformer.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa

@objcMembers class SBTrackArtistNameTransformer: ValueTransformer {
    override class func allowsReverseTransformation() -> Bool {
        false
    }
    
    override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        // value is NSNumber-based enum
        if let track = value as? SBTrack {
            if let artistName = track.artistName, artistName != "" {
                return artistName
            }
            return track.album?.artist?.itemName
        }
        return nil
    }
}
