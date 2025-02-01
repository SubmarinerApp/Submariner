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
    
    static func temporaryFile(fileExtension: String? = nil) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        var randomName = UUID().uuidString
        // better to use the UTType appendingPathExtension if possible
        if let fileExtension = fileExtension, !fileExtension.isEmpty {
            randomName += ".\(fileExtension)"
        }
        return tempDir.appendingPathComponent(randomName)
    }
    
    // #MARK: -
    // #MARK: Parameters
    
    // XXX: Convert to initializers
    static func URLWith(string: String?, command: String, parameters:  [URLQueryItem]) -> URL? {
        if string == nil {
            return nil
        }
        // string -> "http://ip:port"; the base URL (which could have its own path components)
        // command -> "rest/ping.view"; the API endpoint
        // so, we get "http://ip:port/rest/ping.view" from appendingPathComponent
        var components = URLComponents(string: string!) ?? URLComponents()
        // crude way to reject an invalid URL... we need valid scheme
        // TODO: prettier way
        if components.scheme == nil {
            return nil
        }
        
        if components.path.last != "/" {
            components.path.append("/")
        }
        components.path.append(command)
        
        // XXX: Debug?
        logger.info("Assembling base URL \(components.string ?? "<nil>")")
        logger.info("\tAPI endpoint \(components.path, privacy: .public)")
        for item in parameters {
            // XXX: Debug?
            if let value = item.value, item.name == "p" || item.name == "t" || item.name == "s" {
                logger.info("\tSensitive parameter \(item.name, privacy: .public) = \(value.count) long")
            } else if let value = item.value {
                logger.info("\tparameter \(item.name, privacy: .public) = \(value, privacy: .public)")
            } else {
                logger.info("\tparameter \(item.name, privacy: .public) has no value")
            }
        }
        
        if !parameters.isEmpty {
            components.query = "" // we have to init it to use it
            components.queryItems?.append(contentsOf: parameters)
        }
        
        return components.url
    }
    
    static func URLWith(string: String?, command: String, parameters:  [String: String]) -> URL? {
        let queryItems = parameters.map { (k, v) in  URLQueryItem(name: k, value: v) }
        return URLWith(string: string, command: command, parameters: queryItems)
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
