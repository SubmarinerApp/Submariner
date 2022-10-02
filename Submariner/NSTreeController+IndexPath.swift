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
    @objc(indexPathForObject:) func indexPathFor(object:NSObject) -> NSIndexPath? {
        return self.indexPathFor(object: object, nodes: self.arrangedObjects.children)
    }

    @objc(indexPathForObject::) func indexPathFor(object:NSObject, nodes:[NSTreeNode]!) -> NSIndexPath? {
        for node in nodes {
            if (object == node.representedObject as! NSObject)  {
                return node.indexPath as NSIndexPath
            }
            if (node.children != nil) {
                if let path:NSIndexPath = self.indexPathFor(object: object, nodes: node.children)
                {
                    return path
                }
            }
        }
        return nil
    }
}
