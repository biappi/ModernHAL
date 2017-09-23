//
//  ModernHALTests.swift
//  ModernHALTests
//
//  Created by Antonio Malara on 23/09/2017.
//  Copyright © 2017 Antonio Malara. All rights reserved.
//

import XCTest
@testable import ModernHAL

class ModernHALTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /// Smoke test trying to avoid c memory crashers
    func test_smoke() {
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
        
        let sampleAnswers = [
            "I don\'t know enough to answer you yet!",
            "Test one test two test three test.",
            "One test two test three.",
            "Test two test three.",
            "One test two test three.",
            "Test three test one.",
            "Three test one.",
            "One test two test."
        ]
        
        megahal_initialize()
        
        let answers = smokeTestInput.map {
            $0.withCString {
                String(cString: megahal_do_reply(UnsafeMutablePointer(mutating: $0), 0))
            }
        }
        
        XCTAssert(answers == sampleAnswers)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
