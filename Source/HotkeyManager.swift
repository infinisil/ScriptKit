//
//  File.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 22/07/16.
//  
//

import Foundation
import Carbon

/// A convenience property to access the shared instance of `HotkeyManagerClass`. Equivalent to `HotkeyManagerClass.shared`
public let HotkeyManager = HotkeyManagerClass.shared


/**
Manages the registering of hotkeys. There needs to be a running event loop for the registering to work.
*/
public class HotkeyManagerClass {
	/// An action to be performed with an occuring event
	public enum EventAction {
		/// Propagate the event to the next handler. The event can be received by other applications
		case Propagate
		/// Discard the event. The event cannot be received by other applications
		case Discard
	}
	
	/// An event handler for when a hotkey was pressed. Returns whether the event should be discarded or propagated.
	/// - Parameter hotkey: The pressed hotkey
	/// - Returns: The desired action that should be performed with the event
	public typealias Handler = (hotkey: Hotkey) -> EventAction
	
	/// A signutare for the hotkey registering generated using the bundleIdentifiers hash
	let signature = OSType(truncatingBitPattern: NSBundle.mainBundle().bundleIdentifier?.hashValue ?? 0)
	
	var target : EventTargetRef = nil
	
	/// All registered hotkeys and their corresponding references (which enables unregistering them) and handlers
	var handlers : [Hotkey : (EventHotKeyRef, Handler)] = [:]
	
	/// The shared instance of this class. Equivalent to `HotkeyManager` which is preferred
	public static let shared = HotkeyManagerClass()
	
	var eventTap : CFMachPort!
	
	/// The handler that should be registered on the next key press event and associated with it
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
				switch handler(hotkey: hotkey) {
				case .Discard: return 0
				case .Propagate: return CallNextEventHandler(nextHandler, event)
				}
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
	
	/**
	Registers a new handler with the next hotkey combination pressed.
	
	Example:
	
	-		registerByPress{
				print($0)
				return .Discard
			}
	- [User presses `Cmd-Shift-0`] (handler gets registered for this hotkey)
	- [User presses `Cmd-Shift-0`] (handler gets called) Output: `"[Command, Shift] - 0"`
	*/
	public func registerByPress(handler: Handler) {
		currentlyRegisteringHandler = handler
	}
	
	/**
	Registers the given hotkey with the given handler. Everytime this hotkey combination is pressed, the handler gets called. If another handler wes registered on this hotkey, it gets unregistered and the new handler gets registered instead.
	*/
	public func register(hotkey: Hotkey, handler: Handler) {
		unregister(hotkey)
		
		let id = EventHotKeyID(signature: signature, id: hotkey.id)
		var ref : EventHotKeyRef = nil
		RegisterEventHotKey(hotkey.key.rawValue, hotkey.modifiers.rawValue, id, target, 0, &ref)
		handlers[hotkey] = (ref, handler)
	}
	
	/**
	Unregisters the given hotkey if it was registered, otherwise does nothing.
	*/
	public func unregister(hotkey: Hotkey) {
		if let (ref, _) = handlers.removeValueForKey(hotkey) {
			UnregisterEventHotKey(ref)
		}
	}
}