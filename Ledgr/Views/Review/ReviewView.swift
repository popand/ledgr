import SwiftUI
import SwiftData

struct ReviewView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ReviewViewModel

    private let image: UIImage?
    private let imageData: Data

    @State private var showFullImage = false

    private let currencies = ["CAD", "USD", "EUR", "GBP", "AUD", "JPY", "CHF", "MXN"]

    init(
        imageData: Data,
        image: UIImage?,
        llmService: LLMService,
        driveService: GoogleDriveService,
        sheetsService: GoogleSheetsService,
        authService: AuthService
    ) {
        self.imageData = imageData
        self.image = image
        _viewModel = StateObject(wrappedValue: ReviewViewModel(
            llmService: llmService,
            driveService: driveService,
            sheetsService: sheetsService,
            authService: authService
        ))
    }

    var body: some View {
        Group {
            if viewModel.isComplete {
                successView
            } else {
                formContent
            }
        }
        .background(Color.ledgrBackground.ignoresSafeArea())
        .overlay {
            if viewModel.isProcessing && viewModel.merchantName.isEmpty {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    LoadingView(viewModel.processingStatus)
                }
                .transition(.opacity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.isProcessing && viewModel.merchantName.isEmpty ? "Analyzing Receipt" : "Review Receipt")
                    .font(.headline)
                    .foregroundStyle(Color.ledgrDark)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ledgrDark)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.extractFromImage(imageData)
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 0) {
            Spacer()
            LoadingView(viewModel.processingStatus)
            Spacer()
        }
    }

    // MARK: - Form

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                receiptImageCard
                merchantCard
                amountCard
                categoryCard
                lineItemsCard
                notesCard
                saveButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var receiptImageCard: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .cardStyle(padding: 8, cornerRadius: 20)
                    .onTapGesture { showFullImage = true }
            }
        }
        .fullScreenCover(isPresented: $showFullImage) {
            ReceiptZoomView(image: image)
        }
    }

    private var merchantCard: some View {
        VStack(spacing: 14) {
            sectionHeader("Merchant Details")

            VStack(spacing: 12) {
                fieldRow(icon: "building.2", label: "Merchant") {
                    TextField("Name", text: $viewModel.merchantName)
                        .font(.subheadline)
                        .foregroundStyle(Color.ledgrDark)
                        .multilineTextAlignment(.trailing)
                }

                Divider()

                fieldRow(icon: "calendar", label: "Date") {
                    DatePicker("", selection: $viewModel.transactionDate, displayedComponents: .date)
                        .labelsHidden()
                }

                Divider()

                fieldRow(icon: "creditcard", label: "Payment") {
                    TextField("Method", text: $viewModel.paymentMethod)
                        .font(.subheadline)
                        .foregroundStyle(Color.ledgrDark)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .cardStyle()
    }

    private var amountCard: some View {
        VStack(spacing: 14) {
            sectionHeader("Amount")

            HStack(spacing: 12) {
                // Amount field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.ledgrSecondaryText)

                    TextField("0.00", text: $viewModel.totalAmount)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgrDark)
                        .keyboardType(.decimalPad)
                }

                Spacer()

                // Currency picker
                Picker("", selection: $viewModel.currency) {
                    ForEach(currencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.ledgrBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .tint(Color.ledgrPrimary)
            }
        }
        .cardStyle()
    }

    private var categoryCard: some View {
        VStack(spacing: 14) {
            sectionHeader("Category")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    Button {
                        viewModel.category = cat
                    } label: {
                        VStack(spacing: 6) {
                            CategoryBadgeView(category: cat, style: .icon)
                                .opacity(viewModel.category == cat ? 1 : 0.5)

                            Text(shortCategoryName(cat))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(viewModel.category == cat ? Color.ledgrDark : Color.ledgrSecondaryText)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(viewModel.category == cat ? CategoryBadgeView(category: cat).color.opacity(0.08) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    private var lineItemsCard: some View {
        VStack(spacing: 14) {
            HStack {
                sectionHeader("Line Items")
                Spacer()
                Button {
                    viewModel.addLineItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.ledgrPrimary)
                }
            }

            if viewModel.lineItems.isEmpty {
                Text("No line items")
                    .font(.caption)
                    .foregroundStyle(Color.ledgrSubtleText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach($viewModel.lineItems) { $item in
                        LineItemRowView(item: $item) {
                            viewModel.removeLineItem(id: item.id)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    private var notesCard: some View {
        VStack(spacing: 14) {
            sectionHeader("Notes")

            TextField("Add notes about this expense...", text: $viewModel.notes, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(Color.ledgrDark)
                .lineLimit(3...6)
                .padding(12)
                .background(Color.ledgrBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .cardStyle()
    }

    private var saveButton: some View {
        Button {
            Task {
                await viewModel.saveExpense(modelContext: modelContext)
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isProcessing {
                    ProgressView()
                        .tint(.white)
                    Text(viewModel.processingStatus)
                } else {
                    Image(systemName: "square.and.arrow.up")
                    Text("Save & Upload")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.ledgrGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(viewModel.isProcessing || viewModel.merchantName.isEmpty)
        .opacity((viewModel.isProcessing || viewModel.merchantName.isEmpty) ? 0.6 : 1)
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.ledgrSuccess.opacity(0.12))
                    .frame(width: 96, height: 96)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.ledgrSuccess)
            }

            VStack(spacing: 8) {
                Text("Expense Saved!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.ledgrDark)

                Text(viewModel.processingStatus)
                    .font(.subheadline)
                    .foregroundStyle(Color.ledgrSecondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.ledgrGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ledgrDark)
            Spacer()
        }
    }

    private func fieldRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.ledgrPrimary)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.ledgrSecondaryText)

            Spacer()

            content()
        }
    }

    private func shortCategoryName(_ category: ExpenseCategory) -> String {
        switch category {
        case .foodAndDining: return "Food"
        case .travel: return "Travel"
        case .officeSupplies: return "Office"
        case .entertainment: return "Fun"
        case .utilities: return "Utilities"
        case .health: return "Health"
        case .shopping: return "Shopping"
        case .other: return "Other"
        }
    }
}
