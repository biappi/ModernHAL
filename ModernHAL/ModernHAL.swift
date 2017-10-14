//
//  ModernHAL.swift
//  ModernHAL
//
//  Created by Antonio Malara on 23/09/2017.
//  Copyright © 2017 Antonio Malara. All rights reserved.
//

import Foundation

class Model<Element>
    where Element: Comparable & Copyable
{
    var order = 5
    
    private var dictionary = SymbolCollection<Element>()
    
    private var forward  = Tree()
    private var backward = Tree()
    
    init(word: Element, end: Element) {
        _ = dictionary.add(word: word)
        _ = dictionary.add(word: end)
    }
    
    func initializeForward() -> Context {
        return Context(wrapping: self, initial: forward)
    }
    
    func initializeBackward() -> Context {
        return Context(wrapping: self, initial: backward)
    }
    
    func symbol(for word: Element) -> Int {
        return dictionary.find(word: word)
    }
    
    func word(for symbol: Int) -> Element {
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
        
        func updateContext(word: Element) {
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
        
        func updateModel(word: Element) {
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

protocol Copyable {
    func copy() -> Self
}

class SymbolCollection<Element>
    where Element: Copyable & Comparable
{
    var size : Int { return entries.count }
    
    var indices = [Int]()
    var entries = [Element]()
    
    func add(word: Element) -> Int {
        let (position, found) = search(word: word)
        if found {
            return indices[position]
        }
        
        let newSymbol = entries.count
        entries.append(word.copy())
        indices.insert(newSymbol, at: position)
        
        return indices[position]
    }
    
    func search(word: Element) -> (position: Int, found: Bool) {
        if size == 0 {
            return (0, false)
        }
        
        var min = 0
        var max = size - 1
        
        while true {
            let middle = (min + max) / 2
            let middleWord = self[indices[middle]]
            
            if word == middleWord {
                return (middle, true)
            }
            else if word > middleWord {
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
    
    func find(word: Element) -> Int {
        let (position, found) = search(word: word)
        return found ? indices[position] : 0
    }
        
    subscript(i: Int) -> Element {
        return self.entries[i]
    }
}

typealias Keywords = SymbolCollection<STRING>

extension STRING : Equatable { }

public func ==(lhs: STRING, rhs: STRING) -> Bool {
    return wordcmp(lhs, rhs) == 0
}

extension STRING : Hashable {
    func toString() -> String {
        let data = Data(bytes: self.word, count: Int(self.length))
        return String(data: data, encoding: .utf8)!
    }
    
    public var hashValue: Int { return self.toString().hashValue}
}

extension STRING : Comparable {
    public static func <(lhs: STRING, rhs: STRING) -> Bool {
        return wordcmp(lhs, rhs) < 0
    }
}

extension STRING : Copyable {
    func copy() -> STRING {
        let w = UnsafeMutablePointer<Int8>.allocate(capacity: Int(self.length))
        memcpy(w, self.word, Int(self.length))
        return STRING(length: self.length, word: w)
    }
}

class Tree
{
    var symbol : Int    = 0
    var usage  : Int    = 0
    var branch : Int    { return tree.count }
    var count  : Int    = 0
    var tree   : [Tree] = []
    
    func find(symbol: Int) -> Tree? {
        let (pos, found) = search(symbol: symbol)
        return found ? tree[pos] : nil
    }
    
    func add(symbol: Int) -> Tree {
        let (pos, found) = search(symbol: symbol)
        let node : Tree
        
        if found {
            node = tree[pos]
        }
        else {
            node = Tree()
            node.symbol = symbol
            tree.insert(node, at: pos)
        }
        
        node.count += 1
        usage += 1
        
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
}

class Personality {
    var model : Model<STRING>
    var swap : [STRING:[STRING]]
    var auxy : [STRING]
    var bann : [STRING]
    
    init() {
        model = Model(word: _word, end: _end)
        
        swap = [STRING:[STRING]]()
        for i in 0 ..< Int(swp.pointee.size) {
            let l = (from: swp.pointee.from.advanced(by: i).pointee,
                     to:   swp.pointee.to.advanced(by: i).pointee)
            
            var d = swap[l.from] ?? [STRING]()
            d.append(l.to)
        }
        
        auxy = (0 ..< Int(aux.pointee.size))
            .map { aux.pointee.entry.advanced(by: $0).pointee }
        
        bann = (0 ..< Int(ban.pointee.size))
            .map { ban.pointee.entry.advanced(by: $0).pointee }
    }
    
    
    func doReply(input: String) -> String {
        
        return input.uppercased().withCString {
            let words = modernhal_make_words(from: UnsafeMutablePointer(mutating: $0))
            
            modernhal_learn(model: model, words: words)
            
            let reply = generateReply(words: words)
                .map { $0.map { $0.toString() }.joined() }
                ?? "I don't know enough to answer you yet!"
            
            let output = reply == "" ? "I am utterly speechless!" : reply
            
            var outputData = output.data(using: .utf8)
            outputData?.append(0)
            outputData?.withUnsafeMutableBytes { capitalize($0) }
            outputData!.remove(at: outputData!.count - 1)
            return outputData.map { String(data: $0, encoding: .utf8)! }!
        }
    }
    
    func generateReply(words: [STRING]) -> [STRING]?
    {
        var output   = nil as [STRING]?
        let keywords = makeKeywords(words: words)
        
        var replywords = reply(keys: Keywords())
        
        
        if words != replywords {
            output = replywords
        }
        
        var count = 0
        var maxSurprise : Float32 = -10.0
        
        for _ in 0 ..< 10 {
            replywords = reply(keys: keywords)
            let surprise = modernhal_evaluate_reply(model: model,
                                                    keys: keywords,
                                                    words: replywords)
            
            count += 1
            
            if surprise > maxSurprise && (words != replywords) {
                maxSurprise = surprise
                output = replywords
            }
        }
        
        return output
    }
    
    func reply(keys: Keywords) -> [STRING]
    {
        var replies = [STRING]()
        
        let forwardContext = model.initializeForward()
        
        var used_key = false
        
        var start = true
        var symbol : Int32 = 0
        
        while true {
            if start {
                symbol = seed(context: forwardContext,
                              keys: keys)
            }
            else {
                (symbol, used_key) = babble(context: forwardContext,
                                            keys: keys,
                                            words: replies,
                                            used_key: used_key)
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
            (symbol, used_key) = babble(context: backwardContext,
                                        keys: keys,
                                        words: replies,
                                        used_key: used_key)
            
            if symbol == 0 || symbol == 1 {
                break
            }
            
            replies.insert(model.word(for: Int(symbol)), at: 0)
            backwardContext.updateContext(symbol: Int(symbol))
        }
        
        return replies
    }
    
    func makeKeywords(words: [STRING]) -> Keywords {
        let keys = Keywords()
        
        for word in words {
            let toAdd = swap[word] ?? [word]
            toAdd.forEach { addKey(keys: keys, word: $0) }
        }
        
        if keys.size > 0 {
            for word in words {
                let toAdd = swap[word] ?? [word]
                toAdd.forEach { addAux(keys: keys, word: $0) }
            }
        }
        
        return keys
    }
    
    func addKey(keys: Keywords, word: STRING) {
        if model.symbol(for: word) == 0 {
            return
        }
        
        if isalnum(Int32(word.word.advanced(by: 0).pointee)) == 0 {
            return
        }
        
        if bann.contains(word) {
            return
        }
        
        if auxy.contains(word) && auxy.first != word {
            return
        }
        
        _ = keys.add(word: word)
    }
    
    func addAux(keys: Keywords, word: STRING) {
        if model.symbol(for: word) == 0 {
            return
        }
        
        if isalnum(Int32(word.word.advanced(by: 0).pointee)) == 0 {
            return
        }
        
        if !auxy.contains(word) || auxy.first == word {
            return
        }
        
        _ = keys.add(word: word)
    }
    
    func babble(context: Model<STRING>.Context,
                keys: Keywords,
                words: [STRING],
                used_key: Bool) -> (Int32, Bool)
    {
        guard let node = context.longestAvailableContext() else {
            return (0, used_key)
        }
        
        if node.branch == 0 {
            return (0, used_key)
        }
        
        var i = Int(rnd(Int32(node.branch)))
        var count = Int(rnd(Int32(node.usage)))
        
        var used_key = used_key
        
        var symbol : Int = 0
        
        while count >= 0 {
            symbol = Int(node.tree[i].symbol)
            
            if ((keys.find(word: model.word(for: symbol)) != 0) &&
                ((used_key == true) ||
                    (!auxy.contains(model.word(for: symbol)) || auxy.first == model.word(for: symbol))) &&
                (words.contains(model.word(for: symbol)) == false))
            {
                used_key = true
                break;
            }
            
            
            count -= node.tree[i].count
            
            i = (i >= (node.branch - 1)) ? 0 : i + 1
        }
        
        return (Int32(symbol), used_key)
    }
    
    func seed(context: Model<STRING>.Context, keys: Keywords) -> Int32 {
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
                if (model.symbol(for: keys[i]) != 0) && (!auxy.contains(keys[i]) || auxy.first == keys[i])
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
}


func modernhal_learn(model: Model<STRING>, words: [STRING])
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

func modernhal_evaluate_reply(model: Model<STRING>,
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

class ModernHAL {
    let personality : Personality
    
    init() {
        personality = Personality()
    }
    
    func reply(to sentence: String) -> String {
        return personality.doReply(input: sentence)
    }
}
