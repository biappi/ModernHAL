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

class Keywords : Sequence {
    let wrap : UnsafeMutablePointer<DICTIONARY>
    
    var size : Int { return Int(wrap.pointee.size) }
    
    init() {
        wrap = new_dictionary()!
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
    
    var last : STRING? {
        return size != 0
            ? wrap.pointee.entry[size - 1]
            : nil
    }
}


extension SWAP : Collection {
    public var startIndex : Int { return 0 }
    public var endIndex   : Int { return Int(size) }
    
    public func index(after i: Int) -> Int { return i + 1 }
    
    public subscript(i: Int) -> (from: STRING, to: STRING) {
        return (from: from.advanced(by: i).pointee,
                to:   to.advanced(by: i).pointee)
    }
    
    subscript(from: STRING) -> [STRING]
    {
        return Array(
            self
                .lazy
                .filter { wordcmp($0.from, from) == 0 }
                .map { $0.to }
        )
    }
}

extension STRING : Equatable { }

public func ==(lhs: STRING, rhs: STRING) -> Bool {
    return wordcmp(lhs, rhs) == 0
}

extension STRING {
    func toString() -> String {
        let data = Data(bytes: self.word, count: Int(self.length))
        return String(data: data, encoding: .utf8)!
    }
}
func modernhal_do_reply(input: String) -> String {
    let globalModel = Model(wrapping: model)
    
    return input.uppercased().withCString {
        let words = modernhal_make_words(from: UnsafeMutablePointer(mutating: $0))
        
        modernhal_learn(model: globalModel, words: words)
        
        let output = modernhal_generate_reply(model: globalModel, words: words)
        
        var outputData = output.data(using: .utf8)
        outputData?.append(0)
        outputData?.withUnsafeMutableBytes { capitalize($0) }
        outputData!.remove(at: outputData!.count - 1)
        return outputData.map { String(data: $0, encoding: .utf8)! }!
    }
}

func modernhal_learn(model: Model, words: [STRING])
{
    if words.count <= model.order {
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

let dummy = Keywords()
func modernhal_generate_reply(model: Model,
                              words: [STRING]) -> String
{
    var output   = "I don't know enough to answer you yet!"
    let keywords = modernhal_make_keywords(model: model, words: words)
    
    var replywords = modernhal_reply(model: model, keys: dummy)
    
    
    if words != replywords {
        output = replywords.map { $0.toString() }.joined()
    }
    
    var count = 0
    var maxSurprise : Float32 = -10.0
    
    for _ in 0 ..< 10 {
        replywords = modernhal_reply(model: model, keys: keywords)
        let surprise = modernhal_evaluate_reply(model: model,
                                                keys: keywords,
                                                words: replywords)
        
        count += 1
        
        if surprise > maxSurprise && (words != replywords) {
            maxSurprise = surprise
            output = replywords.map { $0.toString() }.joined()
        }
    }
    
    return output == "" ? "I am utterly speechless!" : output
}

func modernhal_reply(model: Model, keys: Keywords) -> [STRING]
{
    var replies = [STRING]()
    
    model.initializeForward()
    
    used_key = false
    
    var start = true
    var symbol : Int32 = 0
    
    while true {
        if start {
            symbol = seed(model.wrap, keys.wrap)
        }
        else {
            symbol = modernhal_babble(model: model, keys: keys, words: replies)
        }
        
        if symbol == 0 || symbol == 1 {
            break
        }
        
        start = false
        
        replies.append(model.word(for: Int(symbol)))
        
        model.updateContext(symbol: Int(symbol))
    }
    
    model.initializeBackward()
    
    replies.lazy
        .prefix(min(replies.count, model.order))
        .reversed()
        .forEach {
            model.updateContext(word: $0)
        }
    
    while true {
        symbol = modernhal_babble(model: model, keys: keys, words: replies)
        
        if symbol == 0 || symbol == 1 {
            break
        }
        
        replies.insert(model.word(for: Int(symbol)), at: 0)
        model.updateContext(symbol: Int(symbol))
    }
    
    return replies
}

func modernhal_evaluate_reply(model: Model,
                              keys:  Keywords,
                              words: [STRING])
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

var dot : STRING = {
    let d = ".".data(using: .utf8)!
    let p = UnsafeMutablePointer<Int8>.allocate(capacity: d.count)
    let b = UnsafeMutableBufferPointer(start: p, count: d.count)
    _ = d.copyBytes(to: b)
    
    return STRING(length: UInt8(d.count), word: p)
}()

func modernhal_make_words(from input: UnsafeMutablePointer<Int8>) -> [STRING] {
    var dictionary = [STRING]()
    
    if strlen(input) == 0 {
        return dictionary
    }
    
    var input  = input
    var offset = 0
    
    while true {
        if boundary(input, Int32(offset)) {
            dictionary.append(STRING(length: UInt8(offset), word: input))
            
            if offset == strlen(input) {
                break
            }
            
            input = input.advanced(by: offset)
            offset = 0
        }
        else {
            offset += 1
        }
    }
    
    let last = dictionary.last!
    if isalnum(Int32(last.word.advanced(by: 0).pointee)) != 0 {
        dictionary.append(dot)
    }
    else {
        let lastChar = last.word.advanced(by: Int(last.length) - 1)
        
        let lastCharNotPoints = "!.?".withCString { (s) -> Bool in
            return strchr(s, Int32(lastChar.pointee)) == nil
        }
        
        if lastCharNotPoints {
            lastChar.pointee = dot.word.advanced(by: 0).pointee
        }
    }
    
    return dictionary
}

let keys = Keywords()
func modernhal_make_keywords(model: Model, words: [STRING]) -> Keywords {
    keys.forEach { $0.word.deallocate(capacity: 1) }
    keys.clear()
    
    for word in words {
        let swaps = swp.pointee[word]
        let toAdd = swaps.isEmpty ? [word] : swaps
        toAdd.forEach { modernhal_add_key(model: model, keys: keys, word: $0) }
    }
    
    if keys.size > 0 {
        for word in words {
            let swaps = swp.pointee[word]
            let toAdd = swaps.isEmpty ? [word] : swaps
            toAdd.forEach { modernhal_add_aux(model: model, keys: keys, word: $0) }
        }
    }
    
    return keys
}

func modernhal_add_key(model: Model, keys: Keywords, word: STRING) {
    if model.symbol(for: word) == 0 {
        return
    }
    
    if isalnum(Int32(word.word.advanced(by: 0).pointee)) == 0 {
        return
    }
    
    if Int(find_word(ban, word)) != 0 {
        return
    }
    
    if Int(find_word(aux, word)) != 0 {
        return
    }
    
    add_word(keys.wrap, word)
}

func modernhal_add_aux(model: Model, keys: Keywords, word: STRING) {
    if model.symbol(for: word) == 0 {
        return
    }
    
    if isalnum(Int32(word.word.advanced(by: 0).pointee)) == 0 {
        return
    }
    
    if Int(find_word(aux, word)) == 0 {
        return
    }
    
    add_word(keys.wrap, word)
}

func modernhal_babble(model: Model, keys: Keywords, words: [STRING]) -> Int32 {
    guard let node = modernhal_longest_available_context(model.wrap) else {
        return 0
    }
    
    if node.pointee.branch == 0 {
        return 0
    }
    
    var i = Int(rnd(Int32(node.pointee.branch)))
    var count = Int(rnd(Int32(node.pointee.usage)))
    
    var symbol : Int = 0
    
    while count >= 0 {
        symbol = Int(node.pointee.tree.advanced(by: i).pointee!.pointee.symbol)
        
        if ((find_word(keys.wrap, model.word(for: symbol)) != 0) &&
            ((used_key == true) || (find_word(aux, model.word(for: symbol)) == 0)) &&
            (words.contains(model.word(for: symbol)) == false))
        {
            used_key = true
            break;
        }
        
        count -= Int(node.pointee.tree.advanced(by: i).pointee!.pointee.count)
        
        i = (i >= (node.pointee.branch - 1)) ? 0 : i + 1
    }
    
    return Int32(symbol)
}
