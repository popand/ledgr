import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = SettingsViewModel()
    @State private var apiKeyInput = ""
    @State private var showApiKeyField = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    profileCard
                    apiKeyCard
                    preferencesCard
                    aboutCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.ledgrBackground.ignoresSafeArea())
            .onAppear {
                viewModel.configure(authService: dependencies.authService)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Settings")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ledgrDark)

            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Profile / Google Account

    private var profileCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.ledgrPrimary.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.ledgrPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.isGoogleConnected ? "Google Connected" : "Google Account")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ledgrDark)

                    if let email = viewModel.userEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(Color.ledgrSecondaryText)
                    } else {
                        Text("Connect for Drive & Sheets sync")
                            .font(.caption)
                            .foregroundStyle(Color.ledgrSecondaryText)
                    }
                }

                Spacer()

                if viewModel.isGoogleConnected {
                    statusDot(color: Color.ledgrSuccess)
                }
            }

            Divider()

            if viewModel.isGoogleConnected {
                Button {
                    viewModel.disconnectGoogle()
                } label: {
                    HStack {
                        Image(systemName: "link.badge.plus")
                            .font(.subheadline)
                        Text("Disconnect Account")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.ledgrSubtleText)
                    }
                    .foregroundStyle(Color.ledgrError)
                }
            } else {
                Button {
                    Task { await viewModel.connectGoogle() }
                } label: {
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .font(.subheadline)
                        Text("Connect Google Account")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.ledgrSubtleText)
                    }
                    .foregroundStyle(Color.ledgrPrimary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - API Key

    private var apiKeyCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(viewModel.apiKeySet ? Color.ledgrSuccess.opacity(0.12) : Color.ledgrWarning.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: viewModel.apiKeySet ? "checkmark.shield.fill" : "shield")
                        .font(.system(size: 20))
                        .foregroundStyle(viewModel.apiKeySet ? Color.ledgrSuccess : Color.ledgrWarning)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Anthropic API Key")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ledgrDark)

                    Text(viewModel.apiKeySet ? "Configured and stored in Keychain" : "Required for receipt extraction")
                        .font(.caption)
                        .foregroundStyle(Color.ledgrSecondaryText)
                }

                Spacer()

                if viewModel.apiKeySet {
                    statusDot(color: Color.ledgrSuccess)
                }
            }

            if showApiKeyField || !viewModel.apiKeySet {
                VStack(spacing: 12) {
                    SecureField("sk-ant-...", text: $apiKeyInput)
                        .font(.subheadline)
                        .padding(12)
                        .background(Color.ledgrBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        viewModel.saveApiKey(apiKeyInput)
                        apiKeyInput = ""
                        showApiKeyField = false
                    } label: {
                        Text("Save Key")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.ledgrPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(apiKeyInput.isEmpty)
                    .opacity(apiKeyInput.isEmpty ? 0.5 : 1)
                }
            } else {
                Divider()

                HStack {
                    Button {
                        showApiKeyField = true
                    } label: {
                        HStack {
                            Text("Update Key")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.ledgrSubtleText)
                        }
                        .foregroundStyle(Color.ledgrPrimary)
                    }
                }

                Button {
                    viewModel.clearApiKey()
                } label: {
                    HStack {
                        Text("Remove Key")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.ledgrSubtleText)
                    }
                    .foregroundStyle(Color.ledgrError)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Preferences

    private var preferencesCard: some View {
        VStack(spacing: 16) {
            HStack {
                settingIcon("dollarsign.circle.fill", color: Color.ledgrPrimary)

                Text("Default Currency")
                    .font(.subheadline)
                    .foregroundStyle(Color.ledgrDark)

                Spacer()

                Picker("", selection: $viewModel.defaultCurrency) {
                    ForEach(["CAD", "USD", "EUR", "GBP", "AUD", "JPY", "CHF", "MXN"], id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .labelsHidden()
                .tint(Color.ledgrPrimary)
                .onChange(of: viewModel.defaultCurrency) { _, _ in
                    viewModel.saveCurrency()
                }
            }

            Divider()

            HStack {
                settingIcon("folder.fill", color: Color.categoryTravel)

                Text("Drive Folder")
                    .font(.subheadline)
                    .foregroundStyle(Color.ledgrDark)

                Spacer()

                TextField("Folder Name", text: $viewModel.driveFolderName)
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.ledgrSecondaryText)
                    .onChange(of: viewModel.driveFolderName) { _, _ in
                        viewModel.saveFolderName()
                    }
            }

            Divider()

            HStack {
                settingIcon("tablecells.fill", color: Color.ledgrSuccess)

                Text("Sheet Name")
                    .font(.subheadline)
                    .foregroundStyle(Color.ledgrDark)

                Spacer()

                TextField("Sheet Name", text: $viewModel.sheetsName)
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.ledgrSecondaryText)
                    .onChange(of: viewModel.sheetsName) { _, _ in
                        viewModel.saveSheetsName()
                    }
            }
        }
        .cardStyle()
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(spacing: 16) {
            HStack {
                settingIcon("info.circle.fill", color: Color.ledgrSubtleText)
                Text("Version")
                    .font(.subheadline)
                    .foregroundStyle(Color.ledgrDark)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.subheadline)
                    .foregroundStyle(Color.ledgrSecondaryText)
            }

            Divider()

            HStack {
                settingIcon("hammer.fill", color: Color.ledgrSubtleText)
                Text("Build")
                    .font(.subheadline)
                    .foregroundStyle(Color.ledgrDark)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    .font(.subheadline)
                    .foregroundStyle(Color.ledgrSecondaryText)
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func settingIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: 32, height: 32)

            Image(systemName: name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
        }
    }

    private func statusDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppDependencies())
}
