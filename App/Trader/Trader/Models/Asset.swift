//
//  Asset.swift
//  Trader
//
//  Mirrors Alpaca's /v2/assets/{symbol} response.
//

import Foundation

struct Asset: Codable, Hashable {
    let id: String
    let assetClass: String
    let exchange: String
    let symbol: String
    let name: String?
    let status: String
    let tradable: Bool
    let marginable: Bool
    let shortable: Bool
    let easyToBorrow: Bool
    let fractionable: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case assetClass = "class"
        case exchange
        case symbol
        case name
        case status
        case tradable
        case marginable
        case shortable
        case easyToBorrow = "easy_to_borrow"
        case fractionable
    }
}
