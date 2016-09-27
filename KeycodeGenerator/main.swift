//
//  main.swift
//  KeycodeGenerator
//
//  Created by Silvan Mosberger on 22/07/16.
//
//

import Foundation
import Carbon

let relativeKeyCodesFilePath = "/Source/KeyCodes.swift"
let sourceFilePath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/Events.h"
let keyword = "DOIT" // Everthing before the first appearance of this keyword won't be overridden

let keyCodesFilePath = CommandLine.arguments[1] + relativeKeyCodesFilePath
var contents = try! String(contentsOfFile: keyCodesFilePath)

if let range = contents.range(of: keyword) {
    contents.removeSubrange(range.upperBound..<contents.endIndex)
} else {
    contents.append("// \(keyword)")
}

contents += "\n\n"
contents += "public extension Hotkey {\n"
contents += "\t/// Virtual keycodes defined in [`Carbon.HIToolbox.Events.h`](\(sourceFilePath))\n"
contents += "\tpublic enum Key : UInt32, CustomStringConvertible, Equatable {\n"

let sourceLines = try! String(contentsOfFile: sourceFilePath).characters.split(separator: "\n")
let relevantLines = sourceLines.filter{ $0.starts(with: "  kVK_".characters) }
let keys : [(String, String)] = relevantLines.map{ line in
	let parts = line.dropFirst(6).split(separator: " ", omittingEmptySubsequences: true)
	
	let name = String(parts[0])
	let value = String(parts[2].prefix(4))
	
	return (name, value)
}

for (name, value) in keys {
    contents += "\t\tcase \(name) = \(value)\n"
}

contents += "\n\n\t\tpublic var description : String {\n"
contents += "\t\t\tswitch self {\n"

for (name, _) in keys {
	let start = name.characters.index(of: "_").map{ name.index(after: $0) } ?? name.startIndex
	contents += "\t\t\tcase .\(name): return \"\(name.substring(from: start))\"\n"
}

contents += "\t\t\t}\n\t\t}\n\n"

contents += "\t}\n}\n"

try! contents.data(using: .utf8)!.write(to: URL(fileURLWithPath: keyCodesFilePath), options: .atomic)

print("Succesfully generated to file at path \"\(keyCodesFilePath)\"")
