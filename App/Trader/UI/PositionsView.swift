import SwiftUI

struct PositionsView: View {
    @State private var positions: [Position] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && positions.isEmpty {
                    ProgressView("Loading positions")
                } else if positions.isEmpty {
                    ContentUnavailableView("No Positions", systemImage: "chart.pie", description: Text("Open positions will appear here."))
                } else {
                    List(positions) { position in
                        PositionRow(position: position)
                    }
                    .refreshable {
                        await loadPositions()
                    }
                }
            }
            .navigationTitle("Positions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadPositions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Refresh positions")
                }
            }
            .task {
                await loadPositions()
            }
            .alert("Positions Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unable to load positions.")
            }
        }
    }

    private func loadPositions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            positions = try await TradingService.getPositions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PositionRow: View {
    let position: Position

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(position.symbol)
                    .font(.headline)
                Spacer()
                Text(TraderUIFormatting.currency(position.marketValueDouble))
                    .font(.headline)
            }

            HStack {
                Label(position.side.capitalized, systemImage: "arrow.up.right")
                Spacer()
                Text("Qty \(position.qty)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack {
                Text("Avg \(TraderUIFormatting.currency(position.avgEntryPriceValue))")
                Spacer()
                Text("P/L \(TraderUIFormatting.signedCurrency(position.unrealizedPLValue))")
                    .foregroundStyle(position.unrealizedPLValue < 0 ? .red : .green)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PositionsView()
}
