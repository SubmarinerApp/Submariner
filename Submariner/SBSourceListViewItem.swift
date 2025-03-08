//
//  SBSourceListViewItem.swift
//  Submariner
//
//  Created by Calvin Buckley on 2025-03-05.
//
//  Copyright (c) 2025 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa
import SwiftUI

@objc(SBSourceListViewItem) class SBSourceListViewItem: NSView {
    // XXX: NSOutlineView.makeViewWithIdentifier
    @objc static func createView(for resource: SBResource) -> NSView {
        return NSHostingView(rootView: ItemView(resource: resource))
    }
    
    struct ItemView: View {
        @ObservedObject var resource: SBResource
        
        @Environment(\.controlActiveState) var controlActiveState: ControlActiveState
        
        var icon: NSImage? {
            if resource is SBLibrary {
                return NSImage(systemSymbolName: "music.note", accessibilityDescription: "Local Library")
            } else if resource is SBPlaylist {
                return NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Playlist")
            } else if resource is SBServer {
                return NSImage(systemSymbolName: "network", accessibilityDescription: "Server")
            } else if resource is SBDownloads {
                return NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Downloads")
            }
            return nil
        }
        
        var body: some View {
            // https://developer.apple.com/design/human-interface-guidelines/sidebars#macOS
            // Our row height comes from our hosting NSOutlineView's delegate
            // Small: 16px icons, subheading text; Medium: 16px icons, body text
            HStack(alignment: .center, spacing: 4) {
                if resource is SBSection {
                    if let name = resource.resourceName {
                        Text(name)
                            .foregroundStyle(.tertiary)
                            .font(.subheadline.weight(.semibold))
                    }
                } else {
                    if let image = self.icon {
                        Image(nsImage: image)
                            .foregroundStyle(.tint)
                            .frame(width: 20, height: 20, alignment: .center)
                    }
                    if let name = resource.resourceName {
                        Text(name)
                            .font(.body)
                    }
                }
                Spacer()
            }
        }
    }
}
