import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView {
            PositionsView()
                .tabItem {
                    Label("Positions", systemImage: "chart.pie.fill")
                }

            TradeView()
                .tabItem {
                    Label("Trade", systemImage: "arrow.left.arrow.right.circle.fill")
                }

            OrdersView()
                .tabItem {
                    Label("Orders", systemImage: "list.bullet.rectangle.fill")
                }

            MarketDataView()
                .tabItem {
                    Label("Market Data", systemImage: "waveform.path.ecg.rectangle.fill")
                }
        }
    }
}

#Preview {
    HomeView()
}
