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
open class HotkeyManagerClass {
	/// An action to be performed with an occuring event
	public enum EventAction {
		/// Propagate the event to the next handler. The event can be received by other applications
		case propagate
		/// Discard the event. The event cannot be received by other applications
		case discard
	}
	
	/// An event handler for when a hotkey was pressed. Returns whether the event should be discarded or propagated.
	/// - Parameter hotkey: The pressed hotkey
	/// - Returns: The desired action that should be performed with the event
	public typealias Handler = (_ hotkey: Hotkey) -> EventAction
	
	/// A signutare for the hotkey registering generated using the bundleIdentifiers hash
	let signature = OSType(truncatingBitPattern: Bundle.main.bundleIdentifier?.hashValue ?? 0)
	
	var target : EventTargetRef? = nil
	
	/// All registered hotkeys and their corresponding references (which enables unregistering them) and handlers
	var handlers : [Hotkey : (EventHotKeyRef, Handler)] = [:]
	
	/// The shared instance of this class. Equivalent to `HotkeyManager` which is preferred
	open static let shared = HotkeyManagerClass()
	
	var eventTap : CFMachPort!
	
	/// The handler that should be registered on the next key press event and associated with it
	var currentlyRegisteringHandler : Handler? {
		didSet {
			CGEvent.tapEnable(tap: eventTap, enable: currentlyRegisteringHandler != nil)
		}
	}
	
	fileprivate init() {
		self.target = GetEventDispatcherTarget()
		
		var keyDownEventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
		
		let handler : EventHandlerUPP = { nextHandler, event, `self` in
			let `self` = unsafeBitCast(`self`, to: HotkeyManagerClass.self)
			var hotkeyID = EventHotKeyID()
			GetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
			
			if let hotkey = Hotkey(id: hotkeyID.id), let (_, handler) = self.handlers[hotkey] , hotkeyID.signature == self.signature {
				switch handler(hotkey) {
				case .discard: return 0
				case .propagate: return CallNextEventHandler(nextHandler, event)
				}
			} else {
				return CallNextEventHandler(nextHandler, event)
			}
		}
		
		InstallEventHandler(target, handler, 1, &keyDownEventType, unsafeBitCast(self, to: UnsafeMutablePointer.self), nil)
		
		let callback : CGEventTapCallBack = { proxy, type, event, `self` in
			guard type == .keyDown else { return .passRetained(event) }
			
			let `self` = unsafeBitCast(self, to: HotkeyManagerClass.self)
			let modifiers = event.flags.modifiers
			let keycode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
			let hotkey = Hotkey.Key(rawValue: keycode).map{ modifiers + $0 }
			if self.press(hotkey: hotkey) {
				return nil
			} else {
				return .passRetained(event)
			}
		}

		guard let eventTap = CGEvent.tapCreate(
			tap: .cgSessionEventTap,
			place: .headInsertEventTap,
			options: .defaultTap,
			eventsOfInterest: UInt64(1 << CGEventType.keyDown.rawValue),
			callback: callback,
			userInfo: unsafeBitCast(self, to: UnsafeMutablePointer.self))
		else {
			fatalError("Key up/down events cannot be received unless the application is either run as root or is added in System Preferences > Security & Privacy > Privacy > Accessibility")
		}
		
		CGEvent.tapEnable(tap: eventTap, enable: false)
		
		let source = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
	}
	
	func press(hotkey: Hotkey?) -> Bool {
		defer { currentlyRegisteringHandler = nil }
		if let hotkey = hotkey, let handler = currentlyRegisteringHandler {
			register(hotkey: hotkey, handler: handler)
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
	open func registerByPress(handler: @escaping Handler) {
		currentlyRegisteringHandler = handler
	}
	
	/**
	Registers the given hotkey with the given handler. Everytime this hotkey combination is pressed, the handler gets called. If another handler wes registered on this hotkey, it gets unregistered and the new handler gets registered instead.
	*/
	open func register(hotkey: Hotkey, handler: @escaping Handler) {
		unregister(hotkey: hotkey)
		
		let id = EventHotKeyID(signature: signature, id: hotkey.id)
		var ref : EventHotKeyRef? = nil
		RegisterEventHotKey(hotkey.key.rawValue, hotkey.modifiers.rawValue, id, target, 0, &ref)
		
		handlers[hotkey] = (ref!, handler)
	}
	
	/**
	Unregisters the given hotkey if it was registered, otherwise does nothing.
	*/
	open func unregister(hotkey: Hotkey) {
		if let (ref, _) = handlers.removeValue(forKey: hotkey) {
			UnregisterEventHotKey(ref)
		}
	}
}
