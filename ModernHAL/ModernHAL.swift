//
//  ModernHAL.swift
//  ModernHAL
//
//  Created by Antonio Malara on 23/09/2017.
//  Copyright © 2017 Antonio Malara. All rights reserved.
//

import Foundation

class Model {
    let wrap : UnsafeMutablePointer<MODEL>
    
    var order : Int { return Int(wrap.pointee.order) }
    
    init(wrapping model: UnsafeMutablePointer<MODEL>) {
        wrap = model
    }
    
    func initializeForward() {
        initialize_context(wrap)
        wrap.pointee.context.advanced(by: 0).pointee = wrap.pointee.forward
    }
    
    func initializeBackward() {
        initialize_context(wrap)
        wrap.pointee.context.advanced(by: 0).pointee = wrap.pointee.backward
    }
    
    func symbol(for word: STRING) -> Int {
        return Int(find_word(wrap.pointee.dictionary, word))
    }
    
    func word(for symbol: Int) -> STRING {
        return wrap.pointee.dictionary.pointee.entry.advanced(by: Int(symbol)).pointee
    }
    
    func updateContext(word: STRING) {
        let symbol = Int(find_word(wrap.pointee.dictionary, word))
        updateContext(symbol: symbol)
    }
    
    func updateContext(symbol: Int) {
        update_context(wrap, Int32(symbol))
    }
    
    func updateModel(word: STRING) {
        let symbol = Int(add_word(wrap.pointee.dictionary, word))
        update_model(wrap, Int32(symbol))
    }
    
    func updateModel(symbol: Int) {
        update_model(wrap, Int32(symbol))
    }
    
    func contexts() -> AnyIterator<UnsafeMutablePointer<TREE>?> {
        var cur = 0
        let size = Int(self.wrap.pointee.order)
        
        return AnyIterator({
            if cur == size {
                return nil
            }
            else {
                defer { cur += 1 }
                return self.wrap.pointee.context.advanced(by: cur).pointee
            }
        })
    }
}

class HalDictionary : Sequence {
    let wrap : UnsafeMutablePointer<DICTIONARY>
    
    init(wrapping model: UnsafeMutablePointer<DICTIONARY>) {
        wrap = model
    }
    
    func find(word: STRING) -> Int {
        return Int(find_word(wrap, word))
    }
    
    func makeIterator() -> AnyIterator<STRING> {
        var cur = 0
        let size = Int(self.wrap.pointee.size)
        
        return AnyIterator({
            if cur == size {
                return nil
            }
            else {
                defer { cur += 1 }
                return self.wrap.pointee.entry.advanced(by: cur).pointee
            }
        })
    }
}

func modernhal_do_reply(input: String) -> String {
    let globalModel = Model(wrapping: model)
    
    return input.uppercased().withCString {
        make_words(UnsafeMutablePointer(mutating: $0), words)
        
        modernhal_learn(model: globalModel, words: words)
        
        let output = modernhal_generate_reply(model: globalModel, words: words)
        
        var outputData = output.data(using: .utf8)
        outputData?.append(0)
        outputData?.withUnsafeMutableBytes { capitalize($0) }
        outputData!.remove(at: outputData!.count - 1)
        return outputData.map { String(data: $0, encoding: .utf8)! }!
    }
}

func modernhal_learn(model: Model,
                     words: UnsafeMutablePointer<DICTIONARY>)
{
    if words.pointee.size <= model.order {
        return
    }
    
    do {
        // Forward training
        model.initializeForward()
        
        for i in 0 ..< words.pointee.size {
            model.updateModel(word: words.pointee.entry.advanced(by: Int(i)).pointee)
        }
        
        model.updateModel(symbol: 1)
    }
    
    do {
        // Backwards training
        model.initializeBackward()
        
        for i in (0 ..< words.pointee.size).reversed() {
            model.updateModel(word: words.pointee.entry.advanced(by: Int(i)).pointee)
        }
        
        model.updateModel(symbol: 1)
    }
}

