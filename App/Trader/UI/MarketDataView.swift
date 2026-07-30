import SwiftUI

struct MarketDataView: View {
    @State private var symbol = "AAPL"
    @State private var quoteResponse: SingleQuoteResponse?
    @State private var clock: MarketClock?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Lookup") {
                    HStack {
                        TextField("Symbol", text: $symbol)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        Button {
                            Task { await loadMarketData() }
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .disabled(trimmedSymbol.isEmpty || isLoading)
                        .accessibilityLabel("Look up quote")
                    }
                }

                if isLoading {
                    Section {
                        ProgressView("Loading market data")
                    }
                }

                if let clock {
                    Section("Market Clock") {
                        LabeledContent("Status", value: clock.isOpen ? "Open" : "Closed")
                        LabeledContent("Timestamp", value: clock.timestamp)
                        LabeledContent("Next Open", value: clock.nextOpen)
                        LabeledContent("Next Close", value: clock.nextClose)
                    }
                }

                if let quoteResponse {
                    Section(quoteResponse.symbol) {
                        LabeledContent("Bid", value: TraderUIFormatting.currency(quoteResponse.quote.bidPrice))
                        LabeledContent("Bid Size", value: "\(quoteResponse.quote.bidSize)")
                        LabeledContent("Ask", value: TraderUIFormatting.currency(quoteResponse.quote.askPrice))
                        LabeledContent("Ask Size", value: "\(quoteResponse.quote.askSize)")
                        LabeledContent("Mid", value: TraderUIFormatting.currency(quoteResponse.quote.midPrice))
                        LabeledContent("Spread", value: TraderUIFormatting.currency(quoteResponse.quote.spread))
                        LabeledContent("Updated", value: quoteResponse.quote.timestamp)
                    }
                }
            }
            .navigationTitle("Market Data")
            .task {
                await loadMarketData()
            }
            .alert("Market Data Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unable to load market data.")
            }
        }
    }

    private var trimmedSymbol: String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func loadMarketData() async {
        guard !trimmedSymbol.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let loadedClock = TradingService.getClock()
            async let loadedQuote = TradingService.getQuote(symbol: trimmedSymbol)
            clock = try await loadedClock
            quoteResponse = try await loadedQuote
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    MarketDataView()
}
