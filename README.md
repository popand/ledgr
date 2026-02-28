# Ledgr 📸💰

> Snap a receipt. Let AI do the rest.

Ledgr is a personal iOS expense tracking app that uses the Anthropic Claude API to extract
expense details from receipt photos, stores images in Google Drive, and logs every expense
to a Google Sheet — automatically.

---

## Features

- **Receipt Capture** – Take photos or pick from your library
- **AI-Powered Extraction** – Claude API reads merchant, amount, date, line items, and category
- **Auto-Categorization** – Expenses sorted into 8 categories (Food & Dining, Travel, Office Supplies, etc.)
- **Google Drive Backup** – Receipt images securely uploaded to your Google Drive
- **Google Sheets Logging** – Expenses automatically appended with hyperlinks to receipt images
- **Offline Support** – Upload queue persists pending expenses; retries when network returns
- **Local Search & Filter** – Browse and filter your expense history in the app
- **Secure Storage** – API keys and tokens stored in iOS Keychain, never in code or UserDefaults

---

## How It Works

1. **Snap** – Take a photo of any receipt using the in-app camera
2. **Extract** – Claude AI reads the receipt and pulls out merchant, amount, date, category, and line items
3. **Review** – Confirm or edit the extracted details before saving
4. **Sync** – Receipt image uploads to your Google Drive, expense details log to your Google Sheet
5. **Track** – Browse your full expense history with search, filter, and category summaries

---

## Screenshots

*Placeholder: Add screenshots here*
- Home screen with camera button
- Camera/photo picker interface
- Review & edit extracted expense data
- Expense history with filters
- Settings screen with API key entry

---

## Requirements

- **Xcode 15.0+** (includes Swift 5.9+)
- **iOS 17.0+** (deployment target)
- **Apple Developer Account** (for device testing and deployment)
- **Google Cloud Console Project** (for Drive & Sheets APIs)
- **Anthropic API Key** (for Claude vision processing)

---

## Setup Instructions

### 1. Google Cloud Console Setup

Follow these steps to enable Google Drive and Sheets APIs:

#### a. Create a Google Cloud Project
```bash
1. Go to https://console.cloud.google.com
2. Click the project dropdown at the top
3. Click "NEW PROJECT"
4. Enter "Ledgr" as the project name
5. Click "CREATE"
```

#### b. Enable APIs
```bash
1. Search for "Google Drive API" in the search bar
2. Click the result and press "ENABLE"
3. Search for "Google Sheets API"
4. Click the result and press "ENABLE"
```

#### c. Create OAuth 2.0 Credentials (iOS)
```bash
1. Go to "Credentials" in the left sidebar
2. Click "CREATE CREDENTIALS" > "OAuth 2.0 Client ID"
3. Select "iOS" as the application type
4. Enter your app's Bundle ID: com.yourcompany.Ledgr
   (Update this to match your actual bundle ID in Xcode)
5. Enter your app name (e.g., "Ledgr iOS")
6. Click "CREATE"
7. You'll see a Client ID and Bundle ID confirmation
8. Copy the Client ID — you'll use this next
```

#### d. Configure OAuth Consent Screen
```bash
1. Go to "OAuth consent screen" in the left sidebar
2. Select "External" as the user type
3. Click "CREATE"
4. Fill in the required fields:
   - App name: Ledgr
   - User support email: your-email@example.com
   - Developer contact: your-email@example.com
5. Click "SAVE AND CONTINUE"
6. On "Scopes" step, click "ADD OR REMOVE SCOPES"
7. Search for and select:
   - https://www.googleapis.com/auth/drive.file
   - https://www.googleapis.com/auth/spreadsheets
8. Click "UPDATE" and then "SAVE AND CONTINUE"
9. On "Test users" step, add your test account email
10. Review and click "BACK TO DASHBOARD"
```

#### e. Download Client Configuration
```bash
1. Go to Credentials
2. Under "OAuth 2.0 Client IDs", click your iOS app
3. Click "DOWNLOAD JSON"
4. Save this file — you may need it for reference
```

