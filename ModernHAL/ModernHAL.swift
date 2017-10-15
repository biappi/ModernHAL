//
//  ModernHAL.swift
//  ModernHAL
//
//  Created by Antonio Malara on 23/09/2017.
//  Copyright © 2017 Antonio Malara. All rights reserved.
//

import Foundation

protocol WordElement : Comparable, Copyable, Hashable {
    var isFirstCharAlnum : Bool { get }
}

protocol Symbol : Comparable {
    static var initial : Self { get }
}

class Model<Element, SymbolType>
    where Element : WordElement, SymbolType : Symbol
{
    var order = 5
    
    private var forward  = Tree<SymbolType>(symbol: SymbolType.initial)
    private var backward = Tree<SymbolType>(symbol: SymbolType.initial)
    
    func initializeForward() -> Context {
        return Context(wrapping: self, initial: forward)
    }
    
    func initializeBackward() -> Context {
        return Context(wrapping: self, initial: backward)
    }
    
    class Context {
        private var context: [Tree<SymbolType>?]
        private let wrap : Model
        
        internal init(wrapping: Model, initial: Tree<SymbolType>) {
            wrap = wrapping
            context = [Tree?](repeating:nil, count: Int(wrapping.order + 2))
            context[0] = initial
        }
        
        func activeContexts() -> [Tree<SymbolType>] {
            return context.dropLast(2).flatMap { $0 }
        }
        
        func updateContext(symbol: SymbolType) {
            context = [context.first!] + context.dropLast().map { $0?.find(symbol: symbol) }
        }
        
        private func updateModel(symbol: SymbolType) {
            context.dropLast().forEach { _ = $0?.add(symbol: symbol) }
            context = [context.first!] + context.dropLast().map { $0?.find(symbol: symbol) }
        }
        
        func longestAvailableContext() -> Tree<SymbolType>? {
            return context.dropLast().flatMap { $0 }.last
        }
        
        var currentContext : Tree<SymbolType> { return context[0]! }
        
        func learn(symbols: [SymbolType]) {
            symbols.forEach { self.updateModel(symbol: $0) }
        }
    }
}

protocol Copyable {
    func copy() -> Self
}

