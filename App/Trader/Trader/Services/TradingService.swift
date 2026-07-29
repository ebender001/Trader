//
//  TradingService.swift
//  Trader
//
//  Friendly async API the views call, wrapping the raw CloudFunctions
//  request structs. Errors propagate as ParseError (from ParseSwift),
//  which carries the message our Cloud Code's Parse.Error normalization
//  sets — see cloud/lib/errors.js.
//

import Foundation
import ParseSwift

enum TradingService {

    // MARK: Account & market meta

    static func getAccount() async throws -> Account {
        try await GetAccountFunction().runFunction()
    }

    static func getClock() async throws -> MarketClock {
        try await GetClockFunction().runFunction()
    }

    static func getAsset(symbol: String) async throws -> Asset {
        try await GetAssetFunction(symbol: symbol).runFunction()
    }

    // MARK: Positions

    static func getPositions() async throws -> [Position] {
        try await GetPositionsFunction().runFunction()
    }

    static func getPosition(symbol: String) async throws -> Position {
        try await GetPositionFunction(symbol: symbol).runFunction()
    }

    static func closePosition(symbol: String, qty: String? = nil, percentage: String? = nil) async throws -> Order {
        try await ClosePositionFunction(symbol: symbol, qty: qty, percentage: percentage).runFunction()
    }

    static func closeAllPositions(cancelOrders: Bool? = nil) async throws -> [CloseAllPositionsResult] {
        try await CloseAllPositionsFunction(cancelOrders: cancelOrders).runFunction()
    }

    // MARK: Orders

    static func placeOrder(
        symbol: String,
        side: String,
        type: String,
        timeInForce: String,
        qty: String? = nil,
        notional: String? = nil,
        limitPrice: String? = nil,
        stopPrice: String? = nil,
        trailPrice: String? = nil,
        trailPercent: String? = nil,
        extendedHours: Bool? = nil,
        clientOrderId: String? = nil
    ) async throws -> Order {
        try await PlaceOrderFunction(
            symbol: symbol,
            side: side,
            type: type,
            timeInForce: timeInForce,
            qty: qty,
            notional: notional,
            limitPrice: limitPrice,
            stopPrice: stopPrice,
            trailPrice: trailPrice,
            trailPercent: trailPercent,
            extendedHours: extendedHours,
            clientOrderId: clientOrderId
        ).runFunction()
    }

    static func listOrders(
        status: String? = nil,
        limit: Int? = nil,
        after: String? = nil,
        until: String? = nil,
        direction: String? = nil,
        symbols: String? = nil
    ) async throws -> [Order] {
        try await ListOrdersFunction(
            status: status,
            limit: limit,
            after: after,
            until: until,
            direction: direction,
            symbols: symbols
        ).runFunction()
    }

    static func getOrder(orderId: String) async throws -> Order {
        try await GetOrderFunction(orderId: orderId).runFunction()
    }

    static func cancelOrder(orderId: String) async throws -> SuccessResponse {
        try await CancelOrderFunction(orderId: orderId).runFunction()
    }

    static func cancelAllOrders() async throws -> [CancelAllOrdersResult] {
        try await CancelAllOrdersFunction().runFunction()
    }

    // MARK: Market data

    static func getQuote(symbol: String) async throws -> SingleQuoteResponse {
        try await GetQuoteFunction(symbol: symbol).runFunction()
    }

    static func getQuotes(symbols: [String]) async throws -> MultiQuoteResponse {
        try await GetQuotesFunction(symbols: symbols.joined(separator: ",")).runFunction()
    }
}
