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
		precondition(!modifiers.isEmpty, "Cannot create hotkey without any modifiers. Key was \(key)")
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

public let HotkeyManager = HotkeyManagerClass.shared

public class HotkeyManagerClass {
    public typealias Handler = (Hotkey) -> Void
    
    let signature = OSType(truncatingBitPattern: NSBundle.mainBundle().bundleIdentifier?.hashValue ?? 0)
    
    var target : EventTargetRef = nil
    
    var handlers : [Hotkey : (EventHotKeyRef, Handler)] = [:]
    let handlerQueue = dispatch_queue_create("\(NSBundle.mainBundle().bundleIdentifier ?? "*").HotkeyHandler", DISPATCH_QUEUE_CONCURRENT)
    
    public static let shared = HotkeyManagerClass()
    
    private init() {
        self.target = GetEventDispatcherTarget()
        
        var keyDownEventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler : EventHandlerUPP = { nextHandler, event, `self` in
            let `self` = unsafeBitCast(`self`, HotkeyManagerClass.self)
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, sizeof(EventHotKeyID), nil, &hotkeyID)
            
            if let hotkey = Hotkey(id: hotkeyID.id), (_, handler) = self.handlers[hotkey] where hotkeyID.signature == self.signature {
                dispatch_async(self.handlerQueue) {
                    handler(hotkey)
                }
                return 0
            } else {
                return CallNextEventHandler(nextHandler, event)
            }
        }
        
        InstallEventHandler(target, handler, 1, &keyDownEventType, unsafeBitCast(self, UnsafeMutablePointer.self), nil)
    }
    
    public func register(hotkey: Hotkey, handler: Handler) {
        unregister(hotkey)
        
		let id = EventHotKeyID(signature: signature, id: hotkey.id)
        var ref : EventHotKeyRef = nil
        RegisterEventHotKey(hotkey.key.rawValue, hotkey.modifiers.rawValue, id, target, 0, &ref)
        handlers[hotkey] = (ref, handler)
    }
    
    public func unregister(hotkey: Hotkey) {
		if let (ref, _) = handlers.removeValueForKey(hotkey) {
			UnregisterEventHotKey(ref)
		}
    }
}