class SymbolCollection<Element> : SymbolStore
    where Element: Copyable & Comparable
{
    var size : Int { return entries.count }
    
    var indices = [Int]()
    var entries = [Element]()
    
    required init() {
    }
    
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

    func symbol(for word: Element) -> Int {
        return find(word: word) ?? 0
    }
    
    func word(for symbol: Int) -> Element {
        return self[Int(symbol)]
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
    
    private func find(word: Element) -> Int? {
        let (position, found) = search(word: word)
        return found ? indices[position] : nil
    }
    
    subscript(i: Int) -> Element {
        return self.entries[i]
    }
    
    func contains(_ word: Element) -> Bool {
        return find(word: word) != nil
    }
}

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

extension STRING : WordElement {
    var isFirstCharAlnum: Bool {
        return isalnum(Int32(self.word.advanced(by: 0).pointee)) != 0
    }
}

class Tree <Symbol>
    where Symbol: Comparable
{
    var symbol : Symbol
    var usage  : Int    = 0
    var branch : Int    { return tree.count }
    var count  : Int    = 0
    var tree   : [Tree] = []
    
    init(symbol: Symbol) {
        self.symbol = symbol
    }
    
    func find(symbol: Symbol) -> Tree? {
        let (pos, found) = search(symbol: symbol)
        return found ? tree[pos] : nil
    }
    
    func add(symbol: Symbol) -> Tree {
        let (pos, found) = search(symbol: symbol)
        let node : Tree
        
        if found {
            node = tree[pos]
        }
        else {
            node = Tree(symbol: symbol)
            tree.insert(node, at: pos)
        }
        
        node.count += 1
        usage += 1
        
        return node
    }
    
    
    private func search(symbol: Symbol) -> (pos: Int, found: Bool) {
        if tree.count == 0 {
            return (0, false)
        }
        
        var min    = 0
        var max    = tree.count - 1
        var middle = (min + max) / 2
        
        while true {
            middle = (min + max) / 2
            let middleSymbol = tree[middle].symbol
            
            if symbol == middleSymbol {
                return (middle, true)
            }
            else if symbol > middleSymbol {
                if max == middle { return (middle + 1, false)  }
                min = middle + 1
            }
            else if symbol < middleSymbol {
                if min == middle { return (middle, false) }
                max = middle - 1
            }
        }
    }
}

struct PersonalityWords<Element : Hashable> {
    var swap : [Element:[Element]]
    var aux  : [Element]
    var ban  : [Element]
}

extension Int : Symbol {
    static var initial: Int {
        return 0
    }
}

protocol SymbolStore {
    associatedtype Element
    associatedtype Symbol
    
    init()
    
    func add(word: Element) -> Symbol
    
    func symbol(for word: Element) -> Symbol
    func word(for symbol: Symbol) -> Element
}

class Personality<Element : WordElement, SymbolDictionary : SymbolStore>
    where SymbolDictionary.Element == Element, SymbolDictionary.Symbol == Int
{
    var dictionary : SymbolDictionary
    var model      : Model<Element, Int>
    var wordLists  : PersonalityWords<Element>
    

    init(lists: PersonalityWords<Element>, word: Element, end: Element) {
        dictionary = SymbolDictionary()
        
        _ = dictionary.add(word: word)
        _ = dictionary.add(word: end)

        wordLists = lists
        model = Model()
    }
    
    func doReply(input: [Element]) -> [Element]? {
        learn(words: input)
        return generateReply(words: input)
    }
    
    func generateReply(words: [Element]) -> [Element]?
    {
        var output   = nil as [Element]?
        
        let keywords = makeKeywords(words: words).deduplicated()
        
        var replywords = reply(keys: [])
        
        if words != replywords {
            output = replywords
        }
        
        var count = 0
        var maxSurprise : Float32 = -10.0
        
        for _ in 0 ..< 10 {
            replywords = reply(keys: keywords)
            let surprise = evaluateReply(model: model,
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
    
    func reply(keys: [Element]) -> [Element]
    {
        var replies = [Element]()
        
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
            
            replies.append(dictionary.word(for: Int(symbol)))
            
            forwardContext.updateContext(symbol: Int(symbol))
        }
        
        let backwardContext = model.initializeBackward()
        
        replies.lazy
            .prefix(min(replies.count, model.order))
            .reversed()
            .forEach {
                backwardContext.updateContext(symbol: dictionary.symbol(for: $0))
            }
        
        while true {
            (symbol, used_key) = babble(context: backwardContext,
                                        keys: keys,
                                        words: replies,
                                        used_key: used_key)
            
            if symbol == 0 || symbol == 1 {
                break
            }
            
            replies.insert(dictionary.word(for: Int(symbol)), at: 0)
            backwardContext.updateContext(symbol: Int(symbol))
        }
        
        return replies
    }
    
    func makeKeywords(words: [Element]) -> [Element] {
        let swappedWords = words.flatMap { wordLists.swap[$0] ?? [$0] }
        let keywords     = swappedWords.filter { shouldAddKey(word: $0) }
        
        if keywords.count > 0 {
            let auxWords = swappedWords.filter { shouldAddAux(word: $0) }
            return keywords + auxWords
        }
        else {
            return []
        }
    }
    
    func shouldAddKey(word: Element) -> Bool {
        if dictionary.symbol(for: word) == 0 {
            return false
        }
        
        if !word.isFirstCharAlnum {
            return false
        }
        
        if wordLists.ban.contains(word) {
            return false
        }
        
        if wordLists.aux.contains(word) && wordLists.aux.first != word {
            return false
        }
        
        return true
    }
    
    func shouldAddAux(word: Element) -> Bool {
        if dictionary.symbol(for: word) == 0 {
            return false
        }
        
        if !word.isFirstCharAlnum {
            return false
        }
        
        if !wordLists.aux.contains(word) || wordLists.aux.first == word {
            return false
        }
        
        return true
    }
    
    func babble(context: Model<Element, Int>.Context,
                keys: [Element],
                words: [Element],
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
            
            if ((keys.contains(dictionary.word(for: symbol))) &&
                (dictionary.word(for: symbol) != keys.first) &&
                ((used_key == true) ||
                    (!wordLists.aux.contains(dictionary.word(for: symbol)) || wordLists.aux.first == dictionary.word(for: symbol))) &&
                (words.contains(dictionary.word(for: symbol)) == false))
            {
                used_key = true
                break;
            }
            
            
            count -= node.tree[i].count
            
            i = (i >= (node.branch - 1)) ? 0 : i + 1
        }
        
        return (Int32(symbol), used_key)
    }
    
    func seed(context: Model<Element, Int>.Context, keys: [Element]) -> Int32 {
        var symbol = 0
        
        if context.currentContext.branch == 0 {
            symbol = 0
        }
        else {
            symbol = Int(context.currentContext
                .tree[ Int(rnd(Int32(context.currentContext.branch))) ]
                .symbol)
        }
        
        if keys.count > 0 {
            var i = Int(rnd(Int32(keys.count)))
            let stop = i
            
            while true {
                if (dictionary.symbol(for: keys[i]) != 0) && (!wordLists.aux.contains(keys[i]) || wordLists.aux.first == keys[i])
                {
                    return Int32(dictionary.symbol(for: keys[i]))
                }
                
                i += 1
        
                if i == keys.count {
                    i = 0
                }
                
                if i == stop {
                    return Int32(symbol)
                }
            }
        }
        
        return Int32(symbol)
    }
    
    func evaluateReply(model: Model<Element, Int>,
                       keys:  [Element],
                       words: [Element])
        -> Float32
    {
        var num = 0
        var entropy : Float32 = 0
        
        let forwardContext = model.initializeForward()
        
        for word in words {
            let symbol = dictionary.symbol(for: word)
            
            if keys.contains(word) && (word != keys.first) {
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
            let symbol = dictionary.symbol(for: word)
            
            if keys.contains(word) && (word != keys.first) {
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
    
    func learn(words: [Element])
    {
        guard words.count > model.order else { return }

        let symbols = words.map { self.dictionary.add(word: $0) }
        model.initializeForward().learn(symbols: symbols + [1])
        model.initializeBackward().learn(symbols: symbols.reversed() + [1])
    }
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

extension String : WordElement {
    var isFirstCharAlnum: Bool {
        let firstCharacter = self.characters.first?.unicodeScalars.first
        return firstCharacter.map (CharacterSet.alphanumerics.contains) ?? false
    }
    
    func copy() -> String {
        return self
    }
}

class ModernHAL {
    let personality : Personality<String, SymbolCollection<String>>
    
    init() {
        var swap = [String:[String]]()
        for i in 0 ..< Int(swp.pointee.size) {
            let l = (from: swp.pointee.from.advanced(by: i).pointee.toString(),
                     to:   swp.pointee.to.advanced(by: i).pointee.toString())
            
            var d = swap[l.from] ?? [String]()
            d.append(l.to)
        }
        
        let lists =
            PersonalityWords(
                swap: swap,
                aux:
                    (0 ..< Int(aux.pointee.size))
                        .map { aux.pointee.entry.advanced(by: $0).pointee }
                        .map { $0.toString().uppercased() },
                ban:
                    (0 ..< Int(ban.pointee.size))
                        .map { ban.pointee.entry.advanced(by: $0).pointee }
                        .map { $0.toString().uppercased() }
            )

        personality = Personality(lists: lists, word: "<ERROR>", end: "<FIN>")
    }
    
    func reply(to sentence: String) -> String {
        return sentence.uppercased().withCString {
            let words = modernhal_make_words(from: UnsafeMutablePointer(mutating: $0)).map { $0.toString() }
            
            let reply = personality.doReply(input: words)
                .map { $0.joined() }
                ?? "I don't know enough to answer you yet!"
            
            let output = reply == "" ? "I am utterly speechless!" : reply
            
            var outputData = output.data(using: .utf8)
            outputData?.append(0)
            outputData?.withUnsafeMutableBytes { capitalize($0) }
            outputData!.remove(at: outputData!.count - 1)
            return outputData.map { String(data: $0, encoding: .utf8)! }!
        }
        
    }
}

extension Array where Element : Equatable
{
    func deduplicated() -> Array<Element> {
        return reduce(into: Array<Element>()) {
            if !$0.contains($1) {
                $0.append($1)
            }
        }
    }
}
