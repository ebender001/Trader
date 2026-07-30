//
//  Bar.swift
//  Trader
//
//  Mirrors Alpaca's OHLCV bar objects from GET /v2/stocks/{symbol}/bars —
//  the data source for historical/scrolling charts. Like quotes, these
//  are real JSON numbers (Market Data API convention), not strings.
//

import Foundation

struct Bar: Codable, Hashable, Identifiable {
    let timestamp: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let tradeCount: Int?
    let vwap: Double?

    var id: String { timestamp }

    enum CodingKeys: String, CodingKey {
        case timestamp = "t"
        case open = "o"
        case high = "h"
        case low = "l"
        case close = "c"
        case volume = "v"
        case tradeCount = "n"
        case vwap = "vw"
    }
}

/// Response shape for getBars({ symbol, timeframe, ... }).
struct BarsResponse: Codable, Hashable {
    let bars: [Bar]
    let symbol: String
    let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case bars
        case symbol
        case nextPageToken = "next_page_token"
    }
}
