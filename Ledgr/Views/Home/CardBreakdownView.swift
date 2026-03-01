import SwiftUI
import SwiftData

struct CardBreakdownView: View {

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Expense.createdAt, order: .reverse) private var expenses: [Expense]

    private var groupedByPaymentMethod: [(method: String, expenses: [Expense], total: Double)] {
        let grouped = Dictionary(grouping: expenses) { $0.paymentMethod ?? "Unknown" }
        return grouped.map { (method: $0.key, expenses: $0.value, total: $0.value.reduce(0) { $0 + $1.totalAmount }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if expenses.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 16) {
                        ForEach(groupedByPaymentMethod, id: \.method) { group in
                            paymentMethodSection(group)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .background(Color.ledgrBackground.ignoresSafeArea())
            .navigationTitle("Payment Methods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.ledgrPrimary)
                }
            }
        }
    }

    private func paymentMethodSection(_ group: (method: String, expenses: [Expense], total: Double)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.ledgrPrimary.opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.ledgrPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.method)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ledgrDark)

                        Text("\(group.expenses.count) transaction\(group.expenses.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(Color.ledgrSecondaryText)
                    }
                }

                Spacer()

                Text(group.total, format: .currency(code: defaultCurrency))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.ledgrDark)
            }
            .padding(.bottom, 10)

            Divider()

            // Expense rows
            ForEach(Array(group.expenses.enumerated()), id: \.element.id) { index, expense in
                ExpenseRowView(expense: expense)

                if index < group.expenses.count - 1 {
                    Divider()
                        .padding(.leading, 58)
                }
            }
        }
        .cardStyle()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 32))
                .foregroundStyle(Color.ledgrSubtleText)

            Text("No expenses yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ledgrSecondaryText)

            Text("Scan a receipt to see payment method breakdowns")
                .font(.caption)
                .foregroundStyle(Color.ledgrSubtleText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var defaultCurrency: String {
        UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultCurrency) ?? "CAD"
    }
}

#Preview {
    CardBreakdownView()
        .modelContainer(for: Expense.self, inMemory: true)
}