### 2. Configure Xcode Project

#### a. Update Bundle Identifier
```bash
1. Open Ledgr.xcodeproj in Xcode
2. Select the "Ledgr" target
3. Go to "Build Settings"
4. Search for "Bundle Identifier"
5. Change it to match your Google Cloud setup (e.g., com.yourcompany.Ledgr)
```

#### b. Add GIDClientID to Info.plist
```bash
1. Open Info.plist in Xcode
2. Add a new key: GIDClientID
3. Set the value to your OAuth Client ID from step 1c
4. Also add your URL scheme for OAuth redirect:
   - Add key: CFBundleURLTypes
   - Add item with CFBundleURLSchemes: [YOUR_CLIENT_ID.apps.googleusercontent.com]
```

#### c. Add Camera & Photo Library Permissions
```bash
Add to Info.plist:
- NSCameraUsageDescription: "Ledgr needs camera access to scan receipts"
- NSPhotoLibraryUsageDescription: "Ledgr needs access to your photo library to import receipts"
```

#### d. Add Google Sign-In via Swift Package Manager
```bash
1. In Xcode: File > Add Packages
2. Enter repository URL: https://github.com/google/GoogleSignIn-iOS.git
3. Set version to "7.1.0" (or latest)
4. Select "Ledgr" target
5. Click "Add Package"
```

### 3. Set Up Anthropic API Key

#### a. Create Account & Generate Key
```bash
1. Go to https://console.anthropic.com
2. Sign up or log in
3. Navigate to "API Keys"
4. Click "Create Key"
5. Name it "Ledgr iOS"
6. Copy the key (it will only show once)
```

#### b. Enter API Key in App
```bash
1. Build and run the app on simulator or device
2. Navigate to Settings screen
3. Paste your Anthropic API key
4. Tap "Save" — the app stores it securely in iOS Keychain
```

### 4. Running the App

```bash
# Clone the repository
git clone <your-repo-url>
cd Ledgr

# Open the Xcode project
open Ledgr.xcodeproj

# Select a simulator or device in the device menu
# Press Cmd+R to build and run
```

On first launch:
1. You'll be prompted to sign in with your Google account
2. Grant permissions for Google Drive and Google Sheets
3. Go to Settings and enter your Anthropic API key
4. You're ready to scan receipts!

---

## Architecture

### Pattern: MVVM + Service Layer

Ledgr uses a clean separation of concerns:

```
Views (SwiftUI)
    ↓
ViewModels (State & Coordination)
    ↓
Services (Business Logic)
    ↓
External APIs & Local Storage
```

**Views** are dumb UI components with no business logic.

**ViewModels** manage state (@Published properties) and coordinate between Views and Services.

**Services** handle API calls, data persistence, and external integrations. They're singletons injected via `@EnvironmentObject` or initializer.

### Project Structure

```
Ledgr/
├── App/
│   ├── LedgrApp.swift              # App entry point
│   └── AppDependencies.swift       # Service DI container
├── Models/
│   ├── Expense.swift               # Core expense data model
│   ├── LineItem.swift              # Line items within expenses
│   ├── ExpenseCategory.swift       # 8 expense categories (enum)
│   └── UploadStatus.swift          # pending, uploading, complete, failed
├── ViewModels/
│   ├── CameraViewModel.swift       # Handles camera & photo selection
│   ├── ReviewViewModel.swift       # Edits extracted expense fields
│   ├── HistoryViewModel.swift      # Lists & filters saved expenses
│   └── SettingsViewModel.swift     # Manages API keys & auth
├── Views/
│   ├── Home/
│   │   └── HomeView.swift          # Main screen with camera button
│   ├── Camera/
│   │   └── CameraView.swift        # Camera & photo picker
│   ├── Review/
│   │   ├── ReviewView.swift        # Edit extracted fields
│   │   └── LineItemRowView.swift   # Line item rows
│   ├── History/
│   │   ├── HistoryView.swift       # Expense list with search
│   │   └── ExpenseRowView.swift    # Individual expense row
│   ├── Settings/
│   │   └── SettingsView.swift      # API key entry, sign out
│   └── Shared/
│       ├── LoadingView.swift       # Loading spinner
│       ├── ErrorView.swift         # Error state UI
│       └── CategoryBadgeView.swift # Category display badge
├── Services/
│   ├── LLMService.swift            # Anthropic Claude API integration
│   ├── GoogleDriveService.swift    # Drive upload & folder management
│   ├── GoogleSheetsService.swift   # Sheets creation & row append
│   ├── AuthService.swift           # Google OAuth flow & token refresh
│   └── UploadQueueService.swift    # Offline queue & retry logic
├── Utilities/
│   ├── KeychainManager.swift       # Secure credential storage
│   ├── ImageProcessor.swift        # Image compression & encoding
│   ├── DateFormatters.swift        # Reusable date formatters
│   └── Constants.swift             # API endpoints & config
└── Resources/
    ├── Assets.xcassets             # App icons & images
    └── Info.plist                  # App metadata & permissions
```

