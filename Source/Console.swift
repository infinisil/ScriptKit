//
//  Console.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 21/07/16.
//  
//

import Foundation

class Console {
    let task : NSTask
    let inHandle : NSFileHandle
    
    static let sharedBash : Console = {
        do {
            return try Console(shell: "bash")
        } catch {
            fatalError("Couldn't find bash with /usr/bin/which, standard location should be /bin/bash, error: \(error)")
        }
    }()
    
    enum WhichError : ErrorType {
        case Error(standardError: String)
    }
    
    static func which(command: String) throws -> String? {
        let task = NSTask()
        let (o, e) = (NSPipe(), NSPipe())
        task.standardInput = NSPipe()
        task.standardOutput = o
        task.standardError = e
        task.environment = ["PATH" : "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
        task.launchPath = "/usr/bin/which"
        task.arguments = [command]
        
        task.launch()
        
        task.waitUntilExit()
        
        if let error = String(data: e.fileHandleForReading.availableData, encoding: NSUTF8StringEncoding) where !error.isEmpty {
            throw WhichError.Error(standardError: error)
        }
        
        if let out = String(data: o.fileHandleForReading.availableData, encoding: NSUTF8StringEncoding) where !out.isEmpty {
            return out.stringByTrimmingCharactersInSet(.newlineCharacterSet())
        }
        
        return nil
    }
    
    init(shell: String = "bash") throws {
        task = NSTask()
        
        guard let path = try Console.which(shell) else {
            fatalError("Shell \"\(shell)\" not found with /usr/bin/which")
        }
        
        task.launchPath = path
        
        let input = NSPipe()
        task.standardInput = input
        inHandle = input.fileHandleForWriting
        
        let output = NSPipe()
        task.standardOutput = output
        output.fileHandleForReading.readabilityHandler = { h in
            if let string = String(data: h.availableData, encoding: NSUTF8StringEncoding) {
                print(string, terminator: "")
            }
        }
        
        task.launch()
    }
    
    var running : Bool {
        return task.running
    }
    
    let newLine = "\n".dataUsingEncoding(NSUTF8StringEncoding)!
    
    func input(line: String) {
        if let data = line.dataUsingEncoding(NSUTF8StringEncoding) {
            inHandle.writeData(data)
            inHandle.writeData(newLine)
        } else {
            print("Couldn't write")
        }
    }
    
    func wait(max: NSTimeInterval = Double.infinity) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(max * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.task.terminate()
        }
        task.waitUntilExit()
    }
}
