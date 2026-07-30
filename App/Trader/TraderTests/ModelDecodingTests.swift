//
//  ModelDecodingTests.swift
//  TraderTests
//
//  Verifies our Codable models decode Alpaca's actual JSON shapes.
//  The quote fixture below is the real response body we captured
//  testing getQuote against AAPL after market close on 7/29/26 —
//  everything else is built from Alpaca's documented response shapes.
//

import XCTest
@testable import Trader

final class ModelDecodingTests: XCTestCase {

    func testAccountDecoding() throws {
        let json = """
        {
            "id": "904837e3-3b76-47ec-b432-046db621571b",
            "account_number": "PA3ZC3KEMPHK",
            "status": "ACTIVE",
            "currency": "USD",
            "cash": "4000.32",
            "portfolio_value": "103820.56",
            "equity": "103820.56",
            "last_equity": "103010.11",
            "buying_power": "8000.64",
            "regt_buying_power": "8000.64",
            "daytrading_buying_power": "0",
            "pattern_day_trader": false,
            "trading_blocked": false,
            "account_blocked": false,
            "daytrade_count": 0,
            "multiplier": "2",
            "created_at": "2024-03-14T18:03:29.865176Z"
        }
        """
        let account = try decode(Account.self, from: json)
        XCTAssertEqual(account.status, "ACTIVE")
        XCTAssertEqual(account.cashValue, 4000.32)
        XCTAssertEqual(account.equityValue, 103820.56, accuracy: 0.001)
        XCTAssertFalse(account.patternDayTrader)
        XCTAssertGreaterThan(account.dayChange, 0)
    }

    func testPositionDecoding() throws {
        let json = """
        {
            "symbol": "AAPL",
            "asset_class": "us_equity",
            "qty": "10",
            "side": "long",
            "avg_entry_price": "330.50",
            "market_value": "3400.00",
            "cost_basis": "3305.00",
            "unrealized_pl": "95.00",
            "unrealized_plpc": "0.02875",
            "current_price": "340.00",
            "change_today": "0.012"
        }
        """
        let position = try decode(Position.self, from: json)
        XCTAssertEqual(position.symbol, "AAPL")
        XCTAssertEqual(position.qtyValue, 10)
        XCTAssertEqual(position.unrealizedPLValue, 95.00)
        XCTAssertEqual(position.unrealizedPLPercentValue, 2.875, accuracy: 0.001)
    }

    func testOrderDecoding() throws {
        let json = """
        {
            "id": "61e69015-8549-4bfd-b9c3-01e75843f47d",
            "client_order_id": "my-order-1",
            "symbol": "AAPL",
            "side": "buy",
            "type": "market",
            "time_in_force": "day",
            "status": "filled",
            "qty": "1",
            "notional": null,
            "filled_qty": "1",
            "filled_avg_price": "341.20",
            "limit_price": null,
            "stop_price": null,
            "extended_hours": false,
            "created_at": "2026-07-29T19:58:00.000Z",
            "submitted_at": "2026-07-29T19:58:00.100Z",
            "filled_at": "2026-07-29T19:58:00.400Z",
            "canceled_at": null,
            "failed_at": null
        }
        """
        let order = try decode(Order.self, from: json)
        XCTAssertEqual(order.status, "filled")
        XCTAssertFalse(order.isOpen)
        XCTAssertEqual(order.filledAvgPriceValue, 341.20)
    }

    func testOpenOrderIsOpen() throws {
        let json = """
        {
            "id": "61e69015-8549-4bfd-b9c3-01e75843f47d",
            "client_order_id": null,
            "symbol": "AAPL",
            "side": "buy",
            "type": "limit",
            "time_in_force": "gtc",
            "status": "new",
            "qty": "1",
            "notional": null,
            "filled_qty": "0",
            "filled_avg_price": null,
            "limit_price": "300.00",
            "stop_price": null,
            "extended_hours": false,
            "created_at": "2026-07-29T19:58:00.000Z",
            "submitted_at": "2026-07-29T19:58:00.100Z",
            "filled_at": null,
            "canceled_at": null,
            "failed_at": null
        }
        """
        let order = try decode(Order.self, from: json)
        XCTAssertTrue(order.isOpen)
        XCTAssertEqual(order.limitPriceValue, 300.00)
    }

    func testMarketClockDecoding() throws {
        let json = """
        {
            "timestamp": "2026-07-29T20:33:59.000Z",
            "is_open": false,
            "next_open": "2026-07-30T13:30:00.000Z",
            "next_close": "2026-07-30T20:00:00.000Z"
        }
        """
        let clock = try decode(MarketClock.self, from: json)
        XCTAssertFalse(clock.isOpen)
        XCTAssertEqual(clock.nextOpen, "2026-07-30T13:30:00.000Z")
    }

    /// This is the actual response body we captured from getQuote for
    /// AAPL after market close (see conversation history / README).
    func testSingleQuoteDecoding_realCapturedResponse() throws {
        let json = """
        {
            "quote": {
                "ap": 356.81,
                "as": 40,
                "ax": "V",
                "bp": 322.31,
                "bs": 40,
                "bx": "V",
                "c": ["R"],
                "t": "2026-07-29T20:00:00.000988168Z",
                "z": "C"
            },
            "symbol": "AAPL"
        }
        """
        let response = try decode(SingleQuoteResponse.self, from: json)
        XCTAssertEqual(response.symbol, "AAPL")
        XCTAssertEqual(response.quote.askPrice, 356.81)
        XCTAssertEqual(response.quote.bidPrice, 322.31)
        XCTAssertEqual(response.quote.midPrice, (356.81 + 322.31) / 2, accuracy: 0.001)
        XCTAssertEqual(response.quote.conditions, ["R"])
    }

    func testMultiQuoteDecoding() throws {
        let json = """
        {
            "quotes": {
                "AAPL": {"ap": 356.81, "as": 40, "ax": "V", "bp": 322.31, "bs": 40, "bx": "V", "c": ["R"], "t": "2026-07-29T20:00:00Z", "z": "C"},
                "TSLA": {"ap": 245.10, "as": 12, "ax": "V", "bp": 244.90, "bs": 8, "bx": "V", "c": ["R"], "t": "2026-07-29T20:00:00Z", "z": "C"}
            }
        }
        """
        let response = try decode(MultiQuoteResponse.self, from: json)
        XCTAssertEqual(response.quotes.count, 2)
        XCTAssertEqual(response.quotes["AAPL"]?.askPrice, 356.81)
        XCTAssertEqual(response.quotes["TSLA"]?.bidPrice, 244.90)
    }

    func testBarsDecoding() throws {
        let json = """
        {
            "bars": [
                {"t": "2026-07-29T13:30:00Z", "o": 338.10, "h": 339.50, "l": 337.80, "c": 339.20, "v": 1250000, "n": 8421, "vw": 338.65},
                {"t": "2026-07-29T13:31:00Z", "o": 339.20, "h": 340.00, "l": 339.00, "c": 339.85, "v": 980000, "n": 6210, "vw": 339.44}
            ],
            "symbol": "QQQ",
            "next_page_token": null
        }
        """
        let response = try decode(BarsResponse.self, from: json)
        XCTAssertEqual(response.symbol, "QQQ")
        XCTAssertEqual(response.bars.count, 2)
        XCTAssertNil(response.nextPageToken)
        XCTAssertEqual(response.bars.first?.open, 338.10)
        XCTAssertEqual(response.bars.first?.close, 339.20)
        XCTAssertEqual(response.bars.last?.tradeCount, 6210)
        XCTAssertEqual(response.bars.last?.vwap, 339.44)
    }

    // MARK: - Helper

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
