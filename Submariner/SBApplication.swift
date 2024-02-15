//
//  SBApplication.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-06-03.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa

@objc(SBApplication) class SBApplication: NSApplication {
    // https://stackoverflow.com/a/32246600
    override func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)
        
        if event.type == .keyDown && event.keyCode == 49 {
            // only trigger if we're not in something editing shaped,
            // where space does something the user expects
            if let firstResponder = event.window?.firstResponder,
               firstResponder is NSText {
                return
            }
            if let fakeEvent = NSEvent.keyEvent(with: .keyDown,
                                                location: .zero,
                                                modifierFlags: [],
                                                timestamp: ProcessInfo.processInfo.systemUptime,
                                                windowNumber: event.windowNumber,
                                                context: .current,
                                                characters: " ",
                                                charactersIgnoringModifiers: " ",
                                                isARepeat: false,
                                                keyCode: 49) {
                NSApp.mainMenu?.performKeyEquivalent(with: fakeEvent)
            }
        }
    }
    
    // #MARK: - AppleScript handlers
    
    @objc var currentTrack: SBTrack? {
        SBPlayer.sharedInstance().currentTrack
    }
    
    @objc var playState: String {
        let playingTrack = SBPlayer.sharedInstance().isPlaying
        let pausedTrack = SBPlayer.sharedInstance().isPaused
        
        if playingTrack && pausedTrack {
            return "paused"
        } else if playingTrack {
            return "playing"
        } else {
            return "stopped"
        }
    }
}
