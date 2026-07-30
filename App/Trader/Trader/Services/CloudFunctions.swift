//
//  CloudFunctions.swift
//  Trader
//
//  One ParseCloudable-conforming struct per Back4App Cloud Code function.
//  `functionJobName` picks the endpoint (POST /functions/<name>); any
//  other stored properties are sent as its JSON params, using the same
//  camelCase names the Cloud Code side expects (see cloud/functions/).
//
//  These are intentionally "dumb" request descriptions — TradingService
//  is the friendly layer views actually call.
//

import Foundation
import ParseSwift

// MARK: - Health

struct HelloFunction: ParseCloudable {
    typealias ReturnType = String
    var functionJobName = "hello"
}

// MARK: - Account & market meta

struct GetAccountFunction: ParseCloudable {
    typealias ReturnType = Account
    var functionJobName = "getAccount"
}

struct GetClockFunction: ParseCloudable {
    typealias ReturnType = MarketClock
    var functionJobName = "getClock"
}

struct GetAssetFunction: ParseCloudable {
    typealias ReturnType = Asset
    var functionJobName = "getAsset"
    var symbol: String
}

// MARK: - Positions

struct GetPositionsFunction: ParseCloudable {
    typealias ReturnType = [Position]
    var functionJobName = "getPositions"
}

struct GetPositionFunction: ParseCloudable {
    typealias ReturnType = Position
    var functionJobName = "getPosition"
    var symbol: String
}

struct ClosePositionFunction: ParseCloudable {
    typealias ReturnType = Order
    var functionJobName = "closePosition"
    var symbol: String
    var qty: String?
    var percentage: String?
}

/// NOTE: Alpaca's DELETE /v2/positions (close-all) returns a batch array
/// shaped like [{ symbol, status, body }]. Verify this against a real
/// response before relying on it — it's the one endpoint here we
/// haven't exercised yet.
struct CloseAllPositionsResult: Codable, Hashable {
    let symbol: String
    let status: Int
    let body: Order?
}

struct CloseAllPositionsFunction: ParseCloudable {
    typealias ReturnType = [CloseAllPositionsResult]
    var functionJobName = "closeAllPositions"
    var cancelOrders: Bool?
}

// MARK: - Orders

struct PlaceOrderFunction: ParseCloudable {
    typealias ReturnType = Order
    var functionJobName = "placeOrder"
    var symbol: String
    var side: String
    var type: String
    var timeInForce: String
    var qty: String?
    var notional: String?
    var limitPrice: String?
    var stopPrice: String?
    var trailPrice: String?
    var trailPercent: String?
    var extendedHours: Bool?
    var clientOrderId: String?
}

struct ListOrdersFunction: ParseCloudable {
    typealias ReturnType = [Order]
    var functionJobName = "listOrders"
    var status: String?
    var limit: Int?
    var after: String?
    var until: String?
    var direction: String?
    var symbols: String?
}

struct GetOrderFunction: ParseCloudable {
    typealias ReturnType = Order
    var functionJobName = "getOrder"
    var orderId: String
}

struct CancelOrderFunction: ParseCloudable {
    typealias ReturnType = SuccessResponse
    var functionJobName = "cancelOrder"
    var orderId: String
}

/// NOTE: same caveat as CloseAllPositionsResult — Alpaca's DELETE
/// /v2/orders (cancel-all) returns [{ id, status }]; unverified here.
struct CancelAllOrdersResult: Codable, Hashable {
    let id: String
    let status: Int
}

struct CancelAllOrdersFunction: ParseCloudable {
    typealias ReturnType = [CancelAllOrdersResult]
    var functionJobName = "cancelAllOrders"
}

// MARK: - Market data

struct GetQuoteFunction: ParseCloudable {
    typealias ReturnType = SingleQuoteResponse
    var functionJobName = "getQuote"
    var symbol: String
}

struct GetQuotesFunction: ParseCloudable {
    typealias ReturnType = MultiQuoteResponse
    var functionJobName = "getQuotes"
    var symbols: String
}

/// NOTE: same caveat as the two batch endpoints above — Alpaca's
/// /v1beta1/indices/latest/values response shape hasn't been verified
/// against a real call yet. IndexValuesResponse (in Quote.swift) is a
/// best guess; check the real response and adjust the model before
/// relying on this.
struct GetIndexValuesFunction: ParseCloudable {
    typealias ReturnType = IndexValuesResponse
    var functionJobName = "getIndexValues"
    var symbols: String
}

/// Historical OHLCV bars for one symbol — chart data source. See
/// Bar.swift for field details; this is a well-established, stable
/// Alpaca endpoint (unlike indices), so the response shape here is
/// confident, not a guess.
struct GetBarsFunction: ParseCloudable {
    typealias ReturnType = BarsResponse
    var functionJobName = "getBars"
    var symbol: String
    var timeframe: String
    var start: String?
    var end: String?
    var limit: Int?
    var adjustment: String?
}
