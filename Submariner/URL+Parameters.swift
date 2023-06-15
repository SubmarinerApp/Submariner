//
//  NSURL+Parameters.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-22.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Foundation

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
    static func URLWith(string: String, command: String, parameters:  [String: String]?, andParameterString: String?) -> URL? {
        // string -> "http://ip:port"; the base URL (which could have its own path components)
        // command -> "rest/ping.view"; the API endpoint
        // so, we get "http://ip:port/rest/ping.view" from appendingPathComponent
        let baseUrl = URL.init(string: string)!
            .appendingPathComponent(command)
        var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)!
        
        if let parameters = parameters {
            components.query = "" // we have to init it to use it
            // XXX: the Objective-C version called into a CF API for specific escaping rules
            // (that is, CFURLCreateStringByAddingPercentEscapes
            //  and legal characters escaped as @";?:/@&=+$,")
            let queryItems = parameters.map { (k, v) in URLQueryItem(name: k, value: v) }
            components.queryItems?.append(contentsOf: queryItems)
            
            // parameterString is used for cases where there are duplicate keys
            // (i.e. songId for playlist manipulation), and can't be represented
            // by a dictionary. it will always have & prefixed, so it'll be safe
            if let andParameterString = andParameterString {
                components.query?.append(andParameterString)
            }
        }
        // objc version had strange check for converting ":/" into "://" - probably NSURL bug in snep?
        
        return components.url
    }
    
    static func URLWith(string: String, command: String, parameters:  [String: String]?) -> URL? {
        return URLWith(string: string, command: command, parameters: parameters, andParameterString: nil)
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
