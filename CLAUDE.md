# CLAUDE.md – Ledgr Project Guide

## Project Overview
Ledgr is an iOS expense tracking app built with Swift and SwiftUI. Users photograph receipts, 
which are processed by the Anthropic Claude API for data extraction, stored in Google Drive, 
and logged to Google Sheets. This file guides Claude Code through architecture decisions, 
coding conventions, and implementation priorities.

---

## Development Philosophy
- Prefer clarity over cleverness — this codebase should be easy to maintain
- Services should be independently testable and loosely coupled
- Never hardcode API keys, credentials, or IDs — always use Keychain or UserDefaults
- Handle errors gracefully — the app should never crash silently
- Offline-first mindset — queue operations when network is unavailable

---

## Architecture

### Pattern: MVVM + Service Layer
- Views are dumb — no business logic in SwiftUI views
- ViewModels handle state and coordinate with Services
- Services are singleton classes injected via @EnvironmentObject or initializer
- Models are plain Swift structs conforming to Codable and Identifiable

### Dependency Flow
Views → ViewModels → Services → External APIs
Views → ViewModels → SwiftData (local cache)

---

## Project Structure
```
Ledgr/
├── App/
│   ├── LedgrApp.swift
│   └── AppDependencies.swift        # Service container / DI setup
├── Models/
│   ├── Expense.swift                # Core expense model
│   ├── LineItem.swift
│   ├── ExpenseCategory.swift        # Enum with all categories
│   └── UploadStatus.swift           # Enum: pending, uploading, complete, failed
├── ViewModels/
│   ├── CameraViewModel.swift
│   ├── ReviewViewModel.swift
│   ├── HistoryViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── Home/
│   │   └── HomeView.swift           # Main camera trigger screen
│   ├── Camera/
│   │   └── CameraView.swift
│   ├── Review/
│   │   ├── ReviewView.swift         # Edit extracted fields before saving
│   │   └── LineItemRowView.swift
│   ├── History/
│   │   ├── HistoryView.swift
│   │   └── ExpenseRowView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Shared/
│       ├── LoadingView.swift
│       ├── ErrorView.swift
│       └── CategoryBadgeView.swift
├── Services/
│   ├── LLMService.swift             # Anthropic API integration
│   ├── GoogleDriveService.swift     # Drive upload + folder management
│   ├── GoogleSheetsService.swift    # Sheet creation + row append
│   ├── AuthService.swift            # Google OAuth flow
│   └── UploadQueueService.swift     # Offline queue management
├── Utilities/
│   ├── KeychainManager.swift        # Secure credential storage
│   ├── ImageProcessor.swift         # Resize/compress before upload
│   ├── DateFormatters.swift
│   └── Constants.swift              # API endpoints, sheet columns, folder names
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

---

## Coding Conventions

### Swift Style
- Use `async/await` for all asynchronous operations — no completion handlers
- Use `Result<Success, Failure>` for service return types where appropriate
- Mark all service methods as `@MainActor` where they update published state
- Prefer `guard let` over nested `if let`
- Use `private` by default, loosen access only when required

### Naming
- ViewModels suffix: `ViewModel` (e.g. `ReviewViewModel`)
- Services suffix: `Service` (e.g. `GoogleDriveService`)
- Enums use PascalCase cases (e.g. `ExpenseCategory.foodAndDining`)
- Constants in `Constants.swift` as static let grouped by context

### Error Handling
- Define a custom `LedgrError` enum conforming to `LocalizedError`
- Every service method must propagate errors — no silent failures
- ViewModels catch service errors and expose them as `@Published var errorMessage: String?`

---

## Key Models

### Expense
```swift
struct Expense: Identifiable, Codable {
    let id: UUID
    var merchantName: String
    var transactionDate: Date
    var totalAmount: Double
    var currency: String          // ISO 4217 e.g. "CAD", "USD"
    var lineItems: [LineItem]
    var paymentMethod: String?
    var category: ExpenseCategory
    var notes: String?
    var receiptImageURL: String?  // Local file path before upload
    var driveFileURL: String?     // Google Drive link after upload
    var driveFileId: String?
    var sheetsRowId: Int?
    var uploadStatus: UploadStatus
    var createdAt: Date
}
```

### ExpenseCategory
```swift
enum ExpenseCategory: String, Codable, CaseIterable {
    case foodAndDining = "Food & Dining"
    case travel = "Travel"
    case officeSupplies = "Office Supplies"
    case entertainment = "Entertainment"
    case utilities = "Utilities"
    case health = "Health"
    case shopping = "Shopping"
    case other = "Other"
}
```

---

## Service Implementation Notes

### LLMService
- Use Anthropic Messages API endpoint: `https://api.anthropic.com/v1/messages`
- Model: `claude-sonnet-4-6` (configurable via Constants)
- Send receipt image as base64 encoded JPEG in the messages content array
- Compress image to max 1MB before encoding to stay within API limits
- Parse response JSON into an `ExtractedExpense` struct
- If parsing fails, return a partially populated struct so user can fill in manually
- Store API key retrieved from Keychain, never from UserDefaults