---

## Google Sheets Template

When Ledgr creates a spreadsheet for the first time, it sets up a template with these columns:

| Date | Merchant | Category | Amount | Currency | Payment Method | Line Items | Notes | Receipt Link | Added At |
|------|----------|----------|--------|----------|-----------------|-----------|-------|--------------|----------|
| 2026-02-28 | Starbucks | Food & Dining | 5.50 | CAD | Credit Card | Coffee, Pastry | Morning coffee | [View Receipt] | 2026-02-28 10:30 AM |

**Receipt Link** is a HYPERLINK formula pointing to your receipt image on Google Drive. Click it to view the original receipt.

---

## Expense Categories

Ledgr organizes expenses into 8 categories:

- **Food & Dining** – Restaurants, cafes, delivery
- **Travel** – Gas, parking, flights, hotels, transit
- **Office Supplies** – Paper, pens, equipment
- **Entertainment** – Movies, events, games, books
- **Utilities** – Electric, water, internet
- **Health** – Doctor visits, pharmacy, gym
- **Shopping** – Retail, groceries, personal items
- **Other** – Anything that doesn't fit above

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **Language** | Swift 5.9+ |
| **UI Framework** | SwiftUI |
| **Local Storage** | SwiftData |
| **Networking** | URLSession (async/await) |
| **LLM API** | Anthropic Claude (Vision) |
| **Cloud Storage** | Google Drive API v3 |
| **Spreadsheet** | Google Sheets API v4 |
| **Authentication** | Google Sign-In SDK |
| **Photos** | PhotosUI |
| **Secure Storage** | iOS Keychain |
| **Connectivity** | Network framework (NWPathMonitor) |

---

## Privacy & Security

- **API Keys** – Anthropic keys stored in iOS Keychain, never in code
- **OAuth Tokens** – Managed securely by Google Sign-In SDK
- **Data** – Expenses are stored locally until explicitly uploaded
- **Third Parties** – Data only sent to Google (Drive/Sheets) and Anthropic (Claude API)
- **Receipt Images** – Stored in your own Google Drive folder, not Ledgr's servers
- **Permissions** – App requests only `drive.file` and `spreadsheets` scopes (minimal access)

---

## Offline Support

When your device is offline:

1. Photos are captured and expenses extracted locally
2. Uploads are queued in SwiftData
3. When connectivity returns, uploads resume automatically
4. App displays upload status for each expense (pending, uploading, complete, failed)
5. Failed uploads show an error and can be retried manually

---

## License

[MIT License](LICENSE)

---

## Getting Help

- **Google Cloud Issues?** Check [Google Cloud Console Docs](https://cloud.google.com/docs)
- **Anthropic API Issues?** See [Claude API Docs](https://docs.anthropic.com)
- **SwiftUI Questions?** Refer to [Apple SwiftUI Docs](https://developer.apple.com/xcode/swiftui/)

---

Built with Swift, SwiftUI, and Claude.