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
    
    var size : Int { return Int(wrap.pointee.size) }
    
    static func new() -> HalDictionary {
        return HalDictionary(wrapping: new_dictionary()!)
    }
    
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
    
    func clear() {
        free_dictionary(wrap)
    }
    
    private func grow() {
        if wrap.pointee.entry == nil {
            wrap.pointee.entry = UnsafeMutablePointer<STRING>.allocate(capacity: Int(wrap.pointee.size) + 1)
        }
        else {
            let p = realloc(wrap.pointee.entry, Int(wrap.pointee.size + 1) * MemoryLayout<STRING>.stride)
            wrap.pointee.entry = p?.assumingMemoryBound(to: STRING.self)
        }
    }
    func append(word: STRING) {
        grow()
        
        wrap.pointee.entry.advanced(by: Int(wrap.pointee.size)).pointee = word
        wrap.pointee.size += 1
    }
    
    func prepend(word:STRING) {
        grow()
        
        for i in (1 ..< wrap.pointee.size + 1).reversed() {
            wrap.pointee.entry.advanced(by: Int(i)).pointee.length
                = wrap.pointee.entry.advanced(by: Int(i - 1)).pointee.length
            
            wrap.pointee.entry.advanced(by: Int(i)).pointee.word
                = wrap.pointee.entry.advanced(by: Int(i - 1)).pointee.word
        }
        
        wrap.pointee.entry.advanced(by: 0).pointee = word
        wrap.pointee.size += 1
    }
}

func modernhal_do_reply(input: String) -> String {
    let globalModel = Model(wrapping: model)
    let globalWords = HalDictionary(wrapping: words)
    
    return input.uppercased().withCString {
        make_words(UnsafeMutablePointer(mutating: $0), globalWords.wrap)
        
        modernhal_learn(model: globalModel, words: globalWords)
        
        let output = modernhal_generate_reply(model: globalModel,
                                              words: globalWords)
        
        var outputData = output.data(using: .utf8)
        outputData?.append(0)
        outputData?.withUnsafeMutableBytes { capitalize($0) }
        outputData!.remove(at: outputData!.count - 1)
        return outputData.map { String(data: $0, encoding: .utf8)! }!
    }
}

func modernhal_learn(model: Model, words: HalDictionary)
{
    if words.size <= model.order {
        return
    }
    
    do {
        // Forward training
        model.initializeForward()
        words.forEach { model.updateModel(word: $0) }
        model.updateModel(symbol: 1)
    }
    
    do {
        // Backwards training
        model.initializeBackward()
        words.lazy.reversed().forEach { model.updateModel(word: $0) }
        model.updateModel(symbol: 1)
    }
}

let dummy = HalDictionary.new()
func modernhal_generate_reply(model: Model,
                              words: HalDictionary) -> String
{
    var output   = "I don't know enough to answer you yet!"
    let keywords = HalDictionary(wrapping: make_keywords(model.wrap, words.wrap))
    
    var replywords = modernhal_reply(model: model, keys: dummy)
    
    if dissimilar(words.wrap, replywords.wrap) {
        let string = make_output(replywords.wrap)!
        output = String(cString: string)
    }
    
    var count = 0
    var maxSurprise : Float32 = -10.0
    
    for _ in 0 ..< 10 {
        replywords = modernhal_reply(model: model, keys: keywords)
        let surprise = modernhal_evaluate_reply(model: model,
                                                keys: keywords,
                                                words: replywords)
        
        count += 1
        
        if surprise > maxSurprise && dissimilar(words.wrap, replywords.wrap) {
            maxSurprise = surprise
            
            let string = make_output(replywords.wrap)!
            output = String(cString: string)
        }
    }
    
    return output
}

let replies = HalDictionary.new()
func modernhal_reply(model: Model,
                     keys:  HalDictionary)
    -> HalDictionary
{
    replies.clear()
    
    model.initializeForward()
    
    used_key = false
    
    var start = true
    var symbol : Int32 = 0
    
    while true {
        if start {
            symbol = seed(model.wrap, keys.wrap)
        }
        else {
            symbol = babble(model.wrap, keys.wrap, replies.wrap)
        }
        
        if symbol == 0 || symbol == 1 {
            break
        }
        
        start = false
        
        replies.append(word: model.word(for: Int(symbol)))
        
        model.updateContext(symbol: Int(symbol))
    }
    
    model.initializeBackward()
    
    replies.lazy
        .prefix(min(replies.size, model.order))
        .reversed()
        .forEach {
            model.updateContext(word: $0)
        }
    
    while true {
        symbol = babble(model.wrap, keys.wrap, replies.wrap)
        
        if symbol == 0 || symbol == 1 {
            break
        }
        
        replies.prepend(word: model.word(for: Int(symbol)))
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

