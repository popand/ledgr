import SwiftUI
import PhotosUI
import SwiftData

struct HomeView: View {

    @Binding var selectedTab: Int
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var insightsViewModel = InsightsViewModel()
    @Query(sort: \Expense.createdAt, order: .reverse) private var recentExpenses: [Expense]
    @State private var showReview = false
    @State private var showShareSheet = false
    @State private var showCardBreakdown = false
    @State private var showAllInsights = false
    @State private var showAllTransactions = false
    @State private var csvFileURL: URL?
    @Environment(\.scenePhase) private var scenePhase

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
            .sheet(isPresented: $showAllTransactions) {
                AllTransactionsView(
                    authService: dependencies.authService,
                    driveService: dependencies.googleDriveService,
                    sheetsService: dependencies.googleSheetsService
                )
            }
            .sheet(isPresented: $showAllInsights) {
                if case .loaded(let insights) = insightsViewModel.state {
                    AllInsightsView(insights: insights)
                }
            }
            .task {
                insightsViewModel.configure(
                    llmService: dependencies.llmService,
                    sheetsService: dependencies.googleSheetsService,
                    authService: dependencies.authService
                )
                await insightsViewModel.generateInsights(localExpenses: recentExpenses)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await insightsViewModel.generateInsights(localExpenses: recentExpenses)
                    }
                }
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

                    Text(primaryTotal, format: .currency(code: defaultCurrency))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if !secondaryTotals.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(secondaryTotals, id: \.currency) { entry in
                                Text("+ \(entry.total, format: .currency(code: entry.currency))")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
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

                if case .loaded(let insights) = insightsViewModel.state, !insights.isEmpty {
                    Button {
                        showAllInsights = true
                    } label: {
                        Text("View all")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.ledgrPrimary)
                    }
                }
            }

            switch insightsViewModel.state {
            case .idle, .loading:
                insightsLoadingCard

            case .loaded(let insights):
                if insights.isEmpty {
                    insightsEmptyCard
                } else {
                    VStack(spacing: 12) {
                        ForEach(insights.prefix(2)) { insight in
                            insightCard(insight)
                        }
                    }
                }

            case .error(let message):
                insightsErrorCard(message: message)
            }
        }
    }

    private func insightCard(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(insight.iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: insight.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(insight.iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ledgrDark)

                Text(insight.description)
                    .font(.caption)
                    .foregroundStyle(Color.ledgrSecondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var insightsLoadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Generating insights...")
                .font(.caption)
                .foregroundStyle(Color.ledgrSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyle()
    }

    private var insightsEmptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(Color.ledgrSubtleText)

            Text("No insights yet")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.ledgrSecondaryText)

            Text("Add some expenses to get AI-powered insights")
                .font(.caption2)
                .foregroundStyle(Color.ledgrSubtleText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardStyle()
    }

    private func insightsErrorCard(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(Color.ledgrWarning)

            Text("Could not generate insights")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.ledgrSecondaryText)

            Button {
                Task {
                    await insightsViewModel.generateInsights(localExpenses: recentExpenses)
                }
            } label: {
                Text("Retry")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.ledgrPrimary)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
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

                Button {
                    showAllTransactions = true
                } label: {
                    Text("View all")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.ledgrPrimary)
                }
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

    private var defaultCurrency: String {
        UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultCurrency) ?? "CAD"
    }

    private var expensesByCurrency: [(currency: String, total: Double)] {
        let grouped = Dictionary(grouping: recentExpenses) { $0.currency }
        let result = grouped.map { (currency: $0.key, total: $0.value.reduce(0) { $0 + $1.totalAmount }) }
        // Default currency first, then alphabetical
        return result.sorted { lhs, rhs in
            if lhs.currency == defaultCurrency { return true }
            if rhs.currency == defaultCurrency { return false }
            return lhs.currency < rhs.currency
        }
    }

    private var primaryTotal: Double {
        expensesByCurrency.first { $0.currency == defaultCurrency }?.total ?? 0
    }

    private var secondaryTotals: [(currency: String, total: Double)] {
        expensesByCurrency.filter { $0.currency != defaultCurrency }
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
