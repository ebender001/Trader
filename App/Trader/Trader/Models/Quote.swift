//
//  Quote.swift
//  Trader
//
//  Mirrors Alpaca's Market Data API quote objects. Unlike the Trading
//  API, these fields come back as real JSON numbers — confirmed
//  against our own getQuote response: {"ap":356.81,"as":40,"ax":"V", ...}
//

import Foundation

struct QuoteData: Codable, Hashable {
    let askPrice: Double
    let askSize: Int
    let askExchange: String?
    let bidPrice: Double
    let bidSize: Int
    let bidExchange: String?
    let conditions: [String]?
    let timestamp: String
    let tape: String?

    enum CodingKeys: String, CodingKey {
        case askPrice = "ap"
        case askSize = "as"
        case askExchange = "ax"
        case bidPrice = "bp"
        case bidSize = "bs"
        case bidExchange = "bx"
        case conditions = "c"
        case timestamp = "t"
        case tape = "z"
    }
}

extension QuoteData {
    /// Midpoint of bid/ask — a reasonable stand-in "current price" when
    /// there's no trade price handy.
    var midPrice: Double { (askPrice + bidPrice) / 2 }

    var spread: Double { askPrice - bidPrice }
}

/// Response shape for getQuote({ symbol }) — single symbol.
struct SingleQuoteResponse: Codable, Hashable {
    let symbol: String
    let quote: QuoteData
}

/// Response shape for getQuotes({ symbols }) — multiple symbols.
struct MultiQuoteResponse: Codable, Hashable {
    let quotes: [String: QuoteData]
}

// MARK: - Index values

struct IndexValueData: Codable, Hashable {
    let symbol: String?
    let value: Double?
    let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case indexSymbol = "index_symbol"
        case value
        case shortValue = "v"
        case timestamp = "t"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ??
            container.decodeIfPresent(String.self, forKey: .indexSymbol)
        value = try container.decodeIfPresent(Double.self, forKey: .value) ??
            container.decodeIfPresent(Double.self, forKey: .shortValue)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(symbol, forKey: .symbol)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
    }
}

struct IndexValuesResponse: Codable, Hashable {
    let indexValues: [String: IndexValueData]

    enum CodingKeys: String, CodingKey {
        case indexValues = "index_values"
        case values
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let dictionary = try container.decodeIfPresent([String: IndexValueData].self, forKey: .indexValues) ??
            container.decodeIfPresent([String: IndexValueData].self, forKey: .values) ??
            container.decodeIfPresent([String: IndexValueData].self, forKey: .data) {
            indexValues = dictionary
            return
        }

        if let array = try container.decodeIfPresent([IndexValueData].self, forKey: .indexValues) ??
            container.decodeIfPresent([IndexValueData].self, forKey: .values) ??
            container.decodeIfPresent([IndexValueData].self, forKey: .data) {
            indexValues = Dictionary(
                uniqueKeysWithValues: array.compactMap { value in
                    value.symbol.map { ($0, value) }
                }
            )
            return
        }

        indexValues = [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(indexValues, forKey: .indexValues)
    }
}
