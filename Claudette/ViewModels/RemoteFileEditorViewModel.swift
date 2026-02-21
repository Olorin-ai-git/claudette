import Citadel
import CryptoKit
import Foundation
import NIOSSH
import os

@MainActor
final class RemoteFileEditorViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var error: String?
    @Published var hasUnsavedChanges: Bool = false

    let filePath: String
    let fileName: String

    private let fileBrowserService: RemoteFileBrowserService
    private let maxFileSize: Int
    private let logger: Logger
    private var originalContent: String = ""

    init(
        filePath: String,
        fileBrowserService: RemoteFileBrowserService,
        config: AppConfiguration,
        logger: Logger
    ) {
        self.filePath = filePath
        fileName = (filePath as NSString).lastPathComponent
        self.fileBrowserService = fileBrowserService
        maxFileSize = config.fileEditorMaxSizeBytes
        self.logger = logger
    }

    func loadFile() async {
        isLoading = true
        error = nil

        let path = filePath
        do {
            let data = try await fileBrowserService.readFile(atPath: path)

            guard data.count <= maxFileSize else {
                throw RemoteFileBrowserError.fileTooLarge(size: UInt64(data.count), maxSize: maxFileSize)
            }

            guard let text = String(data: data, encoding: .utf8) else {
                error = "File is not valid UTF-8 text"
                isLoading = false
                return
            }

            content = text
            originalContent = text
            hasUnsavedChanges = false
            isLoading = false
            logger.info("Loaded file: \(path, privacy: .public)")
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            logger.error("Failed to load file: \(error.localizedDescription)")
        }
    }

    func saveFile() async {
        isSaving = true
        error = nil

        let path = filePath
        do {
            guard let data = content.data(using: .utf8) else {
                error = "Failed to encode content"
                isSaving = false
                return
            }

            try await fileBrowserService.writeFile(data: data, atPath: path)
            originalContent = content
            hasUnsavedChanges = false
            isSaving = false
            logger.info("Saved file: \(path, privacy: .public)")
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            logger.error("Failed to save file: \(error.localizedDescription)")
        }
    }

    func contentDidChange() {
        hasUnsavedChanges = content != originalContent
    }
}
