import SwiftUI
import PhotosUI
import SwiftData

struct HomeView: View {

    @Binding var selectedTab: Int
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = CameraViewModel()
    @Query(sort: \Expense.createdAt, order: .reverse) private var recentExpenses: [Expense]
    @State private var showReview = false
    @State private var showShareSheet = false
    @State private var showCardBreakdown = false
    @State private var csvFileURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    balanceCard
                    quickActions
                    aiInsightsSection
                    recentTransactions
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.ledgrBackground.ignoresSafeArea())
            .fullScreenCover(isPresented: $viewModel.isShowingCamera) {
                CameraView { image in
                    viewModel.handleCapturedImage(image)
                    viewModel.isShowingCamera = false
                    showReview = true
                }
            }
            .fullScreenCover(isPresented: $showReview) {
                if let imageData = viewModel.capturedImageData {
                    NavigationStack {
                        ReviewView(
                            imageData: imageData,
                            image: viewModel.selectedImage,
                            llmService: dependencies.llmService,
                            driveService: dependencies.googleDriveService,
                            sheetsService: dependencies.googleSheetsService,
                            authService: dependencies.authService
                        )
                    }
                }
            }
            .onChange(of: showReview) { _, isShowing in
                if !isShowing {
                    viewModel.clearSelection()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = csvFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $showCardBreakdown) {
                CardBreakdownView()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundStyle(Color.ledgrSecondaryText)

                Text("Andrei")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.ledgrDark)
            }

            Spacer()

            // Notification bell
            Button {} label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)

                    Image(systemName: "bell")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.ledgrDark)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Expenses")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(totalExpenses, format: .currency(code: defaultCurrency))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(defaultCurrency)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
            }

            HStack(spacing: 12) {
                // Scan Receipt button
                Button {
                    viewModel.isShowingCamera = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                        Text("Scan Receipt")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.ledgrPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(Capsule())
                }

                // Photo picker
                PhotosPicker(
                    selection: $viewModel.selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.caption)
                        Text("From Library")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                }
                .onChange(of: viewModel.selectedPhotoItem) { _, newValue in
                    Task {
                        await viewModel.handlePhotoPickerItem(newValue)
                        if viewModel.capturedImageData != nil {
                            showReview = true
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color.ledgrGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(Color.ledgrDark)

            HStack(spacing: 0) {
                quickActionButton(icon: "camera.fill", label: "Scan", color: Color.ledgrPrimary) {
                    viewModel.isShowingCamera = true
                }

                Spacer()

                quickActionButton(icon: "doc.text", label: "Export", color: Color.categoryTravel) {
                    exportCSV()
                }

                Spacer()

                quickActionButton(icon: "chart.bar.fill", label: "Insights", color: Color.categoryOffice) {
                    selectedTab = 1
                }

                Spacer()

                quickActionButton(icon: "creditcard.fill", label: "Cards", color: Color.categoryEntertainment) {
                    showCardBreakdown = true
                }
            }
            .padding(.vertical, 4)
            .cardStyle()
        }
    }

    private func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(color)
                }

                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.ledgrSecondaryText)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - AI Insights

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AI Insights")
                    .font(.headline)
                    .foregroundStyle(Color.ledgrDark)

                Spacer()

                Text("View all")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.ledgrPrimary)
            }

            VStack(spacing: 12) {
                insightCard(
                    icon: "arrow.down.circle.fill",
                    iconColor: Color.ledgrSuccess,
                    title: "Spending is down",
                    description: "Your expenses decreased by 14% compared to last month."
                )

                insightCard(
                    icon: "lightbulb.fill",
                    iconColor: Color.ledgrWarning,
                    title: "Top Category: Food & Dining",
                    description: "Consider setting a budget for dining expenses."
                )
            }
        }
    }

    private func insightCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ledgrDark)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.ledgrSecondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    // MARK: - Recent Transactions

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Receipts")
                    .font(.headline)
                    .foregroundStyle(Color.ledgrDark)

                Spacer()

                Text("View all")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.ledgrPrimary)
            }

            if recentExpenses.isEmpty {
                emptyTransactions
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentExpenses.prefix(5).enumerated()), id: \.element.id) { index, expense in
                        ExpenseRowView(expense: expense)

                        if index < min(recentExpenses.count, 5) - 1 {
                            Divider()
                                .padding(.leading, 58)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    private var emptyTransactions: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 32))
                .foregroundStyle(Color.ledgrSubtleText)

            Text("No receipts yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ledgrSecondaryText)

            Text("Scan your first receipt to get started")
                .font(.caption)
                .foregroundStyle(Color.ledgrSubtleText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .cardStyle()
    }

    // MARK: - Computed

    private var totalExpenses: Double {
        recentExpenses.reduce(0) { $0 + $1.totalAmount }
    }

    private var defaultCurrency: String {
        UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultCurrency) ?? "USD"
    }

    // MARK: - CSV Export

    private func exportCSV() {
        let dateFormatter = DateFormatters.displayDate
        var csv = "Date,Merchant,Category,Amount,Currency,Payment Method,Notes,Upload Status\n"

        for expense in recentExpenses {
            let date = dateFormatter.string(from: expense.transactionDate)
            let merchant = expense.merchantName.csvEscaped
            let category = expense.category.rawValue.csvEscaped
            let amount = String(format: "%.2f", expense.totalAmount)
            let currency = expense.currency
            let payment = (expense.paymentMethod ?? "").csvEscaped
            let notes = (expense.notes ?? "").csvEscaped
            let status = expense.uploadStatus.rawValue

            csv += "\(date),\(merchant),\(category),\(amount),\(currency),\(payment),\(notes),\(status)\n"
        }

        let fileName = "Ledgr_Expenses_\(DateFormatters.fileNameDate.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            csvFileURL = tempURL
            showShareSheet = true
        } catch {
            // File write failed — no-op, share sheet simply won't appear
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - CSV Escaping

private extension String {
    var csvEscaped: String {
        if contains(",") || contains("\"") || contains("\n") {
            return "\"\(replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return self
    }
}

#Preview {
    HomeView(selectedTab: .constant(0))
        .environmentObject(AppDependencies())
        .modelContainer(for: Expense.self, inMemory: true)
}
