//
//  String+File.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers

extension String {
    static let illegalFilenameCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")
    
    func isValidFileName() -> Bool {
        if self == "" || self == "." || self == ".." {
            return false
        }
        
        return self.rangeOfCharacter(from: String.illegalFilenameCharacters) == nil
    }
}
