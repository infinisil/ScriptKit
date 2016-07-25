//
//  Script.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 08/06/16.
//
//

import Cocoa

/**
Protocol for the functionality of a script

Implement this protocol and call an instances `run` method to start the script application.
*/
public protocol Script : class {
	
	/// An arbitrary type that you can use to pass a context value to the main function by calling the `manager`s `invokeMain(context:)` function.
	associatedtype Context
	
	/// Use the initializer to set up the variables in your script.
	init()
	
	/// Called once when the script starts the first time (after init). Use this to configure the manager or handle any other initialization work. This method shouldn't take a long time to finish because it prevents the main method from starting.
	/// - Parameter manager: The script manager for configuration
	func setUp(manager: Manager<Self>)
	
	/**
	Main method of the script.

	This method is called every time this application gets started. The index indicates what number of start this invocation is. This means that if the index is `0`, the script starts the first time.

	This invocation of the script is considered 'done', when all of these conditions are met
		
	- This method has returned.
	- All blocks associated with the given dispatch group have finished.
	- Time equal to the managers `terminationDelay` has passed after the fulfillment of the above condition. You can configure this delay in this method.

	The given dispatch group is not associated with any blocks when this method gets called, it is merely a convenience argument for asynchronous functions. Example:
	```
	group.enter()
	doAsynchronousWork(handler: {
		group.leave()
	})
	```
	
	If the `invokeMain(context:)` method was called on the manager, the given context will be passed as is to this method.
	
	You can terminate the script at any point by calling the managers `terminate` function. This will immediately set the `manager`s `cancelled` property to true.

	- Parameters:
		- manager:	The script manager for configuration.
		- index:	The starting index of this invocation
		- group:	The dispatch group for additional work
		- context:	The context if called with `invokeMain`, nil otherwise
	*/
	func main(manager: Manager<Self>, index: Int32, group: dispatch_group_t, context: Context?)
	
	/// Called right before the script terminates. Use this to clean up. This method shouldn't take a long time to finish.
	/// - Parameter manager: The script manager for configuration
	func tearDown(manager: Manager<Self>)
}

let nsecPerSec = Double(NSEC_PER_SEC)

final public class Manager<S: Script>: NSObject, NSApplicationDelegate {
	
	/// Used to do all the script work
    let workQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
	
	/// Used for unimportant meta stuff
	public let metaQueue = dispatch_queue_create("MetaQueue", DISPATCH_QUEUE_CONCURRENT)
	
	/// When this group is done, the script finishes
	let mainGroup = dispatch_group_create()
	
	/// Starting index
	var index : Int32 = -1
	
	/// The duration of inactivity needed for the script to terminate.
	public var terminationDelay: NSTimeInterval = 0
	var script : S!
	
	override init() {
		self.script = S()
		super.init()
	}

	/// Do not call this yourself, in the future this should not be public
    public func applicationDidFinishLaunching(notification: NSNotification) {
        script.setUp(self)
        work()

        dispatch_group_notify(mainGroup, self.metaQueue) {
            self.terminate()
        }
    }
	
	/// Do not call this yourself, in the future this should not be public
	public func applicationShouldHandleReopen(sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		work()
		return false
	}
	
	/// Manually start another invocation of the main method.
    public func invokeMain(context context: S.Context? = nil) {
		work(context)
	}
	
	func work(context: S.Context? = nil) {
		let index = OSAtomicIncrement32(&self.index)
		let group = dispatch_group_create()
		
        dispatch_group_enter(mainGroup)
        
		
		dispatch_async(workQueue) {
			
			// Delegate this to the workQueue, since it might take a while.
			self.script.main(self, index: index, group: group, context: context)
			
			// Condition 1 (main returns), check
			
			let delay = self.terminationDelay
			
            dispatch_group_notify(group, self.metaQueue) {
				// Condition 2 (group done), check
				
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * nsecPerSec)), self.metaQueue) {
					// Condition 3 (delay), check
					
                    dispatch_group_leave(self.mainGroup)
				}
			}
		}
	}
	
	/// This property is immediately set to true when the `terminate` method has been called. You can repeatedly check this to act appropriately
	internal(set) public var cancelled = false
	
	/// A custom handler called when the `cancelled` property has been set from `false` to `true`. Default is nil
	public var cancellationHandler : (() -> ())?
	
	
	/// Terminate the script unconditionally after a certain duration. Useful when errors occur that can't be recovered. Default is 0 (instantly).
	public func terminate(after delay: NSTimeInterval = 0) {
		func terminateNow() {
			self.script.tearDown(self)
			self.script = nil
			NSApp.terminate(self)
		}
		
		if delay <= 0 {
			terminateNow()
		} else {
			cancelled = true
			cancellationHandler?()
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * nsecPerSec)), metaQueue, terminateNow)
		}
	}
	
	/// Do not call this yourself, in the future this should not be public
	public func applicationShouldTerminate(sender: NSApplication) -> NSApplicationTerminateReply {
		return .TerminateNow
	}
}

public extension Script {
	
	/// Run the script application. This method never returns because `NSApplication` consumes the main thread upon terminating.
	@noreturn static func run() {
		let app = NSApplication.sharedApplication()
		let manager : Manager<Self> = Manager()
		app.delegate = manager
		app.performSelectorOnMainThread(#selector(NSApplication.run), withObject: nil, waitUntilDone: true)
		
		// The application seems to quit the main thread when terminating (even when just calling `stop`), so we might as well make this function `@noreturn`.
		fatalError("Code made it past terminate wut")
	}
}



