import Foundation
import Network

final class UploadQueueService: ObservableObject {

    @Published private(set) var isOnline = true

    private let authService: AuthService
    private let driveService: GoogleDriveService
    private let sheetsService: GoogleSheetsService
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "ledgr.network.monitor")
    private let maxRetries = 3

    private var queue: [PendingUpload] = []
    private var isProcessing = false

    init(
        authService: AuthService,
        driveService: GoogleDriveService,
        sheetsService: GoogleSheetsService
    ) {
        self.authService = authService
        self.driveService = driveService
        self.sheetsService = sheetsService
        self.monitor = NWPathMonitor()

        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Public

    func enqueue(expense: Expense, imageData: Data) {
        let pending = PendingUpload(expense: expense, imageData: imageData)
        queue.append(pending)

        if isOnline {
            Task { await processQueue() }
        }
    }

    @MainActor
    func processQueue() async {
        guard !isProcessing, isOnline, !queue.isEmpty else { return }
        isProcessing = true

        defer { isProcessing = false }

        while let index = queue.firstIndex(where: { $0.status == .pending }) {
            queue[index].status = .uploading

            do {
                try await processUpload(&queue[index])
                queue[index].status = .complete
            } catch {
                queue[index].retryCount += 1
                if queue[index].retryCount >= maxRetries {
                    queue[index].status = .permanentlyFailed
                    queue[index].lastError = error.localizedDescription
                } else {
                    queue[index].status = .pending
                }
            }
        }
    }

    var pendingCount: Int {
        queue.filter { $0.status == .pending || $0.status == .uploading }.count
    }

    var failedUploads: [PendingUpload] {
        queue.filter { $0.status == .permanentlyFailed }
    }

    func retryFailed(id: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        queue[index].status = .pending
        queue[index].retryCount = 0

        if isOnline {
            Task { await processQueue() }
        }
    }

    func removeFailed(id: UUID) {
        queue.removeAll { $0.id == id }
    }

    // MARK: - Private: Processing

    private func processUpload(_ upload: inout PendingUpload) async throws {
        let accessToken = try await authService.getAccessToken()

        // Ensure Drive folder exists
        let folderId = try await driveService.ensureFolder(accessToken: accessToken)

        // Build file name
        let fileName = GoogleDriveService.buildFileName(
            date: upload.expense.transactionDate,
            merchantName: upload.expense.merchantName,
            amount: upload.expense.totalAmount
        )

        // Upload to Drive
        let (fileId, webViewLink) = try await driveService.uploadReceipt(
            imageData: upload.imageData,
            fileName: fileName,
            folderId: folderId,
            accessToken: accessToken
        )

        upload.expense.driveFileId = fileId
        upload.expense.driveFileURL = webViewLink

        // Ensure spreadsheet exists
        let spreadsheetId = try await sheetsService.ensureSpreadsheet(accessToken: accessToken)

        // Append to Sheets
        try await sheetsService.appendExpense(
            upload.expense,
            receiptLink: webViewLink,
            accessToken: accessToken,
            spreadsheetId: spreadsheetId
        )

        upload.expense.uploadStatus = .complete
    }

    // MARK: - Private: Network Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let online = path.status == .satisfied
            Task { @MainActor in
                self.isOnline = online
                if online {
                    await self.processQueue()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
}

// MARK: - Pending Upload Model

struct PendingUpload: Identifiable {
    let id: UUID
    var expense: Expense
    let imageData: Data
    var retryCount: Int
    var status: PendingUploadStatus
    var lastError: String?

    init(expense: Expense, imageData: Data) {
        self.id = UUID()
        self.expense = expense
        self.imageData = imageData
        self.retryCount = 0
        self.status = .pending
    }
}

enum PendingUploadStatus {
    case pending
    case uploading
    case complete
    case permanentlyFailed
}
