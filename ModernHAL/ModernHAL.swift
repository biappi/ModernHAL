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
    
    private var dictionary : Keywords { return Keywords(wrapping: wrap.pointee.dictionary) }
    
    private var forward : Tree
    private var backward : Tree
    
    init(wrapping model: UnsafeMutablePointer<MODEL>) {
        wrap = model
        forward = Tree(wrapping: wrap.pointee.forward)
        backward = Tree(wrapping: wrap.pointee.backward)
    }
    
    func initializeForward() -> Context {
        return Context(wrapping: wrap, initial: forward)
    }
    
    func initializeBackward() -> Context {
        return Context(wrapping: wrap, initial: backward)
    }
    
    func symbol(for word: STRING) -> Int {
        return dictionary.find(word: word)
    }
    
    func word(for symbol: Int) -> STRING {
        return dictionary[Int(symbol)]
    }
    
    class Context {
        private var context: Contexts
        private let wrap : UnsafeMutablePointer<MODEL>
        
        internal init(wrapping: UnsafeMutablePointer<MODEL>, initial: Tree) {
            wrap = wrapping
            context = Contexts(wrapping: wrapping)
            
            initialize_context(wrap)
            context[0] = initial
        }
        
        func activeContexts() -> [Tree] {
            return context.flatMap({ $0 })
        }
        
        func updateContext(word: STRING) {
            let symbol = Int(find_word(wrap.pointee.dictionary, word))
            updateContext(symbol: symbol)
        }
        
        func updateContext(symbol: Int) {
            for i in (1 ..< Int(wrap.pointee.order + 2)).reversed() {
                if context[i - 1] != nil {
                    context[i] = context[i - 1]?.find(symbol: symbol)
                }
            }
        }
        
        func updateModel(word: STRING) {
            let symbol = Int(add_word(wrap.pointee.dictionary, word))
            updateModel(symbol: symbol)
        }
        
        func updateModel(symbol: Int) {
            for i in (1 ..< Int(wrap.pointee.order + 2)).reversed() {
                if context[i - 1] != nil {
                    context[i] = context[i - 1]?.add(symbol:symbol)
                }
            }
        }
        
        func longestAvailableContext() -> Tree? {
            var node : Tree?
            
            for  i in 0 ..< context.count + 1 {
                if let c = context[i] {
                    node = c
                }
            }
            
            return node
        }
        
        var currentContext : Tree { return context[0]! }
    }
    
    internal class Contexts : Collection {
        let wrap : UnsafeMutablePointer<MODEL>
        
        public var startIndex : Int { return 0 }
        public var endIndex   : Int { return Int(wrap.pointee.order) }
        
        public func index(after i: Int) -> Int { return i + 1 }
        
        subscript(i: Int) -> Tree? {
            get {
                return wrap.pointee.context.advanced(by: i).pointee.map { Tree(wrapping: $0) }
            }
            
            set {
                wrap.pointee.context.advanced(by: i).pointee = newValue?.wrap
            }
        }
        
        init(wrapping: UnsafeMutablePointer<MODEL>) {
            wrap = wrapping
        }
    }
}

class Keywords {
    private let wrap : UnsafeMutablePointer<DICTIONARY>
    
    var size : Int { return Int(wrap.pointee.size) }
    
    init() {
        wrap = new_dictionary()!
    }
    
    init(wrapping: UnsafeMutablePointer<DICTIONARY>) {
        wrap = wrapping
    }
    
    func add(word: STRING) {
        add_word(wrap, word)
    }
    
    func find(word: STRING) -> Int {
        return Int(find_word(wrap, word))
    }
    
    func clear() {
        let size = Int(self.wrap.pointee.size)
        
        for i in 0 ..< size {
            self.wrap.pointee.entry.advanced(by: i).pointee.word.deallocate(capacity: 1)
        }
        
        free_dictionary(wrap)
    }
    
