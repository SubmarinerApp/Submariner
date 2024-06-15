//
//  SBStarrable.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-06-15.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//

import Foundation

@objc(SBStarrable) protocol SBStarrable {
    @objc var starredBool: Bool { get set }
}
