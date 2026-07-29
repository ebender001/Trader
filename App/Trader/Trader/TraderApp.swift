//
//  TraderApp.swift
//  Trader
//
//  Created by Edward Bender on 7/29/26.
//

import SwiftUI

@main
struct TraderApp: App {
    init() {
        ParseConfig.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
