import Foundation
import SwiftData

@Model
final class Expense: Identifiable {
    @Attribute(.unique) var id: UUID
    var merchantName: String
    var transactionDate: Date
    var totalAmount: Double
    var currency: String
    var lineItemsData: Data?
    var paymentMethod: String?
    var categoryRawValue: String
    var notes: String?
    var receiptImageURL: String?
    var driveFileURL: String?
    var driveFileId: String?
    var sheetsRowId: Int?
    var uploadStatusRawValue: String
    var createdAt: Date

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var uploadStatus: UploadStatus {
        get { UploadStatus(rawValue: uploadStatusRawValue) ?? .pending }
        set { uploadStatusRawValue = newValue.rawValue }
    }

    var lineItems: [LineItem] {
        get {
            guard let data = lineItemsData else { return [] }
            return (try? JSONDecoder().decode([LineItem].self, from: data)) ?? []
        }
        set {
            lineItemsData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: UUID = UUID(),
        merchantName: String,
        transactionDate: Date,
        totalAmount: Double,
        currency: String = "CAD",
        lineItems: [LineItem] = [],
        paymentMethod: String? = nil,
        category: ExpenseCategory = .other,
        notes: String? = nil,
        receiptImageURL: String? = nil,
        driveFileURL: String? = nil,
        driveFileId: String? = nil,
        sheetsRowId: Int? = nil,
        uploadStatus: UploadStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.merchantName = merchantName
        self.transactionDate = transactionDate
        self.totalAmount = totalAmount
        self.currency = currency
        self.lineItemsData = try? JSONEncoder().encode(lineItems)
        self.paymentMethod = paymentMethod
        self.categoryRawValue = category.rawValue
        self.notes = notes
        self.receiptImageURL = receiptImageURL
        self.driveFileURL = driveFileURL
        self.driveFileId = driveFileId
        self.sheetsRowId = sheetsRowId
        self.uploadStatusRawValue = uploadStatus.rawValue
        self.createdAt = createdAt
    }
}
