import Foundation

final class GoogleDriveService: ObservableObject {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Folder Management

    func ensureFolder(accessToken: String) async throws -> String {
        // Check cached folder ID
        if let cachedId = UserDefaults.standard.string(forKey: UserDefaultsKeys.driveFolderId),
           !cachedId.isEmpty {
            return cachedId
        }

        let folderName = UserDefaults.standard.string(forKey: UserDefaultsKeys.driveFolderName)
            ?? APIConstants.defaultDriveFolderName

        // Search for existing folder
        if let existingId = try await findFolder(named: folderName, accessToken: accessToken) {
            UserDefaults.standard.set(existingId, forKey: UserDefaultsKeys.driveFolderId)
            return existingId
        }

        // Create folder
        let newId = try await createFolder(named: folderName, accessToken: accessToken)
        UserDefaults.standard.set(newId, forKey: UserDefaultsKeys.driveFolderId)
        return newId
    }

    // MARK: - Upload

    func uploadReceipt(
        imageData: Data,
        fileName: String,
        folderId: String,
        accessToken: String
    ) async throws -> (fileId: String, webViewLink: String) {
        let fileId = try await performMultipartUpload(
            imageData: imageData,
            fileName: fileName,
            folderId: folderId,
            accessToken: accessToken
        )

        let webViewLink = try await getWebViewLink(fileId: fileId, accessToken: accessToken)

        return (fileId, webViewLink)
    }

    // MARK: - Delete

    func deleteFile(fileId: String, accessToken: String) async throws {
        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)") else {
            throw LedgrError.driveDeleteFailed("Invalid delete URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LedgrError.invalidResponse
        }
        guard httpResponse.statusCode == 204 else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw LedgrError.driveDeleteFailed("HTTP \(httpResponse.statusCode): \(body)")
        }
    }

    // MARK: - File Naming

    static func buildFileName(date: Date, merchantName: String, amount: Double) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let sanitized = merchantName
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined()
            .replacingOccurrences(of: " ", with: "_")
            .prefix(50)

        let amountString = String(format: "%.2f", amount)

        return "\(dateString)_\(sanitized)_\(amountString).jpg"
    }

    // MARK: - Private: Folder Operations

    private func findFolder(named name: String, accessToken: String) async throws -> String? {
        let query = "name='\(name)' and mimeType='application/vnd.google-apps.folder' and trashed=false"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.googleapis.com/drive/v3/files?q=\(encodedQuery)&fields=files(id)") else {
            throw LedgrError.driveUploadFailed("Invalid folder search URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, context: "folder search")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [[String: Any]],
              let firstFile = files.first,
              let folderId = firstFile["id"] as? String else {
            return nil
        }

        return folderId
    }

    private func createFolder(named name: String, accessToken: String) async throws -> String {
        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files") else {
            throw LedgrError.driveUploadFailed("Invalid folder creation URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let metadata: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, context: "folder creation")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let folderId = json["id"] as? String else {
            throw LedgrError.driveUploadFailed("Missing folder ID in creation response")
        }

        return folderId
    }

    // MARK: - Private: Upload

    private func performMultipartUpload(
        imageData: Data,
        fileName: String,
        folderId: String,
        accessToken: String
    ) async throws -> String {
        guard let url = URL(string: "\(APIConstants.driveUploadEndpoint)?uploadType=multipart&fields=id") else {
            throw LedgrError.driveUploadFailed("Invalid upload URL")
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let metadata: [String: Any] = [
            "name": fileName,
            "parents": [folderId],
            "mimeType": "image/jpeg"
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n")
        body.append(metadataData)
        body.append("\r\n--\(boundary)\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, context: "file upload")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fileId = json["id"] as? String else {
            throw LedgrError.driveUploadFailed("Missing file ID in upload response")
        }

        return fileId
    }

    // MARK: - Private: Permissions & Links

    private func setPublicPermission(fileId: String, accessToken: String) async throws {
        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)/permissions") else {
            throw LedgrError.driveUploadFailed("Invalid permissions URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let permission: [String: String] = [
            "role": "reader",
            "type": "anyone"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: permission)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, context: "permission setting")
    }

    private func getWebViewLink(fileId: String, accessToken: String) async throws -> String {
        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)?fields=webViewLink") else {
            throw LedgrError.driveUploadFailed("Invalid file metadata URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, context: "web view link retrieval")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let link = json["webViewLink"] as? String else {
            throw LedgrError.driveUploadFailed("Missing webViewLink in response")
        }

        return link
    }

    // MARK: - Private: Validation

    private func validateHTTPResponse(_ response: URLResponse, data: Data, context: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LedgrError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw LedgrError.driveUploadFailed("\(context) failed (HTTP \(httpResponse.statusCode)): \(body)")
        }
    }
}

// MARK: - Data Extension

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
