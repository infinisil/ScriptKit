//
//  main.swift
//  KeycodeGenerator
//
//  Created by Silvan Mosberger on 22/07/16.
//
//

import Foundation

let relativeKeyCodesFilePath = "/ScriptKit/KeyCodes.swift"
let sourceFilePath = "/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/Events.h"
let keyword = "DOIT" // Everthing before and including the first appearance of this keyword won't be overridden

let keyCodesFilePath = Process.arguments[1] + relativeKeyCodesFilePath
var contents = try! String(contentsOfFile: keyCodesFilePath)

if let range = contents.rangeOfString(keyword) {
    contents.removeRange(range.endIndex..<contents.endIndex)
} else {
    contents.appendContentsOf("// \(keyword)")
}

contents += "\n\n"
contents += "public extension Hotkey {\n"
contents += "\t/// Virtual keycodes defined in `\(sourceFilePath)`\n"
contents += "\tpublic enum Key : UInt32 {\n"

let sourceLines = try! String(contentsOfFile: sourceFilePath).characters.split("\n")

for line in sourceLines where line.startsWith("  kVK_".characters) {
    let parts = line.dropFirst(6).split(" ", allowEmptySlices: false)
    
    let name = String(parts[0])
    let value = String(parts[2].prefix(4))
    
    contents += "\t\tcase \(name) = \(value)\n"
}

contents += "\t}\n}\n"

try! contents.dataUsingEncoding(NSUTF8StringEncoding)!.writeToFile(keyCodesFilePath, options: .DataWritingAtomic)

print("Succesfully generated to file at path \"\(keyCodesFilePath)\"")