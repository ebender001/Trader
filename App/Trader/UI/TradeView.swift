import SwiftUI

struct TradeView: View {
    private let sides = ["buy", "sell"]
    private let orderTypes = ["market", "limit", "stop"]
    private let timeInForceOptions = ["day", "gtc", "ioc", "fok"]

    @State private var symbol = ""
    @State private var side = "buy"
    @State private var orderType = "market"
    @State private var timeInForce = "day"
    @State private var quantity = ""
    @State private var notional = ""
    @State private var limitPrice = ""
    @State private var stopPrice = ""
    @State private var extendedHours = false
    @State private var isSubmitting = false
    @State private var submittedOrder: Order?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Symbol") {
                    TextField("AAPL", text: $symbol)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section("Order") {
                    Picker("Side", selection: $side) {
                        ForEach(sides, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Picker("Type", selection: $orderType) {
                        ForEach(orderTypes, id: \.self) { Text($0.capitalized).tag($0) }
                    }

                    Picker("Time in Force", selection: $timeInForce) {
                        ForEach(timeInForceOptions, id: \.self) { Text($0.uppercased()).tag($0) }
                    }

                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)

                    TextField("Notional", text: $notional)
                        .keyboardType(.decimalPad)

                    if orderType == "limit" {
                        TextField("Limit Price", text: $limitPrice)
                            .keyboardType(.decimalPad)
                    }

                    if orderType == "stop" {
                        TextField("Stop Price", text: $stopPrice)
                            .keyboardType(.decimalPad)
                    }

                    Toggle("Extended Hours", isOn: $extendedHours)
                }

                Section {
                    Button {
                        Task { await submitOrder() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Label("Submit Order", systemImage: "paperplane.fill")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }

                if let submittedOrder {
                    Section("Submitted") {
                        LabeledContent("Symbol", value: submittedOrder.symbol)
                        LabeledContent("Side", value: submittedOrder.side.capitalized)
                        LabeledContent("Status", value: submittedOrder.status.capitalized)
                        LabeledContent("Price", value: TraderUIFormatting.optionalPrice(submittedOrder.limitPrice ?? submittedOrder.stopPrice))
                    }
                }
            }
            .navigationTitle("Trade")
            .alert("Order Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unable to submit order.")
            }
        }
    }

    private var canSubmit: Bool {
        !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !notional.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func submitOrder() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            submittedOrder = try await TradingService.placeOrder(
                symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                side: side,
                type: orderType,
                timeInForce: timeInForce,
                qty: nilIfEmpty(quantity),
                notional: nilIfEmpty(notional),
                limitPrice: orderType == "limit" ? nilIfEmpty(limitPrice) : nil,
                stopPrice: orderType == "stop" ? nilIfEmpty(stopPrice) : nil,
                extendedHours: extendedHours ? true : nil
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func nilIfEmpty(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

#Preview {
    TradeView()
}
