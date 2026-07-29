//
//  Order.swift
//  Trader
//
//  Mirrors Alpaca's /v2/orders objects (also what POST /v2/orders and
//  DELETE /v2/positions/{symbol} return). Money/qty fields are strings
//  on the wire; many fields are only present once an order reaches a
//  given lifecycle stage, so most are Optional.
//

import Foundation

struct Order: Codable, Hashable, Identifiable {
    let id: String
    let clientOrderId: String?
    let symbol: String
    let side: String
    let type: String
    let timeInForce: String
    let status: String
    let qty: String?
    let notional: String?
    let filledQty: String?
    let filledAvgPrice: String?
    let limitPrice: String?
    let stopPrice: String?
    let extendedHours: Bool?
    let createdAt: String?
    let submittedAt: String?
    let filledAt: String?
    let canceledAt: String?
    let failedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case clientOrderId = "client_order_id"
        case symbol
        case side
        case type
        case timeInForce = "time_in_force"
        case status
        case qty
        case notional
        case filledQty = "filled_qty"
        case filledAvgPrice = "filled_avg_price"
        case limitPrice = "limit_price"
        case stopPrice = "stop_price"
        case extendedHours = "extended_hours"
        case createdAt = "created_at"
        case submittedAt = "submitted_at"
        case filledAt = "filled_at"
        case canceledAt = "canceled_at"
        case failedAt = "failed_at"
    }
}

extension Order {
    var qtyValue: Double? { qty.flatMap(Double.init) }
    var filledQtyValue: Double? { filledQty.flatMap(Double.init) }
    var filledAvgPriceValue: Double? { filledAvgPrice.flatMap(Double.init) }
    var limitPriceValue: Double? { limitPrice.flatMap(Double.init) }
    var stopPriceValue: Double? { stopPrice.flatMap(Double.init) }

    var isOpen: Bool {
        !["filled", "canceled", "expired", "rejected", "done_for_day"].contains(status)
    }
}

/// A simple `{ success: true }` acknowledgement, used by cancelOrder.
struct SuccessResponse: Codable, Hashable {
    let success: Bool
}
