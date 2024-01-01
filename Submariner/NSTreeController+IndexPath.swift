//
//  NSTreeController+IndexPath.swift
//  Submariner
//
//  Created by Calvin Buckley on 2022-10-01.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

import Foundation
import Cocoa

// https://stackoverflow.com/a/9050488
@objc extension NSTreeController {
    @objc(indexPathForObject:) func indexPath(for object: NSObject) -> NSIndexPath? {
        return self.indexPath(for: object, nodes: self.arrangedObjects.children)
    }

    private func indexPath(for object: NSObject, nodes: [NSTreeNode]!) -> NSIndexPath? {
        for node in nodes {
            if (object == node.representedObject as! NSObject)  {
                return node.indexPath as NSIndexPath
            }
            if (node.children != nil) {
                if let path:NSIndexPath = self.indexPath(for: object, nodes: node.children) {
                    return path
                }
            }
        }
        return nil
    }
}
