//
//  Console.swift
//  ScriptKit
//
//  Created by Silvan Mosberger on 21/07/16.
//  
//

import Foundation

class Console {
    let task : Process
    let inHandle : FileHandle
    
    static let sharedBash : Console = {
        do {
            return try Console(shell: "bash")
        } catch {
            fatalError("Couldn't find bash with /usr/bin/which, standard location should be /bin/bash, error: \(error)")
        }
    }()
    
    enum WhichError : Error {
        case error(standardError: String)
    }
    
    static func which(_ command: String) throws -> String? {
        let task = Process()
        let (o, e) = (Pipe(), Pipe())
        task.standardInput = Pipe()
        task.standardOutput = o
        task.standardError = e
        task.environment = ["PATH" : "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
        task.launchPath = "/usr/bin/which"
        task.arguments = [command]
        
        task.launch()
        
        task.waitUntilExit()
        
        if let error = String(data: e.fileHandleForReading.availableData, encoding: .utf8) , !error.isEmpty {
            throw WhichError.error(standardError: error)
        }
        
        if let out = String(data: o.fileHandleForReading.availableData, encoding: .utf8) , !out.isEmpty {
            return out.trimmingCharacters(in: .newlines)
        }
        
        return nil
    }
    
    init(shell: String = "bash") throws {
        task = Process()
        
        guard let path = try Console.which(shell) else {
            fatalError("Shell \"\(shell)\" not found with /usr/bin/which")
        }
        
        task.launchPath = path
        
        let input = Pipe()
        task.standardInput = input
        inHandle = input.fileHandleForWriting
        
        let output = Pipe()
        task.standardOutput = output
        output.fileHandleForReading.readabilityHandler = { h in
            if let string = String(data: h.availableData, encoding: .utf8) {
                print(string, terminator: "")
            }
        }
        
        task.launch()
    }
    
    var running : Bool {
        return task.isRunning
    }
    
    let newLine = "\n".data(using: .utf8)!
    
    func input(_ line: String) {
        if let data = line.data(using: .utf8) {
            inHandle.write(data)
            inHandle.write(newLine)
        } else {
            print("Couldn't write")
        }
    }
    
    func wait(_ max: TimeInterval = Double.infinity) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + max) {
            self.task.terminate()
        }
        task.waitUntilExit()
    }
}
