import Foundation
import UIKit

final class LLMService: ObservableObject {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public

    func extractExpense(from imageData: Data) async throws -> ExtractedExpense {
        let apiKey = try loadAPIKey()
        let base64Image = ImageProcessor.base64Encode(imageData)
        let request = try buildRequest(apiKey: apiKey, base64Image: base64Image)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LedgrError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw LedgrError.llmExtractionFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        return try parseResponse(data)
    }

    // MARK: - Private

    private func loadAPIKey() throws -> String {
        guard let key = try KeychainManager.loadString(forKey: KeychainKeys.anthropicAPIKey),
              !key.isEmpty else {
            throw LedgrError.keychainError("Anthropic API key not found in Keychain")
        }
        return key
    }

    private func buildRequest(apiKey: String, base64Image: String) throws -> URLRequest {
        guard let url = URL(string: APIConstants.anthropicEndpoint) else {
            throw LedgrError.llmExtractionFailed("Invalid API endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let systemPrompt = """
            You are an expense tracking assistant. Analyze the receipt image and extract all \
            relevant expense information. Return ONLY a valid JSON object with fields: \
            merchant_name, transaction_date (ISO 8601), total_amount (float), currency (ISO 4217), \
            line_items (array of {description, amount}), payment_method, \
            category (one of: Food & Dining, Travel, Office Supplies, Entertainment, Utilities, \
            Health, Shopping, Other), and notes (brief description of the expense).
            """

        let body: [String: Any] = [
            "model": APIConstants.anthropicModel,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Extract the expense data from this receipt."
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseResponse(_ data: Data) throws -> ExtractedExpense {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw LedgrError.llmExtractionFailed("Unable to extract text from API response")
        }

        let jsonText = extractJSON(from: text)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LedgrError.llmExtractionFailed("Unable to encode extracted text as data")
        }

        do {
            return try JSONDecoder().decode(ExtractedExpense.self, from: jsonData)
        } catch {
            // Graceful fallback: return partially populated struct
            return ExtractedExpense(
                merchantName: nil,
                transactionDate: nil,
                totalAmount: nil,
                currency: nil,
                lineItems: nil,
                paymentMethod: nil,
                category: nil,
                notes: "Failed to parse receipt automatically. Please fill in manually."
            )
        }
    }

    private func extractJSON(from text: String) -> String {
        // Try to find JSON between ```json ... ``` markers
        if let jsonRange = text.range(of: "```json"),
           let endRange = text.range(of: "```", range: jsonRange.upperBound..<text.endIndex) {
            return String(text[jsonRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to find JSON between { and }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }

        return text
    }
}
