//
//  Hotkey.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 21/07/16.
//  
//

import Cocoa
import Carbon

public struct Hotkey {
    public struct Modifiers : OptionSetType {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        private var bits : UInt32 {
            return UInt32(rawValue)
        }
        
        public static let Shift = Modifiers(rawValue: shiftKey)
        public static let Control = Modifiers(rawValue: controlKey)
        public static let Option = Modifiers(rawValue: optionKey)
        public static let Command = Modifiers(rawValue: cmdKey)
    }
    
    public struct Key {
        public var val : Int
        
        private var bits : UInt32 {
            return UInt32(val)
        }
    }
    
    private var id : UInt32 {
        return UInt32(modifiers.rawValue << 16) ^ UInt32(key.val)
    }
    
    init(id: UInt32) {
        modifiers = Modifiers(rawValue: Int(id >> 16))
        key = Key(val: Int((id << 16) >> 16))
    }
    
    public init(mods: Modifiers, key: Int) {
        modifiers = mods
        self.key = Key(val: key)
    }
    
    public let modifiers : Modifiers
    public let key : Key
}

public func +(l: Hotkey.Modifiers, r: Int) -> Hotkey {
    return Hotkey(mods: l, key: r)
}

public let HotkeyManager = HotkeyManagerClass.shared

public class HotkeyManagerClass {
    public typealias Handler = (Hotkey) -> Void
    
    private var target : EventTargetRef = nil
    
    private var handlers : [UInt32 : (EventHotKeyRef, Handler)] = [:]
    private let handlerQueue = dispatch_queue_create("handlers", DISPATCH_QUEUE_CONCURRENT)
    
    public static let shared = HotkeyManagerClass()
    
    private init() {
        self.target = GetEventDispatcherTarget()
        
        var keyDownEventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler : EventHandlerUPP = { nextHandler, event, handler in
            let `self` = unsafeBitCast(handler, HotkeyManagerClass.self)
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, sizeof(EventHotKeyID), nil, &hotkeyID)
            
            if let (_, handler) = self.handlers[hotkeyID.id] {
                dispatch_async(self.handlerQueue) { handler(Hotkey(id: hotkeyID.id)) }
                return 0
            } else {
                return CallNextEventHandler(nextHandler, event)
            }
        }
        
        InstallEventHandler(target, handler, 1, &keyDownEventType, unsafeBitCast(self, UnsafeMutablePointer.self), nil)
    }
    
    public func register(hotkey: Hotkey, handler: Handler) {
        unregister(hotkey)
        
        var ref : EventHotKeyRef = nil
        let id = EventHotKeyID(signature: 0, id: hotkey.id)
        RegisterEventHotKey(hotkey.key.bits, hotkey.modifiers.bits, id, target, 0, &ref)
        handlers[hotkey.id] = (ref, handler)
    }
    
    public func unregister(hotkey: Hotkey) {
        if let (ref, _) = handlers[hotkey.id] {
            UnregisterEventHotKey(ref)
            handlers[hotkey.id] = nil
        }
    }
}


