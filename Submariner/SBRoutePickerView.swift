//
//  SBRoutePickerView.swift
//  Submariner
//
//  Created by Calvin Buckley on 2022-11-04.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

import Cocoa
import AVKit

@objc class SBRoutePickerView: AVRoutePickerView {
    private func sharedInit() {
        self.player = SBPlayer.sharedInstance().remotePlayer
        self.isRoutePickerButtonBordered = true
        
        let button = self.subviews.first as! NSButton
        button.bezelStyle = .texturedRounded // as to match other buttons
    }
    
    @objc required init?(coder: NSCoder) {
        super.init(coder: coder)
        sharedInit()
    }
    
    @objc override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        sharedInit()
    }
    
    @objc deinit {
        self.player = nil
    }
}
