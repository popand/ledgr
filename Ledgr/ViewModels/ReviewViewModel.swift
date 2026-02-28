import Foundation
import SwiftUI
import SwiftData

@MainActor
final class ReviewViewModel: ObservableObject {

    // MARK: - Editable Fields

    @Published var merchantName = ""
    @Published var transactionDate = Date()
    @Published var totalAmount = ""
    @Published var currency = "CAD"
    @Published var paymentMethod = ""
    @Published var category: ExpenseCategory = .other
    @Published var notes = ""
    @Published var lineItems: [LineItem] = []

    // MARK: - State

    @Published var isProcessing = false
    @Published var processingStatus = ""
    @Published var errorMessage: String?
    @Published var isComplete = false

    // MARK: - Image

    private var imageData: Data?
    private var localImageURL: String?

    // MARK: - Dependencies

    private let llmService: LLMService
    private let driveService: GoogleDriveService
    private let sheetsService: GoogleSheetsService
    private let authService: AuthService

    init(
        llmService: LLMService,
        driveService: GoogleDriveService,
        sheetsService: GoogleSheetsService,
        authService: AuthService
    ) {
        self.llmService = llmService
        self.driveService = driveService
        self.sheetsService = sheetsService
        self.authService = authService
    }

    // MARK: - Extraction

    func extractFromImage(_ imageData: Data) async {
        self.imageData = imageData
        isProcessing = true
        processingStatus = "Analyzing receipt..."
        errorMessage = nil

        do {
            let extracted = try await llmService.extractExpense(from: imageData)
            populateFields(from: extracted)
            processingStatus = "Extraction complete"
        } catch {
            errorMessage = error.localizedDescription
            processingStatus = "Extraction failed"
        }

        isProcessing = false
    }

    private func populateFields(from extracted: ExtractedExpense) {
        merchantName = extracted.merchantName ?? ""

        if let dateString = extracted.transactionDate {
            transactionDate = DateFormatters.iso8601.date(from: dateString)
                ?? DateFormatters.displayDate.date(from: dateString)
                ?? Date()
        }

        if let amount = extracted.totalAmount {
            totalAmount = String(format: "%.2f", amount)
        }

        currency = extracted.currency ?? "CAD"
        paymentMethod = extracted.paymentMethod ?? ""

        category = ExpenseCategory.allCases.first {
            $0.rawValue.lowercased() == (extracted.category ?? "").lowercased()
        } ?? .other

        notes = extracted.notes ?? ""

        lineItems = (extracted.lineItems ?? []).map { item in
            LineItem(
                itemDescription: item.description ?? "Unknown item",
                amount: item.amount ?? 0
            )
        }
    }

    // MARK: - Save

    func saveExpense(modelContext: ModelContext) async {
        guard let parsedAmount = Double(totalAmount) else {
            errorMessage = "Invalid amount"
            return
        }

        isProcessing = true
        processingStatus = "Saving expense..."
        errorMessage = nil

        let expense = Expense(
            merchantName: merchantName,
            transactionDate: transactionDate,
            totalAmount: parsedAmount,
            currency: currency,
            lineItems: lineItems,
            paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
            category: category,
            notes: notes.isEmpty ? nil : notes,
            receiptImageURL: localImageURL,
            uploadStatus: .pending
        )

        modelContext.insert(expense)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save expense locally: \(error.localizedDescription)"
            isProcessing = false
            return
        }

        guard authService.isAuthenticated else {
            processingStatus = "Saved locally (sign in to Google to upload)"
            isProcessing = false
            isComplete = true
            return
        }

        // Upload to Drive
        var receiptLink = ""
        if let imageData {
            do {
                processingStatus = "Uploading receipt to Drive..."
                let token = try await authService.getAccessToken()
                let folderId = try await driveService.ensureFolder(accessToken: token)
                let driveResult = try await driveService.uploadReceipt(
                    imageData: imageData,
                    fileName: GoogleDriveService.buildFileName(
                        date: expense.transactionDate,
                        merchantName: expense.merchantName,
                        amount: expense.totalAmount
                    ),
                    folderId: folderId,
                    accessToken: token
                )
                expense.driveFileURL = driveResult.webViewLink
                expense.driveFileId = driveResult.fileId
                receiptLink = driveResult.webViewLink
            } catch {
                errorMessage = "Drive upload failed: \(error.localizedDescription)"
            }
        }

        // Append to Sheets
        do {
            processingStatus = "Logging to Google Sheets..."
            let token = try await authService.getAccessToken()
            let spreadsheetId = try await sheetsService.ensureSpreadsheet(accessToken: token)
            try await sheetsService.appendExpense(
                expense,
                receiptLink: receiptLink,
                accessToken: token,
                spreadsheetId: spreadsheetId
            )
            expense.uploadStatus = .complete
        } catch {
            if errorMessage == nil {
                errorMessage = "Sheets append failed: \(error.localizedDescription)"
            }
            expense.uploadStatus = .failed
        }

        try? modelContext.save()

        isProcessing = false
        if errorMessage == nil {
            isComplete = true
            processingStatus = "Expense saved successfully"
        }
    }

    // MARK: - Line Items

    func addLineItem() {
        lineItems.append(LineItem(itemDescription: "", amount: 0))
    }

    func removeLineItem(at offsets: IndexSet) {
        lineItems.remove(atOffsets: offsets)
    }

    func removeLineItem(id: UUID) {
        lineItems.removeAll { $0.id == id }
    }
}
