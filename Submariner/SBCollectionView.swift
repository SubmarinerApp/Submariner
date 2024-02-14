//
//  SBCollectionView.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-12.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

@objc(SBCollectionView) class SBCollectionView: NSCollectionView {
    // Make it so right-clicking for the menu will select the item under the cursor.
    override func rightMouseDown(with event: NSEvent) {
        defer {
            super.rightMouseDown(with: event)
        }
        
        let point = self.convert(event.locationInWindow, from: nil)
        if let path = indexPathForItem(at: point) {
            deselectAll(self)
            
            guard numberOfItems(inSection: 0) > path.item else {
                return
            }
            
            let paths = Set([path])
            selectItems(at: paths, scrollPosition: .nearestVerticalEdge)
            delegate?.collectionView?(self, didSelectItemsAt: paths)
        }
    }
    
    @objc(scrollToItemsInIndices:scrollPosition:) func selectItems(in indices: IndexSet, scrollPosition: NSCollectionView.ScrollPosition) {
        let indexPaths = Set(indices.map { IndexPath(item: $0, section: 0) })
        self.selectItems(at: indexPaths, scrollPosition: scrollPosition)
    }
}
