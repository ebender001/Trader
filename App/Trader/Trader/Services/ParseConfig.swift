//
//  ParseConfig.swift
//  Trader
//
//  Initializes the ParseSwift SDK against our Back4App app. The
//  Client Key is safe to ship in the app binary — unlike the REST/master
//  keys the Cloud Code backend uses, it's designed to be embedded in
//  clients, with class-level permissions/ACLs doing the actual access
//  control on the server side.
//

import Foundation
import ParseSwift

enum ParseConfig {
    static let applicationId = "lkViTJ3sPH14UHCHjFLbGii4hWSYw54ZA67Dct3N"
    static let clientKey = "kBAtxC1HVGs9TerDJ5UHCElKdU7eGpuXre4laFjv"
    static let serverURL = URL(string: "https://parseapi.back4app.com/")!

    static func initialize() {
        ParseSwift.initialize(
            applicationId: applicationId,
            clientKey: clientKey,
            serverURL: serverURL
        )
    }
}