    subscript(i: Int) -> STRING {
        return self.wrap.pointee.entry.advanced(by: i).pointee
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

class Tree {
    let wrap: UnsafeMutablePointer<TREE>
    
    init(wrapping: UnsafeMutablePointer<TREE>) {
        wrap = wrapping
    }
    
    var symbol : Int   { return Int(wrap.pointee.symbol) }
    var usage  : Int   { return Int(wrap.pointee.usage)  }
    var branch : Int   { return Int(wrap.pointee.branch) }
    var count  : Int   { return Int(wrap.pointee.count)  }
    var tree   : Trees { return Trees(wrapping: wrap)    }
    
    func find(symbol: Int) -> Tree? {
        return search(symbol: symbol).map { tree[$0] }
    }
    
    func add(symbol: Int) -> Tree {
        return Tree(wrapping: add_symbol(wrap, UInt16(symbol)))
    }
    
    
    private func search(symbol: Int) -> Int? {
        if tree.count == 0 {
            return nil
        }
        
        var min    = 0
        var max    = tree.count - 1
        var middle = (min + max) / 2
        
        while true {
            middle = (min + max) / 2
            let compar = symbol - tree[middle].symbol
            
            if compar == 0 {
                return middle
            }
            else if compar > 0 {
                if max == middle { _ = middle + 1 ; return nil }
                min = middle + 1
            }
            else if compar < 0 {
                if min == middle { _ = middle ; return nil }
                max = middle - 1
            }
        }
    }
    
    class Trees : Collection {
        let wrap : UnsafeMutablePointer<TREE>
        
        public var startIndex : Int { return 0 }
        public var endIndex   : Int { return Int(wrap.pointee.branch) }
        
        public func index(after i: Int) -> Int { return i + 1 }
        
        subscript(i: Int) -> Tree {
            return wrap.pointee.tree.advanced(by: i).pointee.map { Tree(wrapping: $0) }!
        }
        
        init(wrapping: UnsafeMutablePointer<TREE>) {
            wrap = wrapping
        }
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
        let forwardContext = model.initializeForward()
        words.forEach { forwardContext.updateModel(word: $0) }
        forwardContext.updateModel(symbol: 1)
    }
    
    do {
        // Backwards training
        let backwardContext = model.initializeBackward()
        words.lazy.reversed().forEach { backwardContext.updateModel(word: $0) }
        backwardContext.updateModel(symbol: 1)
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
    
    let forwardContext = model.initializeForward()
    
    used_key = false
    
    var start = true
    var symbol : Int32 = 0
    
    while true {
        if start {
            symbol = modernhal_seed(model: model, context: forwardContext, keys: keys)
        }
        else {
            symbol = modernhal_babble(model: model, context: forwardContext, keys: keys, words: replies)
        }
        
        if symbol == 0 || symbol == 1 {
            break
        }
        
        start = false
        
        replies.append(model.word(for: Int(symbol)))
        
        forwardContext.updateContext(symbol: Int(symbol))
    }
    
    let backwardContext = model.initializeBackward()
    
    replies.lazy
        .prefix(min(replies.count, model.order))
        .reversed()
        .forEach {
            backwardContext.updateContext(word: $0)
        }
    
    while true {
        symbol = modernhal_babble(model: model, context: backwardContext, keys: keys, words: replies)
        
        if symbol == 0 || symbol == 1 {
            break
        }
        
        replies.insert(model.word(for: Int(symbol)), at: 0)
        backwardContext.updateContext(symbol: Int(symbol))
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
    
    let forwardContext = model.initializeForward()
    
    for word in words {
        let symbol = model.symbol(for: word)
        
        if keys.find(word: word) != 0 {
            var probability : Float32 = 0
            var count       : Int = 0
            
            num += 1
            
            for context in forwardContext.activeContexts() {
                let node = context.find(symbol: symbol)!
                probability += Float32(node.count) / Float32(context.usage)
                count += 1
            }
            
            if count > 0 {
                entropy -= Float32(log(Double(probability / Float32(count))))
            }
        }
        
        forwardContext.updateContext(symbol: symbol)
    }
    
    
    let backwardContext = model.initializeBackward()
    
    for word in words.lazy.reversed() {
        let symbol = model.symbol(for: word)
        
        if keys.find(word: word) != 0 {
            var probability : Float = 0
            var count       : Float = 0
            
            num += 1
            
            for context in backwardContext.activeContexts() {
                let node = context.find(symbol: symbol)!
                probability += Float32(node.count) / Float32(context.usage)
                count += 1
            }
            
            if count > 0 {
                entropy -= Float32(log(Double(probability / Float32(count))))
            }
        }
        
        backwardContext.updateContext(symbol: symbol)
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
    
    keys.add(word: word)
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
    
    keys.add(word: word)
}

func modernhal_babble(model: Model, context:Model.Context, keys: Keywords, words: [STRING]) -> Int32 {
    guard let node = context.longestAvailableContext() else {
        return 0
    }
    
    if node.branch == 0 {
        return 0
    }
    
    var i = Int(rnd(Int32(node.branch)))
    var count = Int(rnd(Int32(node.usage)))
    
    var symbol : Int = 0
    
    while count >= 0 {
        symbol = Int(node.tree[i].symbol)
        
        if ((keys.find(word: model.word(for: symbol)) != 0) &&
            ((used_key == true) || (find_word(aux, model.word(for: symbol)) == 0)) &&
            (words.contains(model.word(for: symbol)) == false))
        {
            used_key = true
            break;
        }
        

        count -= node.tree[i].count
        
        i = (i >= (node.branch - 1)) ? 0 : i + 1
    }
    
    return Int32(symbol)
}

func modernhal_seed(model: Model, context: Model.Context, keys: Keywords) -> Int32 {
    var symbol = 0
    
    if context.currentContext.branch == 0 {
        symbol = 0
    }
    else {
        symbol = Int(context.currentContext
            .tree[ Int(rnd(Int32(context.currentContext.branch))) ]
            .symbol)
    }
    
    if keys.size > 0 {
        var i = Int(rnd(Int32(keys.size)))
        let stop = i
        
        while true {
            if (model.symbol(for: keys[i]) != 0) && (find_word(aux, keys[i]) == 0)
            {
                return Int32(model.symbol(for: keys[i]))
            }
            
            i += 1
            
            if i == keys.size {
                i = 0
            }
            
            if i == stop {
                return Int32(symbol)
            }
        }
    }
    
    return Int32(symbol)
}