let dummy = new_dictionary()!
func modernhal_generate_reply(model: Model,
                              words: UnsafeMutablePointer<DICTIONARY>) -> String
{
    var output   = "I don't know enough to answer you yet!"
    let keywords = HalDictionary(wrapping: make_keywords(model.wrap, words))
    
    var replywords = HalDictionary(wrapping: modernhal_reply(model: model, keys: dummy))
    
    if dissimilar(words, replywords.wrap) {
        let string = make_output(replywords.wrap)!
        output = String(cString: string)
    }
    
    var count = 0
    var maxSurprise : Float32 = -10.0
    
    for _ in 0 ..< 10 {
        replywords = HalDictionary(wrapping: modernhal_reply(model: model, keys: keywords.wrap))
        let surprise = modernhal_evaluate_reply(model: model,
                                                keys: keywords,
                                                words: replywords)
        
        count += 1
        
        if surprise > maxSurprise && dissimilar(words, replywords.wrap) {
            maxSurprise = surprise
            
            let string = make_output(replywords.wrap)!
            output = String(cString: string)
        }
    }
    
    return output
}

let replies = new_dictionary()!
func modernhal_reply(model: Model,
                     keys:  UnsafeMutablePointer<DICTIONARY>)
    -> UnsafeMutablePointer<DICTIONARY>
{
    
    free_dictionary(replies)
    
    model.initializeForward()
    
    used_key = false
    
    var start = true
    var symbol : Int32 = 0
    
    while true {
        if start {
            symbol = seed(model.wrap, keys)
        }
        else {
            symbol = babble(model.wrap, keys, replies)
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
        
        replies.pointee.entry.advanced(by: Int(replies.pointee.size)).pointee
            = model.word(for: Int(symbol))
        
        replies.pointee.size += 1
        
        model.updateContext(symbol: Int(symbol))
    }
    
    model.initializeBackward()
    
    if replies.pointee.size > 0 {
        let size = min(Int(replies.pointee.size), Int(model.order))
        for i in (0 ..< size).reversed() {
            model.updateContext(word: replies.pointee.entry.advanced(by: i).pointee)
        }
    }
    
    while true {
        symbol = babble(model.wrap, keys, replies)
        
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
        
        replies.pointee.entry.advanced(by: 0).pointee
            = model.word(for: Int(symbol))
        
        replies.pointee.size += 1
        
        model.updateContext(symbol: Int(symbol))
    }
    
    return replies
}

func modernhal_evaluate_reply(model: Model,
                              keys:  HalDictionary,
                              words: HalDictionary)
    -> Float32
{
    var num = 0
    var entropy : Float32 = 0
    
    model.initializeForward()
    
    for word in words {
        let symbol = model.symbol(for: word)
        
        if keys.find(word: word) != 0 {
            var probability : Float32 = 0
            var count       : Int = 0
            
            num += 1
            
            for context in model.contexts().flatMap({ $0 }) {
                let node = find_symbol(context, Int32(symbol))
                probability += Float32(node!.pointee.count) / Float32(context.pointee.usage)
                count += 1
            }
            
            if count > 0 {
                entropy -= Float32(log(Double(probability / Float32(count))))
            }
        }
        
        model.updateContext(symbol: symbol)
    }
    
    
    model.initializeBackward()
    
    for word in words.lazy.reversed() {
        let symbol = model.symbol(for: word)
        
        if keys.find(word: word) != 0 {
            var probability : Float = 0
            var count       : Float = 0
            
            num += 1
            
            for context in model.contexts().flatMap({ $0 }) {
                let node = find_symbol(context, Int32(symbol))
                probability += Float32(node!.pointee.count) / Float32(context.pointee.usage)
                count += 1
            }
            
            if count > 0 {
                entropy -= Float32(log(Double(probability / Float32(count))))
            }
        }
        
        model.updateContext(symbol: symbol)
    }
    
    if num >= 8 {
        entropy /= Float32(sqrt(Double(num - 1)))
    }
    
    if num >= 16 {
        entropy /= Float32(num)
    }

    return entropy
}

