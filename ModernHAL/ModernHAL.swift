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
        
        let output = modernhal_generate_reply(model: model, words: words)
        
        var outputData = output.data(using: .utf8)
        outputData?.withUnsafeMutableBytes { capitalize($0) }
        return outputData.map { String(data: $0, encoding: .utf8)! }!
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

let dummy = new_dictionary()
func modernhal_generate_reply(model: UnsafeMutablePointer<MODEL>,
                              words: UnsafeMutablePointer<DICTIONARY>) -> String
{
    var output   = "I don't know enough to answer you yet!"
    let keywords = make_keywords(model, words)
    
    var replywords = reply(model, dummy)
    
    if dissimilar(words, replywords) {
        let string = make_output(replywords)!
        output = String(cString: string)
    }
    
    var count = 0
    var maxSurprise : Float = -10.0
    
    for _ in 0 ..< 10 {
        replywords = reply(model, keywords)
        let surprise = evaluate_reply(model, keywords, replywords)
        
        count += 1
        
        if surprise > maxSurprise && dissimilar(words, replywords) {
            maxSurprise = surprise
            
            let string = make_output(replywords)!
            output = String(cString: string)
        }
    }
    
    return output
}
