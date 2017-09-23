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
        
        modernhal_learn(model: model, words: words)
        
        let output = generate_reply(model, words)
        capitalize(output)
        
        return output.map { String(cString: $0) } ?? ""
    }
}

func modernhal_learn(model: UnsafeMutablePointer<MODEL>,
                     words: UnsafeMutablePointer<DICTIONARY>)
{
    if words.pointee.size <= model.pointee.order {
        return
    }
    
    do {
        // Forward training
        
        initialize_context(model)
        model.pointee.context.advanced(by: 0).pointee = model.pointee.forward
        
        for i in 0 ..< words.pointee.size {
            let symbol = add_word(model.pointee.dictionary,
                                  words.pointee.entry.advanced(by: Int(i)).pointee)
            update_model(model, Int32(symbol))
        }
        
        update_model(model, 1)
    }
    
    do {
        // Backwards training
        
        initialize_context(model)
        model.pointee.context.advanced(by: 0).pointee = model.pointee.backward
        
        for i in (0 ..< words.pointee.size).reversed() {
            let symbol = add_word(model.pointee.dictionary,
                                  words.pointee.entry.advanced(by: Int(i)).pointee)
            update_model(model, Int32(symbol))
        }
        
        update_model(model, 1)
    }
}
