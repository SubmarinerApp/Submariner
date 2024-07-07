//
//  UserDefaults+Submariner.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-27.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Foundation

/// Extension to have structured key paths and getters.
extension UserDefaults {
    @objc dynamic var autoRefreshNowPlaying: Bool {
        return bool(forKey: "autoRefreshNowPlaying")
    }
    
    @objc dynamic var enableCacheStreaming: Bool {
        return bool(forKey: "enableCacheStreaming")
    }
    
    @objc dynamic var deleteAfterPlay: Bool {
        return bool(forKey: "deleteAfterPlay")
    }
    
    @objc dynamic var playerVolume: Float {
        return float(forKey: "playerVolume")
    }
    
    @objc dynamic var repeatMode: Int {
        return integer(forKey: "repeatMode")
    }
    
    @objc dynamic var shuffle: Bool {
        return bool(forKey: "shuffle")
    }
    
    @objc dynamic var skipIncrement: Float {
        return float(forKey: "SkipIncrement")
    }
    
    @objc dynamic var scrobbleToServer: Bool {
        return bool(forKey: "scrobbleToServer")
    }
    
    @objc dynamic var playerBehavior: Int {
        return integer(forKey: "playerBehavior")
    }
    
    // This can't be a float return because Swift KVO ignores it otherwise
    @objc dynamic var coverSize: NSNumber {
        return NSNumber(value: float(forKey: "coverSize"))
    }
    
    @objc dynamic var playRate: NSNumber {
        return NSNumber(value: float(forKey: "playRate"))
    }
}
