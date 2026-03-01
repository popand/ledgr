import Foundation

final class GoogleSheetsService: ObservableObject {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Spreadsheet Management

    func ensureSpreadsheet(accessToken: String) async throws -> String {
        // Check cached spreadsheet ID
        if let cachedId = UserDefaults.standard.string(forKey: UserDefaultsKeys.sheetsId),
           !cachedId.isEmpty {
            return cachedId
        }

        let spreadsheetName = UserDefaults.standard.string(forKey: UserDefaultsKeys.sheetsName)
            ?? APIConstants.defaultSheetsName

        let spreadsheetId = try await createSpreadsheet(named: spreadsheetName, accessToken: accessToken)
        UserDefaults.standard.set(spreadsheetId, forKey: UserDefaultsKeys.sheetsId)

        try await writeHeaderRow(spreadsheetId: spreadsheetId, accessToken: accessToken)

        return spreadsheetId
    }

    // MARK: - Read Expenses

    func readExpenses(spreadsheetId: String, accessToken: String) async throws -> [[String]] {
        let range = "Sheet1!A:J"
        guard let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(APIConstants.sheetsBaseEndpoint)/\(spreadsheetId)/values/\(encodedRange)") else {
            throw LedgrError.sheetsReadFailed("Invalid read URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LedgrError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw LedgrError.sheetsReadFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = json["values"] as? [[String]] else {
            return []
        }

        return values
    }

    // MARK: - Append Expense

    func appendExpense(
        _ expense: Expense,
        receiptLink: String,
        accessToken: String,
        spreadsheetId: String
    ) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let addedAtFormatter = ISO8601DateFormatter()

        let lineItemsSummary = expense.lineItems
            .map { "\($0.itemDescription): $\(String(format: "%.2f", $0.amount))" }
            .joined(separator: "; ")

        let hyperlinkFormula = "=HYPERLINK(\"\(receiptLink)\",\"View Receipt\")"

        let row: [Any] = [
            dateFormatter.string(from: expense.transactionDate),
            expense.merchantName,
            expense.category.rawValue,
            expense.totalAmount,
            expense.currency,
            expense.paymentMethod ?? "",
            lineItemsSummary,
            expense.notes ?? "",
            hyperlinkFormula,
            addedAtFormatter.string(from: Date())
        ]

        try await appendRow(
            values: row,
            spreadsheetId: spreadsheetId,
            accessToken: accessToken
        )
    }

    // MARK: - Delete Expense Row

    func deleteExpenseRow(
        merchantName: String,
        date: Date,
        amount: Double,
        spreadsheetId: String,
        accessToken: String
    ) async throws {
        let rows = try await readExpenses(spreadsheetId: spreadsheetId, accessToken: accessToken)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let targetDate = dateFormatter.string(from: date)
        let targetAmount = String(format: "%.2f", amount)

        // Find matching row (skip header at index 0)
        var matchingRowIndex: Int?
        for (index, row) in rows.enumerated() {
            guard index > 0, row.count >= 4 else { continue }
            let rowDate = row[0]
            let rowMerchant = row[1]
            let rowAmount = String(format: "%.2f", Double(row[3]) ?? -1)

            if rowDate == targetDate && rowMerchant == merchantName && rowAmount == targetAmount {
                matchingRowIndex = index
                break
            }
        }

        guard let rowIndex = matchingRowIndex else {
            throw LedgrError.sheetsDeleteFailed("Could not find matching row for \(merchantName)")
        }

        // Delete the row using batchUpdate with deleteDimension
        guard let url = URL(string: "\(APIConstants.sheetsBaseEndpoint)/\(spreadsheetId):batchUpdate") else {
            throw LedgrError.sheetsDeleteFailed("Invalid batchUpdate URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "requests": [
                [
                    "deleteDimension": [
                        "range": [
                            "sheetId": 0,
                            "dimension": "ROWS",
                            "startIndex": rowIndex,
                            "endIndex": rowIndex + 1
                        ]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, context: "row deletion")
    }

    // MARK: - Private: Spreadsheet Creation

    private func createSpreadsheet(named name: String, accessToken: String) async throws -> String {
        guard let url = URL(string: APIConstants.sheetsBaseEndpoint) else {
            throw LedgrError.sheetsAppendFailed("Invalid Sheets API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "properties": [
                "title": name
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, context: "spreadsheet creation")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let spreadsheetId = json["spreadsheetId"] as? String else {
            throw LedgrError.sheetsAppendFailed("Missing spreadsheetId in creation response")
        }

        return spreadsheetId
    }

    // MARK: - Private: Row Operations

    private func writeHeaderRow(spreadsheetId: String, accessToken: String) async throws {
        try await appendRow(
            values: SheetColumns.headers,
            spreadsheetId: spreadsheetId,
            accessToken: accessToken
        )
    }

    private func appendRow(
        values: [Any],
        spreadsheetId: String,
        accessToken: String
    ) async throws {
        let range = "Sheet1!A:J"
        guard let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(APIConstants.sheetsBaseEndpoint)/\(spreadsheetId)/values/\(encodedRange):append?valueInputOption=USER_ENTERED") else {
            throw LedgrError.sheetsAppendFailed("Invalid append URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "values": [values]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, context: "row append")
    }

    // MARK: - Private: Validation

    private func validateHTTPResponse(_ response: URLResponse, data: Data, context: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LedgrError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw LedgrError.sheetsAppendFailed("\(context) failed (HTTP \(httpResponse.statusCode)): \(body)")
        }
    }
}
