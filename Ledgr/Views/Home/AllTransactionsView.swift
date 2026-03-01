import SwiftUI
import SwiftData

struct AllTransactionsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.createdAt, order: .reverse) private var expenses: [Expense]

    let authService: AuthService
    let driveService: GoogleDriveService
    let sheetsService: GoogleSheetsService

    @State private var expenseToDelete: Expense?
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if expenses.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                            ExpenseRowView(expense: expense)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        expenseToDelete = expense
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }

                            if index < expenses.count - 1 {
                                Divider()
                                    .padding(.leading, 58)
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .background(Color.ledgrBackground.ignoresSafeArea())
            .navigationTitle("All Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.ledgrPrimary)
                }
            }
            .alert("Delete Transaction", isPresented: .init(
                get: { expenseToDelete != nil },
                set: { if !$0 { expenseToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    expenseToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let expense = expenseToDelete {
                        Task { await deleteExpense(expense) }
                    }
                }
            } message: {
                if let expense = expenseToDelete {
                    Text("Are you sure you want to delete the \(expense.merchantName) transaction?")
                }
            }
            .alert("Delete Failed", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                if let message = errorMessage {
                    Text(message)
                }
            }
            .overlay {
                if isDeleting {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Deleting...")
                                .padding(24)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 32))
                .foregroundStyle(Color.ledgrSubtleText)

            Text("No transactions")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ledgrSecondaryText)

            Text("Your transactions will appear here")
                .font(.caption)
                .foregroundStyle(Color.ledgrSubtleText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func deleteExpense(_ expense: Expense) async {
        isDeleting = true
        defer {
            isDeleting = false
            expenseToDelete = nil
        }

        switch expense.uploadStatus {
        case .complete:
            do {
                let accessToken = try await authService.getAccessToken()

                // Delete from Google Sheets
                if let spreadsheetId = UserDefaults.standard.string(forKey: UserDefaultsKeys.sheetsId) {
                    try await sheetsService.deleteExpenseRow(
                        merchantName: expense.merchantName,
                        date: expense.transactionDate,
                        amount: expense.totalAmount,
                        spreadsheetId: spreadsheetId,
                        accessToken: accessToken
                    )
                }

                // Delete from Google Drive
                if let driveFileId = expense.driveFileId {
                    try await driveService.deleteFile(fileId: driveFileId, accessToken: accessToken)
                }

                // Delete local record
                modelContext.delete(expense)
                try modelContext.save()
            } catch {
                errorMessage = error.localizedDescription
            }

        case .pending, .uploading, .failed:
            modelContext.delete(expense)
            try? modelContext.save()
        }
    }
}

#Preview {
    AllTransactionsView(
        authService: AuthService(),
        driveService: GoogleDriveService(),
        sheetsService: GoogleSheetsService()
    )
    .modelContainer(for: Expense.self, inMemory: true)
}
