//
//  Files.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 21/07/16.
//  
//

import Foundation

struct Path : ExpressibleByStringLiteral {
    let path : String
    
    init(string: String) {
        path = NSString(string: string).expandingTildeInPath
    }
    
    init(stringLiteral value: String) {
        self.init(string: value)
    }
}

extension ExpressibleByStringLiteral where StringLiteralType == String {
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(stringLiteral: value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.init(stringLiteral: value)
    }
}

func touch(_ path: Path) -> FileHandle {
    if !FileManager.default.fileExists(atPath: path.path) {
        FileManager.default.createFile(atPath: path.path, contents: nil, attributes: nil)
    }
    return FileHandle(forUpdatingAtPath: path.path)!
}
    
func >(lhs: String, rhs: FileHandle) {
    rhs.truncateFile(atOffset: 0)
    rhs.write(lhs.data(using: .utf8)!)
}
    
func >>(lhs: String, rhs: FileHandle) {
    rhs.seekToEndOfFile()
    rhs.write(lhs.data(using: .utf8)!)
}
