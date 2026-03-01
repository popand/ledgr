import Foundation
import SwiftUI

@MainActor
final class InsightsViewModel: ObservableObject {

    enum State {
        case idle
        case loading
        case loaded([Insight])
        case error(String)
    }

    @Published private(set) var state: State = .idle

    private var llmService: LLMService?
    private var sheetsService: GoogleSheetsService?
    private var authService: AuthService?
    private var lastGenerationDate: Date?

    func configure(llmService: LLMService, sheetsService: GoogleSheetsService, authService: AuthService) {
        guard self.llmService == nil else { return }
        self.llmService = llmService
        self.sheetsService = sheetsService
        self.authService = authService
    }

    func generateInsights(localExpenses: [Expense]) async {
        // 60-second debounce
        if let lastDate = lastGenerationDate, Date().timeIntervalSince(lastDate) < 60 {
            return
        }

        state = .loading

        do {
            let summary = try await buildExpenseSummary(localExpenses: localExpenses)

            guard !summary.isEmpty else {
                state = .loaded([])
                return
            }

            guard let llmService else {
                state = .error("LLM service not configured")
                return
            }

            let insights = try await llmService.generateInsights(from: summary)
            lastGenerationDate = Date()
            state = .loaded(insights)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func buildExpenseSummary(localExpenses: [Expense]) async throws -> String {
        // Try Google Sheets first
        if let authService, authService.isAuthenticated,
           let spreadsheetId = UserDefaults.standard.string(forKey: UserDefaultsKeys.sheetsId),
           !spreadsheetId.isEmpty {
            do {
                let token = try await authService.getAccessToken()
                let rows = try await sheetsService?.readExpenses(
                    spreadsheetId: spreadsheetId,
                    accessToken: token
                ) ?? []
                if rows.count > 1 { // Has data beyond header row
                    return aggregateSheetsData(rows)
                }
            } catch {
                // Fall through to local data
            }
        }

        // Fall back to local SwiftData expenses
        guard !localExpenses.isEmpty else { return "" }
        return aggregateLocalExpenses(localExpenses)
    }

    private func aggregateSheetsData(_ rows: [[String]]) -> String {
        guard rows.count > 1 else { return "" }

        let headers = rows[0]
        let dataRows = Array(rows.dropFirst())

        let dateIdx = headers.firstIndex(of: "Date") ?? 0
        let merchantIdx = headers.firstIndex(of: "Merchant") ?? 1
        let categoryIdx = headers.firstIndex(of: "Category") ?? 2
        let amountIdx = headers.firstIndex(of: "Amount") ?? 3
        let currencyIdx = headers.firstIndex(of: "Currency") ?? 4

        var categoryTotals: [String: Double] = [:]
        var merchantCounts: [String: Int] = [:]
        var monthlyTotals: [String: Double] = [:]
        var totalSpent = 0.0
        var currency = "USD"

        for row in dataRows {
            guard row.count > amountIdx else { continue }

            let category = row.count > categoryIdx ? row[categoryIdx] : "Other"
            let amount = Double(row[amountIdx]) ?? 0
            let merchant = row.count > merchantIdx ? row[merchantIdx] : "Unknown"
            let date = row.count > dateIdx ? row[dateIdx] : ""
            if row.count > currencyIdx { currency = row[currencyIdx] }

            categoryTotals[category, default: 0] += amount
            merchantCounts[merchant, default: 0] += 1
            totalSpent += amount

            // Extract month (YYYY-MM) from date
            let monthKey = String(date.prefix(7))
            if !monthKey.isEmpty {
                monthlyTotals[monthKey, default: 0] += amount
            }
        }

        return formatSummary(
            totalExpenses: dataRows.count,
            totalSpent: totalSpent,
            currency: currency,
            categoryTotals: categoryTotals,
            merchantCounts: merchantCounts,
            monthlyTotals: monthlyTotals
        )
    }

    private func aggregateLocalExpenses(_ expenses: [Expense]) -> String {
        var categoryTotals: [String: Double] = [:]
        var merchantCounts: [String: Int] = [:]
        var monthlyTotals: [String: Double] = [:]
        var totalSpent = 0.0

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"

        let currency = expenses.first?.currency ?? "USD"

        for expense in expenses {
            categoryTotals[expense.category.rawValue, default: 0] += expense.totalAmount
            merchantCounts[expense.merchantName, default: 0] += 1
            totalSpent += expense.totalAmount

            let monthKey = monthFormatter.string(from: expense.transactionDate)
            monthlyTotals[monthKey, default: 0] += expense.totalAmount
        }

        return formatSummary(
            totalExpenses: expenses.count,
            totalSpent: totalSpent,
            currency: currency,
            categoryTotals: categoryTotals,
            merchantCounts: merchantCounts,
            monthlyTotals: monthlyTotals
        )
    }

    private func formatSummary(
        totalExpenses: Int,
        totalSpent: Double,
        currency: String,
        categoryTotals: [String: Double],
        merchantCounts: [String: Int],
        monthlyTotals: [String: Double]
    ) -> String {
        var lines: [String] = []
        lines.append("Total: \(totalExpenses) expenses, \(String(format: "%.2f", totalSpent)) \(currency)")

        lines.append("\nBy category:")
        for (cat, total) in categoryTotals.sorted(by: { $0.value > $1.value }) {
            lines.append("  \(cat): \(String(format: "%.2f", total)) \(currency)")
        }

        lines.append("\nMonthly totals:")
        for (month, total) in monthlyTotals.sorted(by: { $0.key > $1.key }).prefix(6) {
            lines.append("  \(month): \(String(format: "%.2f", total)) \(currency)")
        }

        lines.append("\nTop merchants:")
        for (merchant, count) in merchantCounts.sorted(by: { $0.value > $1.value }).prefix(5) {
            lines.append("  \(merchant): \(count) visits")
        }

        return lines.joined(separator: "\n")
    }
}
