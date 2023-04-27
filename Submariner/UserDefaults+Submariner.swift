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
}
