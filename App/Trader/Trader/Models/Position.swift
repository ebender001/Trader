//
//  Position.swift
//  Trader
//
//  Mirrors Alpaca's /v2/positions objects. Money/qty fields are strings
//  on the wire, per Alpaca's Trading API convention.
//

import Foundation

struct Position: Codable, Hashable, Identifiable {
    let symbol: String
    let assetClass: String?
    let qty: String
    let side: String
    let avgEntryPrice: String
    let marketValue: String
    let costBasis: String
    let unrealizedPL: String
    let unrealizedPLPercent: String
    let currentPrice: String
    let changeToday: String

    var id: String { symbol }

    enum CodingKeys: String, CodingKey {
        case symbol
        case assetClass = "asset_class"
        case qty
        case side
        case avgEntryPrice = "avg_entry_price"
        case marketValue = "market_value"
        case costBasis = "cost_basis"
        case unrealizedPL = "unrealized_pl"
        case unrealizedPLPercent = "unrealized_plpc"
        case currentPrice = "current_price"
        case changeToday = "change_today"
    }
}

extension Position {
    var qtyValue: Double { Double(qty) ?? 0 }
    var avgEntryPriceValue: Double { Double(avgEntryPrice) ?? 0 }
    var marketValueDouble: Double { Double(marketValue) ?? 0 }
    var unrealizedPLValue: Double { Double(unrealizedPL) ?? 0 }
    var unrealizedPLPercentValue: Double { (Double(unrealizedPLPercent) ?? 0) * 100 }
    var currentPriceValue: Double { Double(currentPrice) ?? 0 }
}
