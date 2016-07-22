//
//  main.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 21/07/16.
//  
//

import ScriptKit
import Carbon

final class MyScript : Script {
    let swiftREPL = try! Console(shell: "swift")
    
    func setUp(manager: Manager<MyScript>) {
        manager.terminationDelay = 5
        
        HotkeyManager.register([.Command, .Shift] + .ANSI_0) { hotkey in
            manager.invokeMain(context: "\(hotkey) was pressed!")
        }
    }
    
    func main(manager: Manager<MyScript>, index: Int32, group: dispatch_group_t, context: String?) {
        if index == 0 {
            swiftREPL.input("let x = 10; print(x * 2)")
            NSLog("First start of the script")
        }
        
        if let message = context {
            NSLog(message)
        }
        
        NSLog("Starting work on \(index). invocation")
        NSThread.sleepForTimeInterval(5)
        NSLog("Finished work on \(index). invocation")
        
        
    }
    
    func tearDown(manager: Manager<MyScript>) {
        NSLog("Finished")
    }
}

MyScript.run()