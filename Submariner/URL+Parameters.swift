//
//  NSURL+Parameters.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-22.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Foundation
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "URL+Parameters")

extension URL {
    // #MARK: -
    // #MARK: Temporary Files
    
    static func temporaryFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let randomName = UUID().uuidString
        return tempDir.appendingPathComponent(randomName)
    }
    
    // #MARK: -
    // #MARK: Parameters
    
    // XXX: Convert to initializers
    static func URLWith(string: String, command: String, queryItems:  [URLQueryItem]) -> URL? {
        // string -> "http://ip:port"; the base URL (which could have its own path components)
        // command -> "rest/ping.view"; the API endpoint
        // so, we get "http://ip:port/rest/ping.view" from appendingPathComponent
        var components = URLComponents(string: string)!
        if components.path.last != "/" {
            components.path.append("/")
        }
        components.path.append(command)
        
        // XXX: Debug?
        logger.info("Assembling base URL \(components.string ?? "<nil>")")
        logger.info("\tAPI endpoint \(components.path, privacy: .public)")
        for item in queryItems {
            // XXX: Debug?
            if let value = item.value, item.name == "p" || item.name == "t" || item.name == "s" {
                logger.info("\tSensitive parameter \(item.name, privacy: .public) = \(value.count) long")
            } else if let value = item.value {
                logger.info("\tparameter \(item.name, privacy: .public) = \(value, privacy: .public)")
            } else {
                logger.info("\tparameter \(item.name, privacy: .public) has no value")
            }
        }
        
        components.query = "" // we have to init it to use it
        components.queryItems?.append(contentsOf: queryItems)
        // objc version had strange check for converting ":/" into "://" - probably NSURL bug in snep?
        
        return components.url
    }
    
    static func URLWith(string: String, command: String, parameters:  [String: String]) -> URL? {
        // XXX: the Objective-C version called into a CF API for specific escaping rules
        // (that is, CFURLCreateStringByAddingPercentEscapes
        //  and legal characters escaped as @";?:/@&=+$,")
        let queryItems = parameters.map { (k, v) in  URLQueryItem(name: k, value: v) }
        return URLWith(string: string, command: command, queryItems: queryItems)
    }
    
    // #MARK: -
    // #MARK: Keychain
    
    var keychainProtocol: NSNumber {
        return NSNumber(value: (self.scheme == "https" ? SecProtocolType.HTTPS : SecProtocolType.HTTP).rawValue)
    }
    
    var portWithHTTPFallback: NSNumber {
        if let port = self.port {
            return NSNumber(value: port)
        }
        return NSNumber(value: self.scheme == "https" ? 443 : 80)
    }
}
