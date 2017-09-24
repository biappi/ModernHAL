//
//  ModernHAL.swift
//  ModernHAL
//
//  Created by Antonio Malara on 23/09/2017.
//  Copyright © 2017 Antonio Malara. All rights reserved.
//

import Foundation

extension MODEL {
    mutating func initializeForward() {
        initialize_context(&self)
        context.advanced(by: 0).pointee = forward
    }
    
    mutating func initializeBackward() {
        initialize_context(&self)
        context.advanced(by: 0).pointee = backward
    }
}

func modernhal_do_reply(input: String) -> String {
    return input.uppercased().withCString {
        make_words(UnsafeMutablePointer(mutating: $0), words)
        
        modernhal_learn(model: model, words: words)
        
        let output = modernhal_generate_reply(model: model, words: words)
        
        var outputData = output.data(using: .utf8)
        outputData?.append(0)
        outputData?.withUnsafeMutableBytes { capitalize($0) }
        outputData!.remove(at: outputData!.count - 1)
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
        model.pointee.initializeForward()
        
        for i in 0 ..< words.pointee.size {
            let symbol = add_word(model.pointee.dictionary,
                                  words.pointee.entry.advanced(by: Int(i)).pointee)
            update_model(model, Int32(symbol))
        }
        
        update_model(model, 1)
    }
    
    do {
        // Backwards training
        model.pointee.initializeBackward()
        
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
    var maxSurprise : Float32 = -10.0
    
    for _ in 0 ..< 10 {
        replywords = modernhal_reply(model: model, keys: keywords!)
        let surprise = modernhal_evaluate_reply(model: model, keys: keywords!, words: replywords!)
        
        count += 1
        
        if surprise > maxSurprise && dissimilar(words, replywords) {
            maxSurprise = surprise
            
            let string = make_output(replywords)!
            output = String(cString: string)
        }
    }
    
    return output
}

let replies = new_dictionary()!
func modernhal_reply(model: UnsafeMutablePointer<MODEL>,
                     keys:  UnsafeMutablePointer<DICTIONARY>)
    -> UnsafeMutablePointer<DICTIONARY>
{
    free_dictionary(replies)
    
    model.pointee.initializeForward()
    
    used_key = false
    
    var start = true
    var symbol : Int32 = 0
    
    while true {
        if start {
            symbol = seed(model, keys)
        }
        else {
            symbol = babble(model, keys, replies)
        }
        
        if symbol == 0 || symbol == 1 {
            break
        }
        
        start = false
        
        if replies.pointee.entry == nil {
            replies.pointee.entry = UnsafeMutablePointer<STRING>.allocate(capacity: Int(replies.pointee.size) + 1)
        }
        else {
            let p = realloc(replies.pointee.entry, Int(replies.pointee.size + 1) * MemoryLayout<STRING>.stride)
            replies.pointee.entry = p?.assumingMemoryBound(to: STRING.self)
        }
        
        replies.pointee.entry.advanced(by: Int(replies.pointee.size)).pointee.length
            = model.pointee.dictionary.pointee.entry.advanced(by: Int(symbol)).pointee.length
        replies.pointee.entry.advanced(by: Int(replies.pointee.size)).pointee.word
            = model.pointee.dictionary.pointee.entry.advanced(by: Int(symbol)).pointee.word
        
        replies.pointee.size += 1
        
        update_context(model, symbol)
    }
    
    model.pointee.initializeBackward()
    
    if replies.pointee.size > 0 {
        let size = min(Int(replies.pointee.size), Int(model.pointee.order))
        for i in (0 ..< size).reversed() {
            let symbol = find_word(model.pointee.dictionary,
                                   replies.pointee.entry.advanced(by: i).pointee)
            update_context(model, Int32(symbol))
        }
    }
    
    while true {
        symbol = babble(model, keys, replies)
        
        if symbol == 0 || symbol == 1 {
            break
        }
        
        if replies.pointee.entry == nil {
            replies.pointee.entry = UnsafeMutablePointer<STRING>.allocate(capacity: Int(replies.pointee.size) + 1)
        }
        else {
            let p = realloc(replies.pointee.entry, Int(replies.pointee.size + 1) * MemoryLayout<STRING>.stride)
            replies.pointee.entry = p?.assumingMemoryBound(to: STRING.self)
        }
        
        for i in (1 ..< replies.pointee.size + 1).reversed() {
            replies.pointee.entry.advanced(by: Int(i)).pointee.length
                = replies.pointee.entry.advanced(by: Int(i - 1)).pointee.length
            
            replies.pointee.entry.advanced(by: Int(i)).pointee.word
                = replies.pointee.entry.advanced(by: Int(i - 1)).pointee.word
        }
        
        replies.pointee.entry.advanced(by: 0).pointee.length
            = model.pointee.dictionary.pointee.entry.advanced(by: Int(symbol)).pointee.length
        
        replies.pointee.entry.advanced(by: 0).pointee.word
            = model.pointee.dictionary.pointee.entry.advanced(by: Int(symbol)).pointee.word
        
        replies.pointee.size += 1
        
        update_context(model, symbol)
    }
    
    return replies
}

func modernhal_evaluate_reply(model: UnsafeMutablePointer<MODEL>,
                              keys:  UnsafeMutablePointer<DICTIONARY>,
                              words: UnsafeMutablePointer<DICTIONARY>)
    -> Float32
{
    if words.pointee.size <= 0 {
        return 0
    }
    
    var num = 0
    var entropy : Float32 = 0
    
    model.pointee.initializeForward()
    
    for i in 0 ..< Int(words.pointee.size) {
        let symbol = find_word(model.pointee.dictionary, words.pointee.entry.advanced(by: i).pointee)
        
        if find_word(keys, words.pointee.entry.advanced(by: i).pointee) != 0 {
            var probability : Float32 = 0
            var count       : Int = 0
            
            num += 1
            
            for j in 0 ..< Int(model.pointee.order) {
                if let context = model.pointee.context.advanced(by: j).pointee {
                    let node = find_symbol(context, Int32(symbol))
                    probability += Float32(node!.pointee.count) / Float32(context.pointee.usage)
                    count += 1
                }
            }
            
            if count > 0 {
                entropy -= Float32(log(Double(probability / Float32(count))))
            }
        }
        
        update_context(model, Int32(symbol))
    }
    
    
    initialize_context(model)
    model.pointee.context.advanced(by: 0).pointee = model.pointee.backward
    
    for i in (0 ..< Int(words.pointee.size)).reversed() {
        let symbol = find_word(model.pointee.dictionary, words.pointee.entry.advanced(by: i).pointee)
        
        if find_word(keys, words.pointee.entry.advanced(by: i).pointee) != 0 {
            var probability : Float = 0
            var count       : Float = 0
            
            num += 1
            
            for j in 0 ..< Int(model.pointee.order) {
                if let context = model.pointee.context.advanced(by: j).pointee {
                    let node = find_symbol(context, Int32(symbol))
                    probability += Float(node!.pointee.count) / Float(context.pointee.usage)
                    count += 1
                }
            }
            
            if count > 0 {
                entropy -= Float32(log(Double(probability / Float32(count))))
            }
        }
        update_context(model, Int32(symbol))
    }
    
    if num >= 8 {
        entropy /= Float32(sqrt(Double(num - 1)))
    }
    
    if num >= 16 {
        entropy /= Float32(num)
    }

    return entropy
}
