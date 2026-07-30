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
    private let chartWindow: TimeInterval = 7_200

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let clock {
                        MarketClockSummary(clock: clock, lastUpdated: lastUpdated)
                    }

                    marketCharts

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
                        Task { await refreshHistoricalMarketData() }
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
                await seedAndPollMarketData()
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

    private var marketCharts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Major Market ETFs")
                .font(.headline)

            ForEach(trackedMarkets) { market in
                MarketETFChart(
                    market: market,
                    samples: samples(for: market),
                    chartStart: chartStart,
                    chartEnd: chartEnd
                )
            }

            Text("QQQ, DIA, and SPY update every minute. The chart keeps the latest two hours and scrolls older samples off screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var chartEnd: Date {
        lastUpdated ?? Date()
    }

    private var chartStart: Date {
        chartEnd.addingTimeInterval(-chartWindow)
    }

    private func seedAndPollMarketData() async {
        await refreshHistoricalMarketData()

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: pollInterval)
                await loadLatestQuoteData()
            } catch {
                return
            }
        }
    }

    private func refreshHistoricalMarketData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let loadedClock = TradingService.getClock()
            async let loadedHistoricalSamples = historicalSamples()
            let historicalSamples = try await loadedHistoricalSamples
            clock = try await loadedClock
            samples = pruned(historicalSamples, at: Date())
            await loadLatestQuoteData()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadLatestQuoteData() async {
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

    private func historicalSamples() async throws -> [MarketSample] {
        let end = Date()
        let start = end.addingTimeInterval(-chartWindow)
        let startString = TraderUIFormatting.isoString(start)
        let endString = TraderUIFormatting.isoString(end)

        var loadedSamples: [MarketSample] = []

        for market in trackedMarkets {
            let response = try await TradingService.getBars(
                symbol: market.quoteSymbol,
                timeframe: "1Min",
                start: startString,
                end: endString,
                limit: 180,
                adjustment: "raw"
            )

            loadedSamples.append(contentsOf: response.bars.compactMap { bar in
                guard let timestamp = TraderUIFormatting.date(from: bar.timestamp) else { return nil }
                return MarketSample(market: market, timestamp: timestamp, value: bar.close)
            })
        }

        return loadedSamples.sorted { $0.timestamp < $1.timestamp }
    }

    private func appendSamples(from response: MultiQuoteResponse, timestamp: Date) {
        let newSamples = trackedMarkets.compactMap { market -> MarketSample? in
            guard let quote = response.quotes[market.quoteSymbol] else { return nil }
            return MarketSample(market: market, timestamp: timestamp, value: quote.midPrice)
        }

        samples.append(contentsOf: newSamples)
        samples = pruned(samples, at: timestamp)
    }

    private func pruned(_ samples: [MarketSample], at timestamp: Date) -> [MarketSample] {
        samples
            .filter { $0.timestamp >= timestamp.addingTimeInterval(-chartWindow) }
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(360)
            .map { $0 }
    }

    private func latestSample(for market: MarketIndex) -> MarketSample? {
        samples.last { $0.market == market }
    }

    private func samples(for market: MarketIndex) -> [MarketSample] {
        samples.filter { $0.market == market }
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
    let color: Color

    var id: String { quoteSymbol }

    static let tracked = [
        MarketIndex(name: "NASDAQ Composite", quoteSymbol: "QQQ", color: .blue),
        MarketIndex(name: "Dow Jones Industrials", quoteSymbol: "DIA", color: .orange),
        MarketIndex(name: "S&P 500", quoteSymbol: "SPY", color: .green)
    ]
}

private struct MarketSample: Identifiable {
    let id = UUID()
    let market: MarketIndex
    let timestamp: Date
    let value: Double
}

private struct MarketETFChart: View {
    let market: MarketIndex
    let samples: [MarketSample]
    let chartStart: Date
    let chartEnd: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(market.quoteSymbol)
                        .font(.headline)
                        .foregroundStyle(market.color)
                    Text(market.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let latest = samples.last {
                    Text(TraderUIFormatting.currency(latest.value))
                        .font(.headline.monospacedDigit())
                }
            }

            Chart(samples) { sample in
                BarMark(
                    x: .value("Time", sample.timestamp),
                    yStart: .value("Baseline", valueDomain.lowerBound),
                    yEnd: .value("Value", sample.value)
                )
                .foregroundStyle(market.color)
            }
            .frame(height: 160)
            .chartXScale(domain: chartStart...chartEnd)
            .chartYScale(domain: valueDomain)
            .chartYAxisLabel("Value")
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let value = value.as(Double.self) {
                            Text(TraderUIFormatting.currency(value))
                        }
                    }
                }
            }
            .overlay {
                if samples.isEmpty {
                    ContentUnavailableView("No \(market.quoteSymbol) Samples", systemImage: "chart.bar", description: Text("Samples will appear after the next refresh."))
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

    private var valueDomain: ClosedRange<Double> {
        let values = samples.map(\.value)
        guard let minimumValue = values.min(), let maximumValue = values.max() else {
            return 0...1
        }

        let span = maximumValue - minimumValue
        let padding = max(span * 0.15, max(maximumValue * 0.0025, 0.01))
        return (minimumValue - padding)...(maximumValue + padding)
    }
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
                    Text(TraderUIFormatting.dateTime(clock.nextOpen))
                        .font(.subheadline)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Next Close")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(TraderUIFormatting.dateTime(clock.nextClose))
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
                Text(market.quoteSymbol)
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
