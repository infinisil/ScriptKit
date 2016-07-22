//
//  Files.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 21/07/16.
//  
//

import Foundation

public struct Path : StringLiteralConvertible {
    let path : String
    
    public init(string: String) {
        path = NSString(string: string).stringByExpandingTildeInPath
    }
    
    public init(stringLiteral value: String) {
        self.init(string: value)
    }
}

extension StringLiteralConvertible where StringLiteralType == String {
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(stringLiteral: value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.init(stringLiteral: value)
    }
}

public func touch(path: Path) -> NSFileHandle {
    if !NSFileManager.defaultManager().fileExistsAtPath(path.path) {
        NSFileManager.defaultManager().createFileAtPath(path.path, contents: nil, attributes: nil)
    }
    return NSFileHandle(forUpdatingAtPath: path.path)!
}
    
public func >(lhs: String, rhs: NSFileHandle) {
    rhs.truncateFileAtOffset(0)
    rhs.writeData(lhs.dataUsingEncoding(NSUTF8StringEncoding)!)
}
    
public func >>(lhs: String, rhs: NSFileHandle) {
    rhs.seekToEndOfFile()
    rhs.writeData(lhs.dataUsingEncoding(NSUTF8StringEncoding)!)
}
