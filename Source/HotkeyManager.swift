//
//  File.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 22/07/16.
//  
//

import Foundation
import Carbon

public let HotkeyManager = HotkeyManagerClass.shared

public class HotkeyManagerClass {
	public typealias Handler = (Hotkey) -> Void
	
	let signature = OSType(truncatingBitPattern: NSBundle.mainBundle().bundleIdentifier?.hashValue ?? 0)
	
	var target : EventTargetRef = nil
	
	var handlers : [Hotkey : (EventHotKeyRef, Handler)] = [:]
	let handlerQueue = dispatch_queue_create("\(NSBundle.mainBundle().bundleIdentifier ?? "*").HotkeyHandler", DISPATCH_QUEUE_CONCURRENT)
	
	public static let shared = HotkeyManagerClass()
	
	var eventTap : CFMachPort!
	
	var currentlyRegisteringHandler : Handler? {
		didSet {
			CGEventTapEnable(eventTap, currentlyRegisteringHandler != nil)
		}
	}
	
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
		
		let callback : CGEventTapCallBack = { proxy, type, event, `self` in
			guard type == .KeyDown else { return .passRetained(event) }
			
			let `self` = unsafeBitCast(self, HotkeyManagerClass.self)
			let modifiers = CGEventGetFlags(event).modifiers
			let keycode = UInt32(CGEventGetIntegerValueField(event, .KeyboardEventKeycode))
			let hotkey = Hotkey.Key(rawValue: keycode).map{ modifiers + $0 }
			if self.press(hotkey) {
				return nil
			} else {
				return .passRetained(event)
			}
		}
		
		eventTap = CGEventTapCreate(.CGSessionEventTap, .HeadInsertEventTap, .Default, UInt64(1 << CGEventType.KeyDown.rawValue), callback, unsafeBitCast(self, UnsafeMutablePointer.self))!
		CGEventTapEnable(eventTap, false)
		
		let source = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes)
	}
	
	func press(hotkey: Hotkey?) -> Bool {
		defer { currentlyRegisteringHandler = nil }
		if let hotkey = hotkey, handler = currentlyRegisteringHandler {
			register(hotkey, handler: handler)
			return true
		}
		return false
	}
	
	public func registerByPress(handler: Handler) {
		currentlyRegisteringHandler = handler
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