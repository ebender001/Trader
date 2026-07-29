//
//  MarketClock.swift
//  Trader
//
//  Mirrors Alpaca's /v2/clock response.
//

import Foundation

struct MarketClock: Codable, Hashable {
    let timestamp: String
    let isOpen: Bool
    let nextOpen: String
    let nextClose: String

    enum CodingKeys: String, CodingKey {
        case timestamp
        case isOpen = "is_open"
        case nextOpen = "next_open"
        case nextClose = "next_close"
    }
}
