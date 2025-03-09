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

@objc(SBSourceListViewItem) class SBSourceListViewItem: NSTableCellView {
    var resource: SBResource! {
        objectValue as? SBResource
    }
    
    override var objectValue: Any? {
        didSet {
            if textField != nil {
                textField = nil
                imageView = nil
                subviews.removeAll()
            }
            self.translatesAutoresizingMaskIntoConstraints = false
            
            if let section = objectValue as? SBSection {
                sectionHeader(for: section)
            } else if let resource = objectValue as? SBResource {
                sectionItem(for: resource)
            }
        }
    }
    
    // MARK: - Responder Glue
    
    // This is a bit weird. View based tables seem to have editing work by having the
    // view for the row->column become first responder, but we want to pass it to
    // the (semi-blessed) text field instead, so we can actually work with the text
    // field and type into it. This is pretty awkward.
    override func becomeFirstResponder() -> Bool {
        guard !(resource is SBSection), let textField = self.textField else {
            return false
        }
        textField.isEditable = true
        return window?.makeFirstResponder(textField) ?? super.becomeFirstResponder()
    }
    
    override var acceptsFirstResponder: Bool {
        true
    }
    
    // MARK: - Create Views
    
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
    
    private func sectionHeader(for resource: SBSection) {
        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.stringValue = resource.resourceName ?? ""
        textField.isEditable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        // XXX: Should be subheading font style, but we need to set the weight too
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        textField.font = font
        textField.textColor = .tertiaryLabelColor
        self.textField = textField
        self.addSubview(textField)
        textField.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -4.0).isActive = true
        textField.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 4.0).isActive = true
        textField.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
    }
    
    private func sectionItem(for resource: SBResource) {
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: CGSize(width: 20, height: 20)))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = self.icon
        self.imageView = imageView
        self.addSubview(imageView)
        // image always has a vertical inset of 4px (i.e. medium 28pt row height, 20pt image)
        // that said, 4 doesn't seem exact either; a multiplier seems to handle S/M/L alignment better?
        // https://developer.apple.com/design/human-interface-guidelines/sidebars#macOS
        imageView.topAnchor.constraint(equalToSystemSpacingBelow: self.topAnchor, multiplier: 0.45).isActive = true
        imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -4.0).isActive = true
        imageView.widthAnchor.constraint(equalTo: self.heightAnchor).isActive = true
        imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        
        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.stringValue = resource.resourceName ?? ""
        textField.isEditable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.sendsActionOnEndEditing = true
        // XXX: Seet it here as bindings will set this
        textField.target = self
        textField.action = #selector(SBSourceListViewItem.renameItem(_:))
        self.textField = textField
        self.addSubview(textField)
        textField.centerYAnchor.constraint(equalTo: imageView.centerYAnchor).isActive = true
        textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 2).isActive = true
        // XXX: For some reason, this anchor breaks the editing mode for the text field
        //textField.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
    }
    
    // MARK: - Rename Action
    
    // this logic used to live in SBDatabaseController
    @IBAction func renameItem(_ sender: Any) {
        guard let name = textField?.stringValue, !name.isEmpty else {
            return
        }
        // TODO: This probably belongs in SBResource/children somewhere?
        // Let the remote server have a say first, just do it for local
        if let playlist = objectValue as? SBPlaylist, let server = playlist.server {
            server.updatePlaylist(ID: playlist.itemId!, name: name)
        } else if let resource = objectValue as? SBResource {
            resource.resourceName = name
        }
        textField?.sizeToFit()
    }
}
