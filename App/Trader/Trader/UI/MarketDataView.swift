import Charts
import SwiftUI

struct MarketDataView: View {
    @State private var samples: [MarketSample] = []
    @State private var clock: MarketClock?
    @State private var isLoading = false
    @State private var lastUpdated: Date?
    @State private var errorMessage: String?

    private let trackedMarkets = MarketIndex.tracked
    private let pollInterval: Duration = .seconds(60)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let clock {
                        MarketClockSummary(clock: clock, lastUpdated: lastUpdated)
                    }

                    indexChart

                    VStack(spacing: 12) {
                        ForEach(trackedMarkets) { market in
                            MarketIndexRow(
                                market: market,
                                sample: latestSample(for: market),
                                changePercent: changePercent(for: market)
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Market Data")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadMarketData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Refresh market data")
                }
            }
            .overlay {
                if isLoading && samples.isEmpty {
                    ProgressView("Loading market data")
                }
            }
            .task {
                await pollMarketData()
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

    private var indexChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Major Index Proxies")
                .font(.headline)

            Chart(samples) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Change", normalizedChangePercent(for: sample))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Index", sample.market.name))

                PointMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Change", normalizedChangePercent(for: sample))
                )
                .foregroundStyle(by: .value("Index", sample.market.name))
            }
            .frame(height: 260)
            .chartYAxisLabel("Change")
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let percent = value.as(Double.self) {
                            Text(TraderUIFormatting.percent(percent))
                        }
                    }
                }
            }

            Text("QQQ, DIA, and SPY are used as tradable proxies for Nasdaq Composite, Dow Jones Industrials, and S&P 500 because the current app cloud service exposes stock quotes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func pollMarketData() async {
        await loadMarketData()

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: pollInterval)
                await loadMarketData()
            } catch {
                return
            }
        }
    }

    private func loadMarketData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let loadedClock = TradingService.getClock()
            async let loadedQuotes = TradingService.getQuotes(symbols: trackedMarkets.map(\.quoteSymbol))
            let timestamp = Date()
            let quotes = try await loadedQuotes
            clock = try await loadedClock
            appendSamples(from: quotes, timestamp: timestamp)
            lastUpdated = timestamp
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func appendSamples(from response: MultiQuoteResponse, timestamp: Date) {
        let newSamples = trackedMarkets.compactMap { market -> MarketSample? in
            guard let quote = response.quotes[market.quoteSymbol] else { return nil }
            return MarketSample(market: market, timestamp: timestamp, value: quote.midPrice)
        }

        samples.append(contentsOf: newSamples)
        samples = samples
            .filter { $0.timestamp >= Date().addingTimeInterval(-7_200) }
            .suffix(360)
            .map { $0 }
    }

    private func latestSample(for market: MarketIndex) -> MarketSample? {
        samples.last { $0.market == market }
    }

    private func firstSample(for market: MarketIndex) -> MarketSample? {
        samples.first { $0.market == market }
    }

    private func normalizedChangePercent(for sample: MarketSample) -> Double {
        guard let firstValue = firstSample(for: sample.market)?.value, firstValue != 0 else { return 0 }
        return ((sample.value - firstValue) / firstValue) * 100
    }

    private func changePercent(for market: MarketIndex) -> Double? {
        guard let sample = latestSample(for: market) else { return nil }
        return normalizedChangePercent(for: sample)
    }
}

private struct MarketIndex: Hashable, Identifiable {
    let name: String
    let quoteSymbol: String
    let symbolName: String

    var id: String { quoteSymbol }

    static let tracked = [
        MarketIndex(name: "NASDAQ Composite", quoteSymbol: "QQQ", symbolName: "QQQ"),
        MarketIndex(name: "Dow Jones Industrials", quoteSymbol: "DIA", symbolName: "DIA"),
        MarketIndex(name: "S&P 500", quoteSymbol: "SPY", symbolName: "SPY")
    ]
}

private struct MarketSample: Identifiable {
    let id = UUID()
    let market: MarketIndex
    let timestamp: Date
    let value: Double
}

private struct MarketClockSummary: View {
    let clock: MarketClock
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(clock.isOpen ? "Market Open" : "Market Closed", systemImage: clock.isOpen ? "checkmark.circle.fill" : "moon.fill")
                    .font(.headline)
                    .foregroundStyle(clock.isOpen ? .green : .secondary)

                Spacer()

                if let lastUpdated {
                    Text(lastUpdated, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Next Open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(clock.nextOpen)
                        .font(.subheadline)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Next Close")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(clock.nextClose)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MarketIndexRow: View {
    let market: MarketIndex
    let sample: MarketSample?
    let changePercent: Double?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(market.name)
                    .font(.headline)
                Text(market.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(sample.map { TraderUIFormatting.currency($0.value) } ?? "--")
                    .font(.headline.monospacedDigit())

                if let changePercent {
                    Text(TraderUIFormatting.percent(changePercent))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(changePercent < 0 ? .red : .green)
                } else {
                    Text("--")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        )
    }
}

#Preview {
    MarketDataView()
}
