import Foundation
import SwiftUI
import SwiftData

@MainActor
final class HistoryViewModel: ObservableObject {

    @Published var expenses: [Expense] = []
    @Published var searchText = ""
    @Published var selectedCategory: ExpenseCategory?
    @Published var startDate: Date?
    @Published var endDate: Date?

    var filteredExpenses: [Expense] {
        var result = expenses

        if !searchText.isEmpty {
            result = result.filter {
                $0.merchantName.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if let start = startDate {
            result = result.filter { $0.transactionDate >= start }
        }

        if let end = endDate {
            result = result.filter { $0.transactionDate <= end }
        }

        return result.sorted { $0.transactionDate > $1.transactionDate }
    }

    var categoryTotals: [(ExpenseCategory, Double)] {
        var totals: [ExpenseCategory: Double] = [:]
        for expense in filteredExpenses {
            totals[expense.category, default: 0] += expense.totalAmount
        }
        return totals.sorted { $0.key.rawValue < $1.key.rawValue }
    }

    var monthlyTotals: [(String, Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        var totals: [String: Double] = [:]
        var dateMap: [String: Date] = [:]

        for expense in filteredExpenses {
            let key = formatter.string(from: expense.transactionDate)
            totals[key, default: 0] += expense.totalAmount
            if dateMap[key] == nil {
                dateMap[key] = expense.transactionDate
            }
        }

        return totals.sorted { lhs, rhs in
            (dateMap[lhs.0] ?? .distantPast) > (dateMap[rhs.0] ?? .distantPast)
        }
    }

    var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.totalAmount }
    }

    func loadExpenses(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Expense>(
            sortBy: [SortDescriptor(\.transactionDate, order: .reverse)]
        )
        do {
            expenses = try modelContext.fetch(descriptor)
        } catch {
            expenses = []
        }
    }

    func deleteExpense(_ expense: Expense, modelContext: ModelContext) {
        modelContext.delete(expense)
        try? modelContext.save()
        loadExpenses(modelContext: modelContext)
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        startDate = nil
        endDate = nil
    }
}
