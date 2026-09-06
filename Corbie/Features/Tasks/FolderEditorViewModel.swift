import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class FolderEditorViewModel {
    var title: String
    var subtitle: String
    var template: FolderTemplate
    var anyoneCanCheck: Bool
    private(set) var isSaving = false

    @ObservationIgnored var onError: ((any Error) -> Void)?

    @ObservationIgnored let existingFolder: TaskFolderDTO?
    @ObservationIgnored private let context: TasksContext
    @ObservationIgnored private let repository: any TaskRepository
    @ObservationIgnored private let analytics: any AnalyticsRecording

    init(
        folder: TaskFolderDTO?,
        context: TasksContext,
        repository: any TaskRepository,
        analytics: any AnalyticsRecording
    ) {
        existingFolder = folder
        self.context = context
        self.repository = repository
        self.analytics = analytics
        title = folder?.title ?? ""
        subtitle = folder?.subtitle ?? ""
        template = folder?.template ?? .empty
        anyoneCanCheck = folder?.anyoneCanCheck ?? true
    }

    var isEditing: Bool { existingFolder != nil }

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && isSaving == false
    }

    var titlePlaceholder: String {
        template == .empty ? String(localized: "tasks.folder.editor.title.placeholder") : template.title
    }

    func save() async -> TaskFolderDTO? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false, isSaving == false else { return nil }
        isSaving = true
        defer { isSaving = false }
        do {
            if var folder = existingFolder {
                folder.title = trimmedTitle
                folder.subtitle = trimmedSubtitle
                folder.template = template
                folder.anyoneCanCheck = anyoneCanCheck
                return try await repository.updateFolder(folder)
            }
            let created = try await create(title: trimmedTitle)
            analytics.record(.folderCreated(template: template))
            return created
        } catch {
            onError?(error)
            return nil
        }
    }

    private var trimmedSubtitle: String? {
        let trimmed = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func create(title: String) async throws -> TaskFolderDTO {
        guard let spaceId = context.spaceId else {
            throw CorbieError.notFound("space for a new folder")
        }
        let existing = try await repository.folders(spaceId: spaceId)
        guard template == .shopping, existing.contains(where: \.isPinnedShopping) == false else {
            return try await repository.createFolder(
                TaskFolderDraft(
                    spaceId: spaceId,
                    title: title,
                    subtitle: trimmedSubtitle,
                    template: template,
                    anyoneCanCheck: anyoneCanCheck,
                    createdByMemberId: context.memberId
                )
            )
        }
        var pinned = try await repository.pinnedShoppingFolder(
            spaceId: spaceId,
            title: title,
            createdByMemberId: context.memberId
        )
        guard pinned.subtitle != trimmedSubtitle || pinned.anyoneCanCheck != anyoneCanCheck else { return pinned }
        pinned.subtitle = trimmedSubtitle
        pinned.anyoneCanCheck = anyoneCanCheck
        return try await repository.updateFolder(pinned)
    }
}
