import Foundation

struct ExtractedExpense: Codable {
    var merchantName: String?
    var transactionDate: String?
    var totalAmount: Double?
    var currency: String?
    var lineItems: [ExtractedLineItem]?
    var paymentMethod: String?
    var category: String?
    var notes: String?

    private enum CodingKeys: String, CodingKey {
        case merchantName = "merchant_name"
        case transactionDate = "transaction_date"
        case totalAmount = "total_amount"
        case currency
        case lineItems = "line_items"
        case paymentMethod = "payment_method"
        case category
        case notes
    }

    func toExpense() -> Expense {
        let parsedDate: Date
        if let dateString = transactionDate {
            parsedDate = DateFormatters.iso8601.date(from: dateString)
                ?? DateFormatters.displayDate.date(from: dateString)
                ?? Date()
        } else {
            parsedDate = Date()
        }

        let parsedCategory = ExpenseCategory.allCases.first {
            $0.rawValue.lowercased() == (category ?? "").lowercased()
        } ?? .other

        let parsedLineItems = (lineItems ?? []).map { extracted in
            LineItem(
                itemDescription: extracted.description ?? "Unknown item",
                amount: extracted.amount ?? 0
            )
        }

        return Expense(
            merchantName: merchantName ?? "Unknown Merchant",
            transactionDate: parsedDate,
            totalAmount: totalAmount ?? 0,
            currency: currency ?? "CAD",
            lineItems: parsedLineItems,
            paymentMethod: paymentMethod,
            category: parsedCategory,
            notes: notes,
            uploadStatus: .pending
        )
    }
}

struct ExtractedLineItem: Codable {
    var description: String?
    var amount: Double?
}
