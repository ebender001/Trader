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