### GoogleDriveService
- Authenticate using Google Sign-In SDK token
- On first run, check for existing "Ledgr" folder; create if absent; store folder ID in UserDefaults
- Upload using multipart upload with metadata + JPEG body
- File naming: `YYYY-MM-DD_MerchantName_Amount.jpg` (sanitize merchant name for filesystem)
- After upload, set file permission to "reader" for anyone with link
- Return the `webViewLink` as the shareable receipt URL

### GoogleSheetsService
- On first run, create spreadsheet named "Ledgr Expenses"; store spreadsheet ID in UserDefaults
- Write header row on creation:
  `Date | Merchant | Category | Amount | Currency | Payment Method | Line Items | Notes | Receipt Link | Added At`
- Append rows using `valueInputOption=USER_ENTERED` so the receipt link renders as a hyperlink
- Format receipt link as `=HYPERLINK("url","View Receipt")` for clean display in Sheets

### UploadQueueService
- Persist pending uploads to SwiftData
- Monitor network connectivity using `NWPathMonitor`
- Retry failed uploads in order when connectivity is restored
- Max 3 retry attempts before marking as permanently failed and alerting user

### AuthService
- Use Google Sign-In SDK
- Request scopes: `drive.file` and `spreadsheets` only — minimum necessary permissions
- Store tokens securely; refresh silently on expiry
- Expose `@Published var isAuthenticated: Bool`

---

## Implementation Phases

Work through these phases in order. Complete and test each phase before moving to the next.

### Phase 1 – Foundation
- [ ] Project setup, folder structure, Constants.swift
- [ ] KeychainManager implementation
- [ ] LedgrError enum
- [ ] Core data models
- [ ] SwiftData schema and persistence layer

### Phase 2 – LLM Integration
- [ ] LLMService with Anthropic API
- [ ] ImageProcessor (compress, base64 encode)
- [ ] ExtractedExpense parsing
- [ ] Unit tests for JSON parsing edge cases

### Phase 3 – Google Integration
- [ ] AuthService + Google Sign-In setup
- [ ] GoogleDriveService (folder creation, upload, link retrieval)
- [ ] GoogleSheetsService (sheet creation, header row, append)
- [ ] UploadQueueService with offline support

### Phase 4 – UI
- [ ] HomeView with camera button
- [ ] CameraView + PhotosPicker
- [ ] ReviewView with editable extracted fields
- [ ] HistoryView with search and filter
- [ ] SettingsView

### Phase 5 – Polish
- [ ] Dark mode support
- [ ] Loading states and animations
- [ ] Error states and retry UI
- [ ] Accessibility (VoiceOver labels)
- [ ] App icon and launch screen

---

## Environment & Configuration

### Required API Keys (never commit these)
- `ANTHROPIC_API_KEY` — stored in Keychain under key `ledgr.anthropic.apikey`
- Google OAuth Client ID — stored in `Info.plist` as `GIDClientID`

### UserDefaults Keys (non-sensitive)
```swift
// In Constants.swift
struct UserDefaultsKeys {
    static let driveFolderId = "ledgr.drive.folderid"
    static let sheetsId = "ledgr.sheets.spreadsheetid"
    static let defaultCurrency = "ledgr.settings.currency"
    static let driveFolderName = "ledgr.settings.folderName"
    static let sheetsName = "ledgr.settings.sheetsName"
}
```

### Constants
```swift
struct APIConstants {
    static let anthropicEndpoint = "https://api.anthropic.com/v1/messages"
    static let anthropicModel = "claude-sonnet-4-6"
    static let driveUploadEndpoint = "https://www.googleapis.com/upload/drive/v3/files"
    static let sheetsBaseEndpoint = "https://sheets.googleapis.com/v4/spreadsheets"
    static let defaultDriveFolderName = "Ledgr/Receipts"
    static let defaultSheetsName = "Ledgr Expenses"
}
```

---

## Testing Guidelines
- Write unit tests for all Service classes using mock URL sessions
- Write unit tests for JSON parsing in LLMService
- Use SwiftUI Previews for all views with mock data
- Test offline queue behavior by toggling airplane mode in simulator

---

## Do Not
- Do not use third-party networking libraries — URLSession only
- Do not store any API keys or OAuth tokens in UserDefaults or source code
- Do not put business logic in SwiftUI Views
- Do not skip error handling — every async call must handle failure
- Do not use deprecated Google Sign-In APIs
- Do not block the main thread — all network calls must be async
```

---

**How to use it:** Drop this file as `CLAUDE.md` in the root of your Xcode project directory before starting a Claude Code session. Claude Code will pick it up automatically and use it as its north star throughout the project.

When you kick off the session, start with something like:
```
Read CLAUDE.md and then begin Phase 1 implementation. 
Start with Constants.swift, KeychainManager, and the core Models.