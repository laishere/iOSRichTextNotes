//
//  Logger.swift
//  Notes
//
//  Created by laishere on 2023/11/20.
//

import Foundation

class Logger {
    private let name: String
    
    var tag: String {
        return "\(name)@\(threadName())"
    }
    
    private func threadName() -> String {
        if Thread.isMainThread {
            return "main"
        }
        let name = Thread.current.name ?? ""
        return name.isEmpty ? "non-main" : name
    }
    
    init(type: AnyClass) {
        name = String(describing: type)
    }
    
    func debug(_ msg: String) {
        NSLog("[\(tag)] [DEBUG]: \(msg)")
    }
    
    func info(_ msg: String) {
        NSLog("[\(tag)] [INFO]: \(msg)")
    }
    
    func warn(_ msg: String, error: Error? = nil) {
        NSLog("[\(tag)] [WARN]: \(msg) \(errorMessage(error))")
    }
    
    func error(_ msg: String, error: Error? = nil) {
        NSLog("[\(tag)] [ERROR]: \(msg) \(errorMessage(error))")
    }
    
    func error(_ error: Error? = nil) {
        NSLog("[\(tag)] [ERROR]: \(errorMessage(error))")
    }
    
    private func errorMessage(_ error: Error?) -> String {
        return error == nil ? "" : String(describing: error!)
    }
}
