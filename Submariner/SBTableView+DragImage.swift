//
//  SBTableView+DragImage.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-27.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//

import Cocoa

// From: https://gist.github.com/chotiwat/c98dea2870027fd8f7a90fac48cc3099
// The reason why we need this is because when using the `tableView:pasteboardWriterForRow:` methods use a different
// drag image than the legacy `tableView:writeRowsWithIndexes:toPasteboard:`. The old one would select the whole row,
// whereas the new one only grabs the specific cell. I get the impression it's easier with a view based approach and
// changing the drag image providers. Unfortunately, I'm not aware of a simpler way to do this...
// XXX: Fold into SBTableView once it's converted to Swift
extension SBTableView {
    func convert(_ point: NSPoint, fromDescendant view: NSView?) -> NSPoint {
        var currentView: NSView? = view
        var converted = point
        while currentView != nil && currentView != self {
            converted = currentView!.convert(converted, to: currentView!.superview)
            currentView = currentView!.superview
        }
        return converted
    }
    
    // Here we set the drag image to that of the row with the left edge aligned
    // to the left edge of the row.
    func setDragImage(of item: NSDraggingItem, for row: Int, at screenPoint: NSPoint) {
        // Find the left edge of the row by converting the header view origin to
        // the table view coordinate
        // If the header view doesn't exist (i.e. tracklist), let's use our superview,
        // since we can't use ourself.
        var headerOrigin = convert(headerView?.frame.origin ?? NSZeroPoint, fromDescendant: headerView ?? self.superview)
        
        // Generate the drag image from the current row with all the columns
        var p: NSPoint = .zero
        let image = dragImageForRows(with: IndexSet(integer: row), tableColumns: tableColumns, event: NSEvent(), offset: &p)
        
        // The drag image uses the screen point as the base coordinate `(0, 0)`.
        // We calculate the new horizontal offset by translating the left edge to
        // the screen point.
        headerOrigin = window!.convertPoint(toScreen: headerOrigin)
        let minX = headerOrigin.x - screenPoint.x
        let newFrame = NSRect(x: minX, y: item.draggingFrame.minY, width: image.size.width, height: image.size.height)
        
        // Set the new image to the dragging item
        item.setDraggingFrame(newFrame, contents: image)
    }
    
    open override func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        // Enumberate pasteboard items and set images based on the corresponding rows.
        session.enumerateDraggingItems(options: .concurrent,
                                       for: nil,
                                       classes: [NSPasteboardItem.self],
                                       searchOptions: [:]) { (item, index, _) in
            let pbItem = session.draggingPasteboard.pasteboardItems?[index]
            // for some reason getting the plist type doesn't work (so no NSNumber), we have to use .data
            guard let rowData = pbItem?.data(forType: .rowIndex) else {
                return
            }
            let row = rowData.withUnsafeBytes{ $0.load(as: Int.self) }
            
            setDragImage(of: item, for: row, at: screenPoint)
        }
    }
}
