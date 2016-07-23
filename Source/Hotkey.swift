//
//  Hotkey.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 21/07/16.
//  
//

import Cocoa
import Carbon

/**
Represents a hotkey, composed of a combination of modifiers and a single key

You can create this struct be either using the initializer or the combining operators:

	Hotkey(modifiers: [.Command, .Shift], key: .ANSI_A)
	Hotkey(modifiers: .Control, key: .F5)
	[.Control, .Option] - .ANSI_1
	.Shift + .ANSI_P
*/
public struct Hotkey : CustomStringConvertible, Hashable {
	public let modifiers : Modifiers
	public let key : Key
	
	public var description: String {
		if modifiers.isEmpty {
			return "\(key)"
		} else {
			return "\(modifiers) + \(key)"
		}
	}
	
	public var hashValue: Int {
		return Int(id)
	}
	
	/// Initializes a new hotkey with the specified modifier and key
	public init(modifiers: Modifiers, key: Key) {
		self.modifiers = modifiers
		self.key = key
	}
}

extension Hotkey {
	/**
	A set of key modifiers. Available modifiers are :
	 - Control
	 - Shift
	 - Option
	 - Command
	
	The bit representation is the same as those defined in `Carbon.HIToolbox.Events.h` (`controlKey`, etc.)
	*/
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
	/// `Hotkey.Modifiers` equivalent of this `GCEventFlags`
	/// - Note: Even though `CGEventFlags` is declared as an enum, it should actually be an `OptionSetType` and can therefore represent combination of the declared cases
	var modifiers : Hotkey.Modifiers {
		var mods : Hotkey.Modifiers = []
		if CGEventFlags.MaskControl.rawValue & rawValue > 0 { mods.unionInPlace(.Control) }
		if CGEventFlags.MaskShift.rawValue & rawValue > 0 { mods.unionInPlace(.Shift) }
		if CGEventFlags.MaskAlternate.rawValue & rawValue > 0 { mods.unionInPlace(.Option) }
		if CGEventFlags.MaskCommand.rawValue & rawValue > 0 { mods.unionInPlace(.Command) }
		return mods
	}
}

public func ==(lhs: Hotkey, rhs: Hotkey) -> Bool {
	return lhs.modifiers == rhs.modifiers && lhs.key == rhs.key
}

extension Hotkey {
	/// An id representing this hotkey
	/// - Note: Since modifiers is always only using 16 bytes max and the key codes have a range of 0..<256, this representation is unique
    var id : UInt32 {
        return modifiers.rawValue << 16 | key.rawValue
    }
	
	/// Initializes a hotkey with the given id
	/// - Returns: A hotkey or nil if the least significant two bytes don't represent a valid key code
    init?(id: UInt32) {
        modifiers = Modifiers(rawValue: id >> 16)
        if let key = Key(rawValue: id & 0xFFFF) {
            self.key = key
        } else {
            return nil
        }
    }
}

// Creates a new hotkey with the given modifiers and key. Equivalent to using the `-` operator
public func +(modifiers: Hotkey.Modifiers, key: Hotkey.Key) -> Hotkey {
    return Hotkey(modifiers: modifiers, key: key)
}

// Creates a new hotkey with the given modifiers and key. Equivalent to using the `+` operator
public func -(modifiers: Hotkey.Modifiers, key: Hotkey.Key) -> Hotkey {
    return Hotkey(modifiers: modifiers, key: key)
}

