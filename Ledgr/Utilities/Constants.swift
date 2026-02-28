import Foundation

struct APIConstants {
    static let anthropicEndpoint = "https://api.anthropic.com/v1/messages"
    static let anthropicModel = "claude-sonnet-4-6"
    static let driveUploadEndpoint = "https://www.googleapis.com/upload/drive/v3/files"
    static let sheetsBaseEndpoint = "https://sheets.googleapis.com/v4/spreadsheets"
    static let defaultDriveFolderName = "Ledgr/Receipts"
    static let defaultSheetsName = "Ledgr Expenses"
}

struct UserDefaultsKeys {
    static let driveFolderId = "ledgr.drive.folderid"
    static let sheetsId = "ledgr.sheets.spreadsheetid"
    static let defaultCurrency = "ledgr.settings.currency"
    static let driveFolderName = "ledgr.settings.folderName"
    static let sheetsName = "ledgr.settings.sheetsName"
}

struct KeychainKeys {
    static let anthropicAPIKey = "ledgr.anthropic.apikey"
}

struct SheetColumns {
    static let headers = [
        "Date",
        "Merchant",
        "Category",
        "Amount",
        "Currency",
        "Payment Method",
        "Line Items",
        "Notes",
        "Receipt Link",
        "Added At"
    ]
}
