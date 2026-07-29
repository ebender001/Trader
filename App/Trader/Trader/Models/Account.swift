//
//  Account.swift
//  Trader
//
//  Mirrors the subset of Alpaca's /v2/account fields we actually use.
//  Alpaca's Trading API returns money fields as JSON strings (not
//  numbers) to avoid floating point precision issues, so these are
//  modeled as String with a Double helper for display.
//

import Foundation

struct Account: Codable, Hashable {
    let id: String
    let accountNumber: String
    let status: String
    let currency: String
    let cash: String
    let portfolioValue: String
    let equity: String
    let lastEquity: String
    let buyingPower: String
    let regtBuyingPower: String
    let daytradingBuyingPower: String
    let patternDayTrader: Bool
    let tradingBlocked: Bool
    let accountBlocked: Bool
    let daytradeCount: Int
    let multiplier: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case accountNumber = "account_number"
        case status
        case currency
        case cash
        case portfolioValue = "portfolio_value"
        case equity
        case lastEquity = "last_equity"
        case buyingPower = "buying_power"
        case regtBuyingPower = "regt_buying_power"
        case daytradingBuyingPower = "daytrading_buying_power"
        case patternDayTrader = "pattern_day_trader"
        case tradingBlocked = "trading_blocked"
        case accountBlocked = "account_blocked"
        case daytradeCount = "daytrade_count"
        case multiplier
        case createdAt = "created_at"
    }
}

extension Account {
    var cashValue: Double { Double(cash) ?? 0 }
    var portfolioValueDouble: Double { Double(portfolioValue) ?? 0 }
    var equityValue: Double { Double(equity) ?? 0 }
    var lastEquityValue: Double { Double(lastEquity) ?? 0 }
    var buyingPowerValue: Double { Double(buyingPower) ?? 0 }

    /// Today's unrealized gain/loss (equity vs. yesterday's closing equity).
    var dayChange: Double { equityValue - lastEquityValue }

    var dayChangePercent: Double {
        guard lastEquityValue != 0 else { return 0 }
        return (dayChange / lastEquityValue) * 100
    }
}
