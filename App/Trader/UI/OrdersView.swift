import SwiftUI

struct OrdersView: View {
    private let statuses = ["open", "closed", "all"]

    @State private var orders: [Order] = []
    @State private var status = "open"
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && orders.isEmpty {
                    ProgressView("Loading orders")
                } else if orders.isEmpty {
                    ContentUnavailableView("No Orders", systemImage: "list.bullet.rectangle", description: Text("Orders matching the selected status will appear here."))
                } else {
                    List(orders) { order in
                        OrderRow(order: order)
                    }
                    .refreshable {
                        await loadOrders()
                    }
                }
            }
            .navigationTitle("Orders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Status", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: status) { _, _ in
                        Task { await loadOrders() }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadOrders() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Refresh orders")
                }
            }
            .task {
                await loadOrders()
            }
            .alert("Orders Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unable to load orders.")
            }
        }
    }

    private func loadOrders() async {
        isLoading = true
        defer { isLoading = false }

        do {
            orders = try await TradingService.listOrders(status: status, limit: 50, direction: "desc")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct OrderRow: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(order.symbol)
                    .font(.headline)
                Spacer()
                Text(order.status.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(order.isOpen ? .blue : .secondary)
            }

            HStack {
                Text(order.side.capitalized)
                Text(order.type.capitalized)
                Text(order.timeInForce.uppercased())
                Spacer()
                Text(order.qty ?? order.notional ?? "-")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text(order.createdAt ?? order.submittedAt ?? order.id)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    OrdersView()
}
