# ScriptKit - Convenient Scripts in Swift (WIP)

This framework stems from not wanting to get into complicated stuff when you just want to write a short script in Swift. By script I am not referring to a single interpreted file, but rather a small application that does useful things, mostly without UI.

## Installation

### Manual

- Download the source code of the [latest release](https://github.com/Infinisil/ScriptKit/archive/master.zip)
- Copy all files in the `/Source` directory into your macOS project

### Carthage

- Add this line to your Cartfile:

		github "infinisil/ScriptKit"

- Run `carthage update --platform OSX`
- Add the build framework to your project by dragging it from Finder into the "Embedded Binaries" section under the "General" section of your project settings

### Script protocol (about done, but I got some ideas)

This is the part of this framework that's mostly done. It handles things like restarts of the script, waiting for a certain amount of time before terminating and the Apps run loop. To use it for your script:

 1. Create a new OSX application project
 2. Delete every file except `Info.plist`
 3. In the `Info.plist`, set the `Application is background only` key to `YES`
 4. Add a new Swift file called `main.swift` (If Xcode asks, you don't need a bridging header)
 5. Implement a class conforming to `Script`. Example:

```swift
import ScriptKit

final class MyScript : Script {
	func setUp(manager: Manager<MyScript>) {
		manager.terminationDelay = 5

		manager.metaQueue.asyncAfter(deadline: .now() + 3) {
			manager.invokeMain(context: "This is three seconds later")
		}
	}

	func main(manager: Manager<MyScript>, index: Int32, group: DispatchGroup, context: String?) {
		if index == 0 {
			NSLog("First start of the script")
		}

		if let message = context {
			NSLog(message)
		}

		NSLog("Starting work on \(index). invocation")
		Thread.sleep(forTimeInterval: 5)
		NSLog("Finished work on \(index). invocation")
	}

	func tearDown(manager: Manager<MyScript>) {
		NSLog("Finished")
	}
}

MyScript.run()
```

If you run this application and double-click again after 10 seconds, this is the output of Console:

```
02:29:12 Example: First start of the script
02:29:12 Example: Starting work on 0. invocation
02:29:16 Example: This is three seconds later
02:29:16 Example: Starting work on 1. invocation
02:29:17 Example: Finished work on 0. invocation
02:29:21 Example: Finished work on 1. invocation
02:29:22 Example: Starting work on 2. invocation
02:29:27 Example: Finished work on 2. invocation
02:29:33 Example: Finished
```

The documentation describes pretty well what everything does.

### Hotkey class (about done, but have some ideas)

The `Hotkey` class is a very simple way of registering a new global Hotkey and execute some code when it gets triggered. It is decently documented. It's useable like this:

```swift
HotkeyManager.register([.Command, .Shift] + .ANSI_0)) { hotkey in
	print("⌘⇧-0 was pressed!")
	return .Discard // Don't let any other app get this key event
}
```

This has effect as long as the application is running (unless you use the `unregister` method).

You can also register a hotkey handler by using the next key event:

```swift
HotkeyManager.registerByPress { hotkey in
	print("\(hotkey) was pressed!")
	return .propagate
}
```

### Console (not done at all, not public for now)

Console is a class representing a running console. The standard initializer uses `bash` (should probably be changed to `$SHELL`), but in theory it's possible to use any shell/command that supports interaction (`fish` doesn't want to work for some reason though). It's for example possible to use the Swift REPL (Swiftception):

```swift
let swiftREPL = try! Console(shell: "swift")
swiftREPL.input("let x = 10; print(x * 2)")
```

### File utilities (so not done it's not even worth mentioning, also not public)

## Ideas and stuff to do

- Xcode template for a script that starts at login, supporting the `Script` protocol
- Convenient `NSStatusItem` support (the little icon it the menu bar)
- Hotkey registering cancellation, more flexibility
- The hotkey part should really be it's own project
- Add tests
