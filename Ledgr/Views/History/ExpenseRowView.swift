import SwiftUI

struct ExpenseRowView: View {

    let expense: Expense

    var body: some View {
        HStack(spacing: 14) {
            // Circular category icon
            CategoryBadgeView(category: expense.category, style: .icon)

            // Merchant info
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.merchantName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ledgrDark)
                    .lineLimit(1)

                Text(DateFormatters.displayDate.string(from: expense.transactionDate))
                    .font(.caption)
                    .foregroundStyle(Color.ledgrSecondaryText)
            }

            Spacer()

            // Amount and status
            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedAmount)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.ledgrDark)

                statusIndicator
            }
        }
        .padding(.vertical, 6)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = expense.currency
        return formatter.string(from: NSNumber(value: expense.totalAmount)) ?? "$\(expense.totalAmount)"
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch expense.uploadStatus {
        case .complete:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                Text("Synced")
            }
            .font(.caption2)
            .foregroundStyle(Color.ledgrSuccess)
        case .uploading:
            HStack(spacing: 3) {
                ProgressView()
                    .controlSize(.mini)
                Text("Uploading")
            }
            .font(.caption2)
            .foregroundStyle(Color.ledgrPrimary)
        case .failed:
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.circle.fill")
                Text("Failed")
            }
            .font(.caption2)
            .foregroundStyle(Color.ledgrError)
        case .pending:
            HStack(spacing: 3) {
                Image(systemName: "clock.fill")
                Text("Pending")
            }
            .font(.caption2)
            .foregroundStyle(Color.ledgrWarning)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ExpenseRowView(expense: Expense(
            merchantName: "Starbucks Coffee",
            transactionDate: Date(),
            totalAmount: 12.50,
            category: .foodAndDining,
            uploadStatus: .complete
        ))
        Divider().padding(.leading, 58)
        ExpenseRowView(expense: Expense(
            merchantName: "Uber Technologies",
            transactionDate: Date().addingTimeInterval(-86400),
            totalAmount: 24.80,
            currency: "USD",
            category: .travel,
            uploadStatus: .pending
        ))
        Divider().padding(.leading, 58)
        ExpenseRowView(expense: Expense(
            merchantName: "Payroll Deposit",
            transactionDate: Date(),
            totalAmount: 4250.00,
            category: .other,
            uploadStatus: .complete
        ))
    }
    .padding()
    .cardStyle()
    .padding()
    .background(Color.ledgrBackground)
}
