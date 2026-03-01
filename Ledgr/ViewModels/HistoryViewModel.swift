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

    private var defaultCurrency: String {
        UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultCurrency) ?? "CAD"
    }

    var totalsByCurrency: [(currency: String, total: Double)] {
        let grouped = Dictionary(grouping: filteredExpenses) { $0.currency }
        let result = grouped.map { (currency: $0.key, total: $0.value.reduce(0) { $0 + $1.totalAmount }) }
        return result.sorted { lhs, rhs in
            if lhs.currency == defaultCurrency { return true }
            if rhs.currency == defaultCurrency { return false }
            return lhs.currency < rhs.currency
        }
    }

    var primaryTotal: Double {
        totalsByCurrency.first { $0.currency == defaultCurrency }?.total ?? 0
    }

    var secondaryTotals: [(currency: String, total: Double)] {
        totalsByCurrency.filter { $0.currency != defaultCurrency }
    }

    var categoryTotalsByCurrency: [(category: ExpenseCategory, totals: [(currency: String, total: Double)])] {
        var map: [ExpenseCategory: [String: Double]] = [:]
        for expense in filteredExpenses {
            map[expense.category, default: [:]][expense.currency, default: 0] += expense.totalAmount
        }
        return map.map { category, currencyMap in
            let sorted = currencyMap.map { (currency: $0.key, total: $0.value) }
                .sorted { lhs, rhs in
                    if lhs.currency == defaultCurrency { return true }
                    if rhs.currency == defaultCurrency { return false }
                    return lhs.currency < rhs.currency
                }
            return (category: category, totals: sorted)
        }
        .sorted { $0.category.rawValue < $1.category.rawValue }
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
