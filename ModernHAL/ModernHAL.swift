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
    
    private var dictionary : Keywords
    
    private var forward : Tree
    private var backward : Tree
    
    init(wrapping model: UnsafeMutablePointer<MODEL>) {
        wrap = model
        forward = wrap.pointee.forward
        backward = wrap.pointee.backward
        dictionary = Keywords(wrapping: wrap.pointee.dictionary)
    }
    
    func initializeForward() -> Context {
        return Context(wrapping: self, initial: forward)
    }
    
    func initializeBackward() -> Context {
        return Context(wrapping: self, initial: backward)
    }
    
    func symbol(for word: STRING) -> Int {
        return dictionary.find(word: word)
    }
    
    func word(for symbol: Int) -> STRING {
        return dictionary[Int(symbol)]
    }
    
    class Context {
        private var context: [Tree?]
        private let wrap : Model
        
        internal init(wrapping: Model, initial: Tree) {
            wrap = wrapping
            context = [Tree?](repeating:nil, count: Int(wrapping.order + 2))
            context[0] = initial
        }
        
        func activeContexts() -> [Tree] {
            return context.prefix(wrap.order).flatMap({ $0 })
        }
        
        func updateContext(word: STRING) {
            let symbol = wrap.dictionary.find(word: word)
            updateContext(symbol: symbol)
        }
        
        func updateContext(symbol: Int) {
            for i in (1 ..< (wrap.order + 2)).reversed() {
                if context[i - 1] != nil {
                    context[i] = context[i - 1]?.find(symbol: symbol)
                }
            }
        }
        
        func updateModel(word: STRING) {
            let symbol = wrap.dictionary.add(word: word)
            updateModel(symbol: symbol)
        }
        
        func updateModel(symbol: Int) {
            for i in (1 ..< Int(wrap.order + 2)).reversed() {
                if context[i - 1] != nil {
                    context[i] = context[i - 1]?.add(symbol:symbol)
                }
            }
        }
        
        func longestAvailableContext() -> Tree? {
            var node : Tree?
            
            for  i in 0 ..< wrap.order + 1 {
                if let c = context[i] {
                    node = c
                }
            }
            
            return node
        }
        
        var currentContext : Tree { return context[0]! }
    }
}

class Keywords {
    var size : Int { return entries.count }
    
    var indices = [Int]()
    var entries = [STRING]()
    
    convenience init(wrapping: UnsafeMutablePointer<DICTIONARY>) {
        self.init()
        
        for i in 0 ..< Int(wrapping.pointee.size) {
            indices.append(Int(wrapping.pointee.index.advanced(by: i).pointee))
            entries.append(wrapping.pointee.entry.advanced(by: i).pointee)
        }
    }
    
    func add(word: STRING) -> Int {
        let (position, found) = search(word: word)
        if found {
            return indices[position]
        }
        
        let w = UnsafeMutablePointer<Int8>.allocate(capacity: Int(word.length))
        memcpy(w, word.word, Int(word.length))
        
        let newSymbol = entries.count
        entries.append(STRING(length: word.length, word: w))
        indices.insert(newSymbol, at: position)
        
        return indices[position]
    }
    
    func search(word: STRING) -> (position: Int, found: Bool) {
        if size == 0 {
            return (0, false)
        }
        
        var min = 0
        var max = size - 1
        
        while true {
            let middle = (min + max) / 2
            
            let c = wordcmp(word, self[indices[middle]])
            
            if c == 0 {
                return (middle, true)
            }
            else if c > 0 {
                if max == middle {
                    return (middle + 1, false)
                }
                min = middle + 1
            }
            else {
                if min == middle {
                    return (middle, false)
                }
                max = middle - 1
            }
        }
    }
    
    func find(word: STRING) -> Int {
        let (position, found) = search(word: word)
        return found ? indices[position] : 0
    }
        
    subscript(i: Int) -> STRING {
        return self.entries[i]
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

typealias Tree = UnsafeMutablePointer<TREE>
extension UnsafeMutablePointer
    where Pointee == TREE
{
    
    var symbol : Int   { return Int(self.pointee.symbol) }
    var usage  : Int   { return Int(self.pointee.usage)  }
    var branch : Int   { return Int(self.pointee.branch) }
    var count  : Int   { return Int(self.pointee.count)  }
    var tree   : Trees { return Trees(wrapping: self)    }
    
    func find(symbol: Int) -> Tree? {
        let (pos, found) = search(symbol: symbol)
        return found ? tree[pos] : nil
    }
    
    func add(symbol: Int) -> Tree {
        let (pos, found) = search(symbol: symbol)
        let node : UnsafeMutablePointer<TREE>
        
        if found {
            node = tree[pos]
        }
        else {
            node = new_node()
            node.pointee.symbol = UInt16(symbol)
            add_node(self, node, Int32(pos))
        }
        
        node.pointee.count += 1
        pointee.usage += 1
        
        return node
    }
    
    
    private func search(symbol: Int) -> (pos: Int, found: Bool) {
        if tree.count == 0 {
            return (0, false)
        }
        
        var min    = 0
        var max    = tree.count - 1
        var middle = (min + max) / 2
        
        while true {
            middle = (min + max) / 2
            let compar = symbol - tree[middle].symbol
            
            if compar == 0 {
                return (middle, true)
            }
            else if compar > 0 {
                if max == middle { return (middle + 1, false)  }
                min = middle + 1
            }
            else if compar < 0 {
                if min == middle { return (middle, false) }
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
            return wrap.pointee.tree.advanced(by: i).pointee!
        }
        
        init(wrapping: UnsafeMutablePointer<TREE>) {
            wrap = wrapping
        }
    }
}

func modernhal_do_reply(globalModel: Model, input: String) -> String {
    
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

func modernhal_make_keywords(model: Model, words: [STRING]) -> Keywords {
    let keys = Keywords()
    
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

