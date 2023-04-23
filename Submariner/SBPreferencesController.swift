//
//  SBPreferencesController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import SwiftUI

// When we switch to the SwiftUI app lifecycle, we can just use the Settings view type.
@objc class SBPreferencesController: SBWindowController, NSToolbarDelegate {
    override class func nibName() -> String! {
        return nil
    }
    
    let playerSettingsView: NSViewController = NSHostingController(rootView: PlayerView())
    let serverSettingsView: NSViewController = NSHostingController(rootView: SubsonicView())
    let appearanceSettingsView: NSViewController = NSHostingController(rootView: AppearanceView())
    let playerSettingsItemIdentifier = NSToolbarItem.Identifier(rawValue: "SBPreferencesPlayerItem")
    let serverSettingsItemIdentifier = NSToolbarItem.Identifier(rawValue: "SBPreferencesServerItem")
    let appearanceSettingsItemIdentifier = NSToolbarItem.Identifier(rawValue: "SBPreferencesAppearanceItem")
    let toolbarItemIdentifiers: [NSToolbarItem.Identifier]

    override init!(managedObjectContext context: NSManagedObjectContext!) {
        self.toolbarItemIdentifiers = [
            playerSettingsItemIdentifier,
            serverSettingsItemIdentifier,
            appearanceSettingsItemIdentifier
        ]

        super.init(managedObjectContext: context)
        
        let window = NSWindow(contentViewController: playerSettingsView)
        window.styleMask = [.closable, .miniaturizable, .titled, .resizable]
        window.title = "Settings"
        
        window.toolbarStyle = .preference
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier(stringLiteral: "SBPreferencesToolbar"))
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .default
        toolbar.delegate = self
        window.toolbar = toolbar
        
        self.window = window
        switchView(identifier: playerSettingsItemIdentifier)
    }
    
    required init?(coder: NSCoder) {
        abort()
    }
    
    // #MARK: -
    // #MARK: NSToolbar Delegate
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch (itemIdentifier) {
        case playerSettingsItemIdentifier:
            let playerSettingsItem = NSToolbarItem(itemIdentifier: playerSettingsItemIdentifier)
            playerSettingsItem.image = NSImage(systemSymbolName: "hifispeaker", accessibilityDescription: "Player Settings")
            playerSettingsItem.label = "Player"
            playerSettingsItem.action = #selector(switchView(sender:))
            return playerSettingsItem
        case serverSettingsItemIdentifier:
            let serverSettingsItem = NSToolbarItem(itemIdentifier: serverSettingsItemIdentifier)
            serverSettingsItem.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Server Settings")
            serverSettingsItem.label = "Server"
            serverSettingsItem.action = #selector(switchView(sender:))
            return serverSettingsItem
        case appearanceSettingsItemIdentifier:
            let appearanceSettingsItem = NSToolbarItem(itemIdentifier: appearanceSettingsItemIdentifier)
            appearanceSettingsItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: "Appearance Settings")
            appearanceSettingsItem.label = "Appearance"
            appearanceSettingsItem.action = #selector(switchView(sender:))
            return appearanceSettingsItem
        default:
            return nil
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarItemIdentifiers
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarItemIdentifiers
    }
    
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarItemIdentifiers
    }
    
    func switchView(identifier: NSToolbarItem.Identifier) {
        if let window = self.window {
            var newView: NSViewController?
            switch (identifier) {
            case playerSettingsItemIdentifier:
                newView = playerSettingsView
                window.toolbar?.selectedItemIdentifier = playerSettingsItemIdentifier
                window.title = "Player"
            case serverSettingsItemIdentifier:
                newView = serverSettingsView
                window.toolbar?.selectedItemIdentifier = serverSettingsItemIdentifier
                window.title = "Server"
            case appearanceSettingsItemIdentifier:
                newView = appearanceSettingsView
                window.toolbar?.selectedItemIdentifier = appearanceSettingsItemIdentifier
                window.title = "Appearance"
            default:
                abort()
            }
            NSAnimationContext.runAnimationGroup({ context in
                window.animator().contentViewController = newView // Should be set first
                let newFrame = window.frameRect(forContentRect: newView!.view.frame)
                let oldFrame = window.frame
                var calculatedFrame = window.frame
                calculatedFrame.size = newFrame.size
                calculatedFrame.origin.y -= (newFrame.size.height - oldFrame.size.height)
                window.animator().setFrame(calculatedFrame, display: true)
            })
        }
    }
    
    @IBAction func switchView(sender: NSToolbarItem) {
        switchView(identifier: sender.itemIdentifier)
    }
    
    // #MARK: -
    // #MARK: SwiftUI Views
    
    struct PlayerView: View {
        @AppStorage("enableCacheStreaming") var automaticallyDownload = false
        @AppStorage("deleteAfterPlay") var deleteOnEnd = false
        @AppStorage("SkipIncrement") var skipBySeconds = 5.0
        @AppStorage("playerBehavior") var whenQueueing = 0
        
        var body: some View {
            Form {
                Section {
                    Toggle("Automatically download playing track", isOn: $automaticallyDownload)
                    Toggle("Delete from tracklist at track end", isOn: $deleteOnEnd)
                }
                Section {
                    Picker(selection: $whenQueueing, label: Text("When queueing a track")) {
                        Text("Add to tracklist").tag(0)
                        Text("Replace tracklist").tag(1)
                    }
                }
                Section {
                    TextField("Skip by number of seconds", value: $skipBySeconds, formatter: NumberFormatter())
                }
            }
            .fixedSize()
            .modify {
                if #available(macOS 13, *) {
                    $0.formStyle(.grouped)
                }
            }
        }
    }

    struct AppearanceView: View {
        @AppStorage("coverSize") var coverSize = 0.75
        
        var body: some View {
            Form {
                Slider(value: $coverSize, in: 0...1, step: 0.05) {
                    Text("Cover size")
                } minimumValueLabel: {
                    Text("Min")
                } maximumValueLabel: {
                    Text("Max")
                }
            }
            .fixedSize()
            .modify {
                if #available(macOS 13, *) {
                    $0.formStyle(.grouped)
                }
            }
        }
    }

    struct SubsonicView: View {
        @AppStorage("scrobbleToServer") var scrobble = false
        @AppStorage("autoRefreshNowPlaying") var autoRefreshNowPlaying = false
        @AppStorage("MaxCoverSize") var coverSize = 300
        
        var body: some View {
            Form {
                Section {
                    Toggle("Automatically refresh server users view", isOn: $autoRefreshNowPlaying)
                }
                Section {
                    Picker(selection: $coverSize, label: Text("Cover size to download")) {
                        Text("130x130").tag(130)
                        Text("300x300").tag(300)
                        Text("600x600").tag(600)
                    }
                }
                Section {
                    Toggle("Scrobble tracks to server", isOn: $scrobble)
                }
            }
            .fixedSize()
            .modify {
                if #available(macOS 13, *) {
                    $0.formStyle(.grouped)
                }
            }
        }
    }
}
