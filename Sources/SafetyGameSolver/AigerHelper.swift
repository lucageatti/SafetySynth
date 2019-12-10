import CAiger
import CAigerHelper

import Foundation


func aiger_create_and(_ aig: UnsafeMutablePointer<aiger>, lhs: UInt32, rhs: UInt32) -> UInt32 {
    if lhs == 0 || rhs == 0 {
        return 0;
    } else if lhs == 1 {
        return rhs
    } else if rhs == 1 {
        return lhs
    } else {
        assert(lhs > 1 && rhs > 1)
        let and_lit = aiger_next_lit(aig)
        aiger_add_and(aig, and_lit, lhs, rhs)
        return and_lit
    }
}

func aiger_copy(_ aig: UnsafeMutablePointer<aiger>) -> UnsafeMutablePointer<aiger>? {
    let copy = aiger_init()
    
    // inputs
    var symbolPtr = aig.pointee.inputs
    for _ in 0..<aig.pointee.num_inputs {
        let symbol = symbolPtr!.pointee
        symbolPtr = symbolPtr?.successor()
        aiger_add_input(copy, symbol.lit, symbol.name)
    }
    
    // latches
    symbolPtr = aig.pointee.latches
    for _ in 0..<aig.pointee.num_latches {
        let symbol = symbolPtr!.pointee
        symbolPtr = symbolPtr?.successor()
        aiger_add_latch(copy, symbol.lit, symbol.next, symbol.name)
        aiger_add_reset(copy, symbol.lit, symbol.reset)
    }
    
    // outputs
    symbolPtr = aig.pointee.outputs
    for _ in 0..<aig.pointee.num_outputs {
        let symbol = symbolPtr!.pointee
        symbolPtr = symbolPtr?.successor()
        aiger_add_output(copy, symbol.lit, symbol.name)
    }
    
    // ands
    var andPtr = aig.pointee.ands
    for _ in 0..<aig.pointee.num_ands {
        let and = andPtr!.pointee
        andPtr = andPtr?.successor()
        aiger_add_and(copy, and.lhs, and.rhs0, and.rhs1)
    }
    
    return copy
}

public func minimizeWithABC(_ aig: UnsafeMutablePointer<aiger>) -> UnsafeMutablePointer<aiger>? {
    let minimized = aiger_init()
    
    let inputFileName: String = ProcessInfo.processInfo.globallyUniqueString + ".aig"
    let outputFileName: String = ProcessInfo.processInfo.globallyUniqueString + ".aig"
    let tempDirURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
    let inputFileURL = tempDirURL.appendingPathComponent(inputFileName)!
    let outputFileURL = tempDirURL.appendingPathComponent(outputFileName)!
    let inputPath = inputFileURL.path
    let outputPath = outputFileURL.path
    
    if aiger_open_and_write_to_file(aig, inputPath) == 0 {
        return nil
    }
    
    var abcCommand = "read \(inputPath); strash; refactor -zl; rewrite -zl;"
    if aig.pointee.num_ands < 1000000 {
        abcCommand += " strash; refactor -zl; rewrite -zl;"
    }
    if aig.pointee.num_ands < 200000 {
        abcCommand += " strash; refactor -zl; rewrite -zl;"
    }
    if aig.pointee.num_ands < 200000 {
        abcCommand += " dfraig; rewrite -zl; dfraig;"
    }
    abcCommand += " write \(outputPath);"
  
    // Execute command "abc -q abcCommand"
    let task = Process()
    // determine `abc` binary, either local or system
    var env = ProcessInfo.processInfo.environment
    var path = env["PATH"]! as String
    path = "./Tools/:" + path
    env["PATH"] = path
    task.environment = env
    task.launchPath = "/usr/bin/env"
    task.arguments = ["abc", "-q", abcCommand]
    task.standardOutput = FileHandle.standardError
    task.launch()
    task.waitUntilExit()
    assert(task.terminationStatus == 0)
    
    if aiger_open_and_read_from_file(minimized, outputPath) != nil {
        return nil
    }
    
    defer {
        do {
            try FileManager.default.removeItem(at: inputFileURL)
            try FileManager.default.removeItem(at: outputFileURL)
        } catch let e {
            print("cleanup failed \(e)")
            // ...
        }
    }
    
    return minimized
}

