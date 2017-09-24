//
//  ModernHALTests.swift
//  ModernHALTests
//
//  Created by Antonio Malara on 23/09/2017.
//  Copyright © 2017 Antonio Malara. All rights reserved.
//

import XCTest
import SwiftCheck

@testable import ModernHAL

let lowerCaseCharacters : Gen<Character> = Gen<Character>.fromElements(in: "a"..."z")
let upperCaseCharacters : Gen<Character> = Gen<Character>.fromElements(in: "A"..."Z")
let numericCharacters   : Gen<Character> = Gen<Character>.fromElements(in: "0"..."9")
let specialCharacters   : Gen<Character> = Gen<Character>.fromElements(of: ["!", "#", "$", "%", "&", "'", "*", "+", "-", "/", "=", "?", "^", "_", "`", "{", "|", "}", "~", "."])

let letters = Gen<Character>.one(of: [
    lowerCaseCharacters,
    upperCaseCharacters,
    numericCharacters,
    specialCharacters
])

let strings = letters
    .proliferateNonEmpty
    .suchThat { $0.count > 1 }
    .map { String.init($0) }

let word = Gen<String>.fromElements(of: [
    "test",
    "one",
    "two",
    "three"
])
    
let words = word
    .proliferate
    .flatMap { Gen<String>.pure($0.joined(separator: " ")) }

let smokeTestInput = [
    "test one test two test three",
    "one test two test three test",
    "test two test three test one",
    "two test three test one test",
    "test three test one test two",
    "three test one test two test",
    "test one test two test three",
    "one test two test three test",
]

extension STRING {
    init(_ s: String) {
        let d = s.data(using: .utf8)!
        let p = UnsafeMutablePointer<Int8>.allocate(capacity: d.count)
        let b = UnsafeMutableBufferPointer(start: p, count: d.count)
        _ = d.copyBytes(to: b)
        
        length = UInt8(d.count)
        word = p
    }
}

class ModernHALTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        megahal_initialize()
        
        srand48(0)
        smokeTestInput.forEach {
            $0.withCString {
                _ = megahal_do_reply(UnsafeMutablePointer(mutating: $0), 0)
            }
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /// Smoke test trying to avoid c memory crashers
    func test_smoke() {
        let sampleAnswers = [
            "One test two test three test.",
            "Test one test two.",
            "One test two test three test.",
            "Three test one.",
            "Two test three test one.",
            "One test two.",
            "Three test one test two test.",
            "Two test three."
        ]
        
        srand48(0)
        let answers = smokeTestInput.map {
            $0.withCString {
                String(cString: megahal_do_reply(UnsafeMutablePointer(mutating: $0), 0))
            }
        }
        
        XCTAssert(answers == sampleAnswers)
    }
    
    func test_quickchecks() {
        property("upper") <-
            forAll(strings) { (s: String) in
                
                var stringData = s.data(using: .utf8)!
                stringData.append(0)
                stringData.withUnsafeMutableBytes { upper($0) }
                stringData.remove(at: stringData.count - 1)
                let uppercased = String(bytes: stringData, encoding: .utf8)!
                
                return uppercased == s.uppercased()
            }
        
        property("tests are deterministic") <-
            forAllNoShrink(words) { (string: String) in
                
                return string.withCString {
                    megahal_initialize()
                    
                    let s      = UnsafeMutablePointer(mutating: $0)
                    srand48(0)
                    let first  = String(cString: megahal_do_reply(s, 0))
                    srand48(0)
                    let second = String(cString: megahal_do_reply(s, 0))
                    
                    return first == second
                }
            }
        
        property("do_reply") <-
        forAllNoShrink(words) { (string: String) in
            
            return string.withCString {
                let a = word.generate
                let b = word.generate
                let c = word.generate
                
                megahal_initialize()
                add_word(aux, STRING(a))
                add_word(aux, STRING(b))
                add_word(aux, STRING(c))
                
                srand48(0)
                
                let s      = UnsafeMutablePointer(mutating: $0)
                let first  = String(cString: megahal_do_reply(s, 0))
                print(first)
                
                srand48(0)
                megahal_initialize()
                add_word(aux, STRING(a))
                add_word(aux, STRING(b))
                add_word(aux, STRING(c))
                
                let second = modernhal_do_reply(input: string)
                print(second)
                
                return first == second
            }
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
