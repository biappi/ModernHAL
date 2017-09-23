//
//  ModernHAL.swift
//  ModernHAL
//
//  Created by Antonio Malara on 23/09/2017.
//  Copyright © 2017 Antonio Malara. All rights reserved.
//

import Foundation

func modernhal_do_reply(input: String) -> String {
    return input.uppercased().withCString {
        make_words(UnsafeMutablePointer(mutating: $0), words)
        
        learn(model, words)
        
        let output = generate_reply(model, words)
        capitalize(output)
        
        return output.map { String(cString: $0) } ?? ""
    }
}
