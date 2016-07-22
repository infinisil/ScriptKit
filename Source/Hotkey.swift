//
//  Hotkey.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 21/07/16.
//  
//

import Cocoa
import Carbon

extension Hotkey {
    public struct Modifiers : OptionSetType, CustomStringConvertible, Equatable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
		public static let Control = Modifiers(rawValue: UInt32(controlKey))
        public static let Shift = Modifiers(rawValue: UInt32(shiftKey))
        public static let Option = Modifiers(rawValue: UInt32(optionKey))
        public static let Command = Modifiers(rawValue: UInt32(cmdKey))
		
		public var description: String {
			var strings : [String] = []

			func add(modifier: Modifiers, _ description: String) {
				if contains(modifier) { strings.append(description) }
			}
			
			add(.Control, "Control")
			add(.Shift, "Shift")
			add(.Option, "Option")
			add(.Command, "Command")
			
			return "[\(strings.joinWithSeparator(", "))]"
		}
    }
}

extension CGEventFlags {
	var modifiers : Hotkey.Modifiers {
		var mods : Hotkey.Modifiers = []
		if CGEventFlags.MaskControl.rawValue & rawValue > 0 { mods.unionInPlace(.Control) }
		if CGEventFlags.MaskShift.rawValue & rawValue > 0 { mods.unionInPlace(.Shift) }
		if CGEventFlags.MaskAlternate.rawValue & rawValue > 0 { mods.unionInPlace(.Option) }
		if CGEventFlags.MaskCommand.rawValue & rawValue > 0 { mods.unionInPlace(.Command) }
		return mods
	}
}

public struct Hotkey : CustomStringConvertible, Hashable {
    public let modifiers : Modifiers
    public let key : Key
	
	public var description: String {
		return "\(modifiers) + \(key)"
	}
	
	public var hashValue: Int {
		return Int(id)
	}
	
    public init(modifiers: Modifiers, key: Key) {
        self.modifiers = modifiers
        self.key = key
    }
}

public func ==(lhs: Hotkey, rhs: Hotkey) -> Bool {
	return lhs.modifiers == rhs.modifiers && lhs.key == rhs.key
}

extension Hotkey {
    var id : UInt32 {
        return modifiers.rawValue << 16 | key.rawValue
    }
    
    init?(id: UInt32) {
        modifiers = Modifiers(rawValue: id >> 16)
        if let key = Key(rawValue: id & 0xFFFF) {
            self.key = key
        } else {
            return nil
        }
    }
}

public func +(modifiers: Hotkey.Modifiers, key: Hotkey.Key) -> Hotkey {
    return Hotkey(modifiers: modifiers, key: key)
}

public func -(modifiers: Hotkey.Modifiers, key: Hotkey.Key) -> Hotkey {
    return Hotkey(modifiers: modifiers, key: key)
}

